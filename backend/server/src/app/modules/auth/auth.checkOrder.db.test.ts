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

// T-021 / B-21, DB-backed part: the login check order and the unchanged
// success paths of the four reordered routes, through the real routers and
// middlewares. Redis is the in-memory fake (geoadd, which the fake lacks, is
// stubbed on the client). Committed rows carry a per-run email prefix and are
// deleted in after().

const run = randomUUID().replace(/-/g, '').slice(0, 12);
const emailOf = (n: string) => `t021-${run}-${n}@example.test`;
const PASSWORD = 'correct-horse-1';

describe('login order and success paths (T-021)', { skip: dbTestSkipReason() }, () => {
  let appPrisma: PrismaClient;
  let srv: Awaited<ReturnType<typeof startTestServer>>;
  let redis: ReturnType<typeof installFakeRedis>;
  const db = () => getTestPrisma();
  const users: Record<string, { id: string; email: string }> = {};

  const post = (path: string, body: unknown, token?: string) =>
    fetch(`${srv.baseUrl}${path}`, {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        ...(token ? { authorization: `Bearer ${token}` } : {}),
      },
      body: JSON.stringify(body),
    });

  const loginBody = (email: string, password: string, device = 'dev-a') => ({
    email,
    password,
    deviceIdentifier: `t021-${run}-${device}`,
    platform: 'ANDROID',
    lat: 1,
    lng: 2,
  });

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

    const { getRedisClient } = await import('@/app/configs/redis.configs');
    (getRedisClient() as unknown as Record<string, unknown>).geoadd =
      async () => 1;

    const { hashPassword } = await import('@/app/utils/password.utils');
    const hashed = await hashPassword(PASSWORD);
    const mk = async (
      n: string,
      extra: Record<string, unknown> = {}
    ) => {
      const u = await db().user.create({
        data: {
          name: `T021 ${n}`,
          email: emailOf(n),
          phoneNumber: `+1555${Math.floor(Math.random() * 1e7)}`,
          isVerified: true,
          password: hashed,
          ...extra,
        },
      });
      users[n] = { id: u.id, email: u.email };
    };
    await mk('active');
    await mk('blocked', { accountStatus: 'BLOCKED' });
    await mk('inactive', { accountStatus: 'INACTIVE' });
    await mk('deleted', { accountStatus: 'DELETED' });
    await mk('nopass', { accountStatus: 'BLOCKED', password: null });

    const authRoutes = (await import('@/app/modules/auth/auth.routes')).default;
    const recoverRoutes = (await import('@/app/modules/recover/recover.routes'))
      .default;
    const { globalErrorMiddleware } = await import(
      '@/app/middlewares/globalError.middlewares'
    );
    const app = express();
    app.use(express.json());
    app.use(cookieParser());
    app.use(authRoutes);
    app.use(recoverRoutes);
    app.use(globalErrorMiddleware);
    srv = await startTestServer(app);
  });

  after(async () => {
    try {
      await db().user.deleteMany({
        where: { email: { startsWith: `t021-${run}-` } },
      });
    } finally {
      await srv?.close();
      await appPrisma?.$disconnect();
      await closeTestPrisma();
    }
  });

  describe('POST /auth/login', () => {
    const strip = (j: Record<string, unknown>) => {
      const { traceId: _t, ...rest } = j;
      return rest;
    };

    it('unknown email -> 401 INVALID_CREDENTIALS (baseline)', async () => {
      const res = await post(
        '/auth/login',
        loginBody(emailOf('nobody'), 'whatever-1')
      );
      assert.equal(res.status, 401);
      assert.equal(
        ((await res.json()) as { errorType: string }).errorType,
        'INVALID_CREDENTIALS'
      );
    });

    for (const status of ['blocked', 'inactive', 'deleted']) {
      it(`${status} account + WRONG password -> identical to unknown email`, async () => {
        const unknown = await post(
          '/auth/login',
          loginBody(emailOf('nobody'), 'wrong-pass-1')
        );
        const res = await post(
          '/auth/login',
          loginBody(users[status].email, 'wrong-pass-1')
        );
        assert.equal(res.status, unknown.status);
        assert.deepEqual(
          strip((await res.json()) as Record<string, unknown>),
          strip((await unknown.json()) as Record<string, unknown>)
        );
      });
    }

    it('account without a password hash (social) + any password -> 401 INVALID_CREDENTIALS, not 500', async () => {
      const res = await post(
        '/auth/login',
        loginBody(users.nopass.email, 'whatever-1')
      );
      assert.equal(res.status, 401);
      assert.equal(
        ((await res.json()) as { errorType: string }).errorType,
        'INVALID_CREDENTIALS'
      );
    });

    const expected: Record<string, [string, string]> = {
      blocked: ['USER_BLOCKED', 'Your account has been blocked'],
      inactive: ['ACCOUNT_INACTIVE', 'Your account has been deactivated'],
      deleted: ['ACCOUNT_DELETED', 'Your account has been deleted'],
    };
    for (const [status, [errorType, message]] of Object.entries(expected)) {
      it(`${status} account + RIGHT password -> still 401 ${errorType} with the status message`, async () => {
        const res = await post(
          '/auth/login',
          loginBody(users[status].email, PASSWORD)
        );
        assert.equal(res.status, 401);
        const json = (await res.json()) as Record<string, unknown>;
        assert.equal(json.errorType, errorType);
        assert.equal(json.message, message);
      });
    }

    it('invalid body is still 422 (validation stays first on login)', async () => {
      const res = await post('/auth/login', { email: 'not-an-email' });
      assert.equal(res.status, 422);
    });

    it('active account + wrong password -> 401 INVALID_CREDENTIALS', async () => {
      const res = await post(
        '/auth/login',
        loginBody(users.active.email, 'wrong-pass-1')
      );
      assert.equal(res.status, 401);
      assert.equal(
        ((await res.json()) as { errorType: string }).errorType,
        'INVALID_CREDENTIALS'
      );
    });

    let accessToken = '';
    it('active account + right password -> 200 with token (success shape unchanged)', async () => {
      const res = await post(
        '/auth/login',
        loginBody(users.active.email, PASSWORD)
      );
      assert.equal(res.status, 200);
      const json = (await res.json()) as {
        success: boolean;
        message: string;
        data: Record<string, unknown>;
      };
      assert.equal(json.success, true);
      assert.equal(json.message, 'Login successful');
      assert.deepEqual(Object.keys(json.data).sort(), [
        'isUserVerified',
        'refreshToken',
        'role',
        'token',
      ]);
      accessToken = json.data.token as string;
    });

    it('check then logout succeed with a fresh token; the token is revoked afterwards (HF-003)', async () => {
      assert.ok(accessToken, 'login test must have produced a token');
      const body = {
        deviceIdentifier: `t021-${run}-dev-a`,
        lat: 1,
        lng: 2,
        platform: 'ANDROID',
      };
      const check = await post('/auth/check', body, accessToken);
      assert.equal(check.status, 200);
      const checkJson = (await check.json()) as {
        message: string;
        data: Record<string, unknown>;
      };
      assert.equal(checkJson.message, 'User is authenticated');
      assert.deepEqual(Object.keys(checkJson.data).sort(), [
        'accountStatus',
        'avatar',
        'name',
        'role',
      ]);

      const logout = await post(
        '/auth/logout',
        { deviceIdentifier: body.deviceIdentifier },
        accessToken
      );
      assert.equal(logout.status, 200);
      assert.equal(
        ((await logout.json()) as { message: string }).message,
        'Logout successful'
      );

      // Same token, now revoked: 401 TOKEN_BLACKLISTED on both routes, with a
      // valid body and with an invalid body.
      for (const [path, b] of [
        ['/auth/check', body],
        ['/auth/check', {}],
        ['/auth/logout', { deviceIdentifier: body.deviceIdentifier }],
        ['/auth/logout', {}],
      ] as const) {
        const res = await post(path, b, accessToken);
        assert.equal(res.status, 401, path);
        assert.equal(
          ((await res.json()) as { errorType: string }).errorType,
          'TOKEN_BLACKLISTED'
        );
      }
    });
  });

  describe('recover routes with a real user', () => {
    let resetToken = '';
    before(async () => {
      const { generateResetPasswordPageToken } = await import(
        '@/app/utils/jwt.utils'
      );
      resetToken = generateResetPasswordPageToken({
        sub: users.active.id,
        role: 'USER',
        isVerified: true,
        accountStatus: 'ACTIVE',
        deviceId: 'pending',
      } as unknown as Parameters<typeof generateResetPasswordPageToken>[0]);
    });

    it('reset with a valid token and body but no OTP verification -> 403 RECOVER_OTP_NOT_VERIFIED (HF-004 intact)', async () => {
      const res = await post(
        '/recover/reset',
        { password: 'new-secret-1' },
        resetToken
      );
      assert.equal(res.status, 403);
      assert.equal(
        ((await res.json()) as { errorType: string }).errorType,
        'RECOVER_OTP_NOT_VERIFIED'
      );
    });

    it('verify with a wrong OTP -> 401 INVALID_OTP; with the right OTP -> 200 and marker set', async () => {
      const { hashOtp, saveHashedOtp } = await import('@/app/utils/otp.utils');
      await saveHashedOtp(users.active.id, hashOtp({ otp: '123456' }));
      const bad = await post('/recover/verify', { otp: '654321' }, resetToken);
      assert.equal(bad.status, 401);
      assert.equal(
        ((await bad.json()) as { errorType: string }).errorType,
        'INVALID_OTP'
      );
      const good = await post('/recover/verify', { otp: '123456' }, resetToken);
      assert.equal(good.status, 200);
      assert.equal(
        ((await good.json()) as { message: string }).message,
        'User verification successful'
      );
      const { isRecoverVerified } = await import(
        '@/app/modules/recover/recover.verified.helpers'
      );
      assert.equal(
        await isRecoverVerified({ redis, userId: users.active.id }),
        true
      );
    });
  });
});
