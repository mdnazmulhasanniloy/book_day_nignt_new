import { after, before, describe, it } from 'node:test';
import assert from 'node:assert/strict';
import express from 'express';
import { checkUserAccessTokenMiddleware } from '@/app/modules/auth/auth.middlewares';
import { createRedisKey } from '@/app/utils/system.utils';
import { REDIS_PREFIXES } from '@/const';
import {
  FakeQueue,
  FakeRedis,
  installFakeRedis,
  signStripePayload,
  startTestServer,
} from '@/testing/fakes';
import { constructStripeEvent } from '@/app/utils/stripeSignature.utils';
import Stripe from 'stripe';

// Template 2: route + real middleware + fake Redis (no Redis, no DB needed).
describe('route with fake redis', () => {
  let redis: FakeRedis;
  let srv: Awaited<ReturnType<typeof startTestServer>>;
  before(async () => {
    redis = installFakeRedis();
    const app = express();
    app.get('/p', checkUserAccessTokenMiddleware, (_q, r) => { r.json({ ok: true }); });
    srv = await startTestServer(app);
  });
  after(() => srv.close());

  it('no token -> 401', async () => {
    assert.equal((await fetch(`${srv.baseUrl}/p`)).status, 401);
  });
  it('blacklisted token -> 401 TOKEN_BLACKLISTED (reads the fake redis)', async () => {
    await redis.set(createRedisKey(REDIS_PREFIXES.blacklist, 'tok'), '1');
    const r = await fetch(`${srv.baseUrl}/p`, { headers: { Authorization: 'Bearer tok' } });
    assert.equal(r.status, 401);
    assert.match(JSON.stringify(await r.json()), /revoked/i);
  });
});

// Template 3: queue fake records add() calls; Stripe fake signs payloads.
describe('queue and stripe fakes', () => {
  it('a job added with a given name and payload can be asserted', async () => {
    const q = new FakeQueue();
    await q.add('send-email', { to: 'a@example.test' });
    assert.deepEqual(q.find('send-email')[0].data, { to: 'a@example.test' });
    assert.equal(q.find('other').length, 0);
  });
  it('signStripePayload yields a header constructStripeEvent accepts', () => {
    const payload = JSON.stringify({ id: 'evt_1', object: 'event', type: 'account.updated' });
    const signature = signStripePayload(payload, 'whsec_x');
    const evt = constructStripeEvent({ stripe: new Stripe('sk_test_dummy'), payload, signature, secret: 'whsec_x' });
    assert.equal(evt.id, 'evt_1');
  });
});
