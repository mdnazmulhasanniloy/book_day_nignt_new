import { after, before, describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import express from 'express';
import cookieParser from 'cookie-parser';
import { installFakeRedis, startTestServer } from '@/testing/fakes';
import { createRedisKey } from '@/app/utils/system.utils';
import { AuthErrorType, REDIS_PREFIXES } from '@/const';
import {
  generateAccessTokenForUser,
  generateResetPasswordPageToken,
} from '@/app/utils/jwt.utils';

// T-021 / B-21: on /auth/check, /auth/logout, /recover/verify and /recover/reset
// the token check must run BEFORE body validation. No database is needed: a
// request that fails the token check never reaches a DB-backed middleware, and a
// request with a good token and a bad body is rejected by validation (422)
// before any DB read. The Redis blacklist is the in-memory fake, read with the
// same key logout writes (REDIS_PREFIXES.blacklist).

type Route = {
  name: string;
  path: string;
  mkToken: () => string;
  tokenKind: 'access' | 'reset';
};

// Fresh subject per call: tokens signed in the same second would otherwise be
// byte-identical and a blacklisted token would leak into the next test.
const mkPayload = () => ({
  sub: `u-t021-${randomUUID()}`,
  role: 'USER',
  isVerified: true,
  accountStatus: 'ACTIVE',
  deviceId: 'd-t021',
}) as unknown as Parameters<typeof generateAccessTokenForUser>[0];

const routes: Route[] = [
  {
    name: 'POST /auth/check',
    path: '/auth/check',
    mkToken: () => generateAccessTokenForUser(mkPayload()),
    tokenKind: 'access',
  },
  {
    name: 'POST /auth/logout',
    path: '/auth/logout',
    mkToken: () => generateAccessTokenForUser(mkPayload()),
    tokenKind: 'access',
  },
  {
    name: 'POST /recover/verify',
    path: '/recover/verify',
    mkToken: () => generateResetPasswordPageToken(mkPayload()),
    tokenKind: 'reset',
  },
  {
    name: 'POST /recover/reset',
    path: '/recover/reset',
    mkToken: () => generateResetPasswordPageToken(mkPayload()),
    tokenKind: 'reset',
  },
];

const BAD_BODY = { unexpected: 'field' };

describe('check order: token before body validation (T-021, B-21)', () => {
  let srv: Awaited<ReturnType<typeof startTestServer>>;
  let redis: ReturnType<typeof installFakeRedis>;

  before(async () => {
    redis = installFakeRedis();
    const authRoutes = (await import('@/app/modules/auth/auth.routes')).default;
    const recoverRoutes = (await import('@/app/modules/recover/recover.routes'))
      .default;
    const app = express();
    app.use(express.json());
    app.use(cookieParser());
    app.use(authRoutes);
    app.use(recoverRoutes);
    srv = await startTestServer(app);
  });
  after(() => srv.close());

  const post = (path: string, body: unknown, token?: string) =>
    fetch(`${srv.baseUrl}${path}`, {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        ...(token ? { authorization: `Bearer ${token}` } : {}),
      },
      body: JSON.stringify(body),
    });

  for (const route of routes) {
    describe(route.name, () => {
      it('no token + invalid body -> 401 TOKEN_INVALID (not 422)', async () => {
        const res = await post(route.path, BAD_BODY);
        assert.equal(res.status, 401);
        const json = (await res.json()) as Record<string, unknown>;
        assert.equal(json.errorType, AuthErrorType.TOKEN_INVALID);
        assert.equal(json.errors, undefined);
      });

      it('garbage token + invalid body -> 401 TOKEN_INVALID (not 422)', async () => {
        const res = await post(route.path, BAD_BODY, 'not.a.jwt');
        assert.equal(res.status, 401);
        const json = (await res.json()) as Record<string, unknown>;
        assert.equal(json.errorType, AuthErrorType.TOKEN_INVALID);
      });

      it('token signed with the other secret + invalid body -> 401', async () => {
        const wrongKind =
          route.tokenKind === 'access'
            ? generateResetPasswordPageToken(mkPayload())
            : generateAccessTokenForUser(mkPayload());
        const res = await post(route.path, BAD_BODY, wrongKind);
        assert.equal(res.status, 401);
      });

      it('revoked (blacklisted) token + invalid body -> 401 TOKEN_BLACKLISTED', async () => {
        const token = route.mkToken();
        await redis.set(createRedisKey(REDIS_PREFIXES.blacklist, token), token);
        const res = await post(route.path, BAD_BODY, token);
        assert.equal(res.status, 401);
        const json = (await res.json()) as Record<string, unknown>;
        assert.equal(json.errorType, AuthErrorType.TOKEN_BLACKLISTED);
      });

      it('revoked token + VALID-shaped body is still 401 (HF-003 intact)', async () => {
        const token = route.mkToken();
        await redis.set(createRedisKey(REDIS_PREFIXES.blacklist, token), token);
        const body =
          route.path === '/recover/verify'
            ? { otp: '123456' }
            : route.path === '/recover/reset'
              ? { password: 'secret123' }
              : route.path === '/auth/logout'
                ? { deviceIdentifier: 'dev-1' }
                : {
                    deviceIdentifier: 'dev-1',
                    lat: 1,
                    lng: 2,
                    platform: 'ANDROID',
                  };
        const res = await post(route.path, body, token);
        assert.equal(res.status, 401);
        const json = (await res.json()) as Record<string, unknown>;
        assert.equal(json.errorType, AuthErrorType.TOKEN_BLACKLISTED);
      });

      it('valid token + invalid body -> still 422 (legitimate client unchanged)', async () => {
        const res = await post(route.path, BAD_BODY, route.mkToken());
        assert.equal(res.status, 422);
        const json = (await res.json()) as { errors?: unknown[] };
        assert.ok(Array.isArray(json.errors) && json.errors.length > 0);
      });
    });
  }
});
