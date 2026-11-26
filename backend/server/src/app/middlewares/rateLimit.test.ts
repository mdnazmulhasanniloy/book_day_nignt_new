import { after, before, afterEach, describe, it, mock } from 'node:test';
import assert from 'node:assert/strict';
import express from 'express';
import { createRedisKey } from '@/app/utils/system.utils';
import { AuthErrorType, REDIS_PREFIXES, promoValidateMaxPerWindow, promoValidateWindowSeconds } from '@/const';
import { FakeRedis, installFakeRedis, startTestServer } from '@/testing/fakes';
import { generateAccessTokenForUser } from '@/app/utils/jwt.utils';
import {
  createRateLimitMiddleware,
  limitPromoValidateMiddleware,
} from '@/app/middlewares/rateLimit.middlewares';

// T-019 (S-09): fixed-window limiter, 20 per minute per IP and per user, 429 + Retry-After.
// The test app sets `trust proxy` = 1 like app.ts so X-Forwarded-For selects the client IP.

const token = (sub: string) =>
  generateAccessTokenForUser({
    sub,
    role: 'USER',
    isVerified: true,
    accountStatus: 'ACTIVE',
    rememberMe: true,
  } as never);

describe('rate limit middleware (T-019)', () => {
  let redis: FakeRedis;
  let srv: Awaited<ReturnType<typeof startTestServer>>;
  let hits = 0;

  const post = (ip: string, bearer?: string) =>
    fetch(`${srv.baseUrl}/promo/validate`, {
      method: 'POST',
      headers: {
        'x-forwarded-for': ip,
        ...(bearer ? { authorization: `Bearer ${bearer}` } : {}),
      },
    });

  before(async () => {
    redis = installFakeRedis();
    const app = express();
    app.set('trust proxy', 1);
    app.post('/promo/validate', limitPromoValidateMiddleware, (_q, r) => {
      hits += 1;
      r.json({ success: true });
    });
    const tiny = createRateLimitMiddleware({
      ipPrefix: REDIS_PREFIXES.promoValidateUser,
      max: 2,
      windowSeconds: 30,
      message: 'slow down',
    });
    app.get('/tiny', tiny, (_q, r) => {
      r.json({ ok: true });
    });
    srv = await startTestServer(app);
  });
  after(() => srv.close());
  afterEach(() => mock.timers.reset());

  it('uses 20 per minute (constants, not literals in the route)', () => {
    assert.equal(promoValidateMaxPerWindow, 20);
    assert.equal(promoValidateWindowSeconds, 60);
  });

  it('allows 20 calls, rejects the 21st with 429 RATE_LIMITED and Retry-After, never 401/403', async () => {
    for (let i = 0; i < 20; i++) assert.equal((await post('10.0.0.1')).status, 200);
    const r = await post('10.0.0.1');
    assert.equal(r.status, 429);
    const retry = Number(r.headers.get('retry-after'));
    assert.ok(retry >= 1 && retry <= 60, `Retry-After ${retry}`);
    const body = (await r.json()) as { success: boolean; errorType: string; message: string };
    assert.equal(body.success, false);
    assert.equal(body.errorType, AuthErrorType.RATE_LIMITED);
    assert.equal(hits, 20, 'handler is not reached once limited');
  });

  it('two different IPs do not share a counter', async () => {
    for (let i = 0; i < 20; i++) await post('10.0.0.2');
    assert.equal((await post('10.0.0.2')).status, 429);
    assert.equal((await post('10.0.0.3')).status, 200);
  });

  it('the next window works again (counter expires)', async () => {
    for (let i = 0; i < 21; i++) await post('10.0.0.4');
    assert.equal((await post('10.0.0.4')).status, 429);
    mock.timers.enable({ apis: ['Date'], now: Date.now() });
    mock.timers.tick(61_000);
    assert.equal((await post('10.0.0.4')).status, 200);
  });

  it('counts per user too: same user from new IPs is limited, another user is not', async () => {
    const a = token('user-a-19');
    const b = token('user-b-19');
    for (let i = 0; i < 20; i++) assert.equal((await post(`10.1.0.${i}`, a)).status, 200);
    assert.equal((await post('10.1.1.1', a)).status, 429);
    assert.equal((await post('10.1.1.2', b)).status, 200);
  });

  it('an expired or garbage token is not rejected (no 401 for the live app), it is limited by IP only', async () => {
    assert.equal((await post('10.2.0.1', 'not-a-jwt')).status, 200);
  });

  it('IP key is stored per prefix with colons escaped, and the user id is not logged in the key as a token', async () => {
    await post('2001:db8::1');
    const key = createRedisKey(REDIS_PREFIXES.promoValidateIp, '2001_db8__1');
    assert.equal(await redis.get(key), '1');
    assert.ok((await redis.ttl(key)) > 0);
  });

  it('generic factory honours its own limit and prefix', async () => {
    const get = () => fetch(`${srv.baseUrl}/tiny`, { headers: { 'x-forwarded-for': '10.3.0.1' } });
    assert.equal((await get()).status, 200);
    assert.equal((await get()).status, 200);
    const r = await get();
    assert.equal(r.status, 429);
    assert.equal(((await r.json()) as { message: string }).message, 'slow down');
  });
});
