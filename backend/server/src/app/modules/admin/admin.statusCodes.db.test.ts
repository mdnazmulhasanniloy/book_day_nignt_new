import { after, before, describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import express from 'express';
import cookieParser from 'cookie-parser';
import type { PrismaClient } from '@prisma/client';
import {
  assertSafeTestDatabaseUrl,
  closeTestPrisma,
  dbTestSkipReason,
  getTestPrisma,
} from '@/testing/testDb';
import { installFakeRedis, startTestServer } from '@/testing/fakes';

// T-010: admin status codes (B-17, B-18, B-22) through the real admin router,
// real middlewares and the real global error handler. DB-backed because the
// admin existence middleware reads the user. Redis is the in-memory fake.
// Committed rows use a per-run email prefix and are deleted in after().

const run = randomUUID().replace(/-/g, '').slice(0, 12);

describe('admin status codes (T-010)', { skip: dbTestSkipReason() }, () => {
  let appPrisma: PrismaClient;
  let srv: Awaited<ReturnType<typeof startTestServer>>;
  let redis: ReturnType<typeof installFakeRedis>;
  let adminId: string;
  let accessToken: string;
  let refreshToken: string;
  let sessionKey: string;
  const csrf = 'csrf-' + run;
  const db = () => getTestPrisma();

  const call = (
    method: string,
    path: string,
    cookies: Record<string, string> = {}
  ) =>
    fetch(`${srv.baseUrl}${path}`, {
      method,
      headers: {
        'x-csrf-token': csrf,
        cookie: Object.entries({ admin_csrf_token: csrf, ...cookies })
          .map(([k, v]) => `${k}=${v}`)
          .join('; '),
      },
    });
  const authed = () => ({ access_token: accessToken });

  before(async () => {
    process.env.DATABASE_URL = assertSafeTestDatabaseUrl(
      process.env.TEST_DATABASE_URL
    );
    redis = installFakeRedis();
    appPrisma = (await import('@/app/configs/db.configs')).default;
    const [{ current_database: name }] = await appPrisma.$queryRaw<
      { current_database: string }[]
    >`select current_database()`;
    assert.match(name, /_test$/, 'app prisma client must target the test DB');

    const admin = await db().user.create({
      data: {
        name: 'T010 Admin',
        email: `t010-${run}-admin@example.test`,
        phoneNumber: `+1555${Math.floor(Math.random() * 1e7)}`,
        accountRole: 'ADMIN',
        isVerified: true,
      },
    });
    adminId = admin.id;

    const jwt = await import('@/app/utils/jwt.utils');
    const payload = {
      sub: admin.id,
      role: admin.accountRole,
      isVerified: true,
      accountStatus: admin.accountStatus,
      rememberMe: true,
    };
    accessToken = jwt.generateAccessTokenForAdmin(payload);
    refreshToken = jwt.generateRefreshToken(payload);

    const { createRedisKey } = await import('@/app/utils/system.utils');
    const { hashToken } = await import('@/app/utils/crypto.utils');
    const { REDIS_PREFIXES } = await import('@/const');
    sessionKey = createRedisKey(
      REDIS_PREFIXES.adminSession,
      admin.id,
      hashToken(refreshToken)
    );

    const adminRoutes = (await import('@/app/modules/admin/admin.routes'))
      .default;
    const { globalErrorMiddleware } = await import(
      '@/app/middlewares/globalError.middlewares'
    );
    const app = express();
    app.use(express.json());
    app.use(cookieParser());
    app.use('/api/v1', adminRoutes);
    app.use(globalErrorMiddleware);
    srv = await startTestServer(app);
  });

  after(async () => {
    try {
      await db().user.deleteMany({
        where: { email: { startsWith: `t010-${run}-` } },
      });
    } finally {
      await srv?.close();
      await appPrisma?.$disconnect();
      await closeTestPrisma();
    }
  });

  describe('POST /admin/auth/refresh (B-17)', () => {
    it('garbage refresh token -> 401 TOKEN_INVALID', async () => {
      const r = await call('POST', '/api/v1/admin/auth/refresh', {
        refresh_token: 'garbage',
      });
      assert.equal(r.status, 401);
      const body = (await r.json()) as { errorType?: string };
      assert.equal(body.errorType, 'TOKEN_INVALID');
    });

    it('validly signed token with no live session -> 401 TOKEN_INVALID (was 500)', async () => {
      const r = await call('POST', '/api/v1/admin/auth/refresh', {
        refresh_token: refreshToken,
      });
      assert.equal(r.status, 401);
      const body = (await r.json()) as { success: boolean; errorType?: string };
      assert.equal(body.success, false);
      assert.equal(body.errorType, 'TOKEN_INVALID');
    });

    it('validly signed token with a live session still refreshes, and cannot be reused', async () => {
      await redis.set(sessionKey, '1');
      const r = await call('POST', '/api/v1/admin/auth/refresh', {
        refresh_token: refreshToken,
      });
      assert.equal(r.status, 200);
      const body = (await r.json()) as { success: boolean };
      assert.equal(body.success, true);
      const again = await call('POST', '/api/v1/admin/auth/refresh', {
        refresh_token: refreshToken,
      });
      assert.equal(again.status, 401);
    });
  });

  describe('PATCH /admin/users/:id/suspend (B-18)', () => {
    it('unknown user id -> 404 (was 500)', async () => {
      const r = await call(
        'PATCH',
        `/api/v1/admin/users/${randomUUID()}/suspend`,
        authed()
      );
      assert.equal(r.status, 404);
      const body = (await r.json()) as { success: boolean; message: string };
      assert.equal(body.success, false);
      assert.equal(body.message, 'User not found');
    });

    it('existing user still toggles BLOCKED and back', async () => {
      const u = await db().user.create({
        data: {
          name: 'T010 Target',
          email: `t010-${run}-target@example.test`,
          phoneNumber: `+1555${Math.floor(Math.random() * 1e7)}`,
        },
      });
      const r1 = await call('PATCH', `/api/v1/admin/users/${u.id}/suspend`, authed());
      assert.equal(r1.status, 200);
      assert.equal(
        (await db().user.findUniqueOrThrow({ where: { id: u.id } })).accountStatus,
        'BLOCKED'
      );
      const r2 = await call('PATCH', `/api/v1/admin/users/${u.id}/suspend`, authed());
      assert.equal(r2.status, 200);
      assert.equal(
        (await db().user.findUniqueOrThrow({ where: { id: u.id } })).accountStatus,
        'ACTIVE'
      );
    });
  });

  for (const path of ['/api/v1/admin/users', '/api/v1/admin/earnings']) {
    describe(`GET ${path} page/limit (B-22)`, () => {
      for (const qs of [
        'page=abc',
        'page=0',
        'page=-1',
        'page=1.5',
        'page=1abc',
        'limit=-1',
        'limit=0',
        'limit=abc',
        'limit=101',
        'page=',
        'limit=',
      ]) {
        it(`${qs} -> 422`, async () => {
          const r = await call('GET', `${path}?${qs}`, authed());
          assert.equal(r.status, 422);
          const body = (await r.json()) as { success: boolean; errors: unknown[] };
          assert.equal(body.success, false);
          assert.ok(body.errors.length > 0);
        });
      }

      it('no params -> 200 with the old shape (defaults page 1, limit 10)', async () => {
        const r = await call('GET', path, authed());
        assert.equal(r.status, 200);
        const body = (await r.json()) as Record<string, unknown>;
        assert.equal(body.success, true);
        assert.ok(Array.isArray(body.data));
        assert.ok(typeof body.meta === 'object' && body.meta !== null);
        if (path.endsWith('/users')) {
          const meta = body.meta as { page: number; limit: number };
          assert.equal(meta.page, 1);
          assert.equal(meta.limit, 10);
        }
      });

      it('valid page=2&limit=100 -> 200', async () => {
        const r = await call('GET', `${path}?page=2&limit=100`, authed());
        assert.equal(r.status, 200);
      });
    });
  }

  it('admin fixture exists', () => {
    assert.ok(adminId);
  });
});
