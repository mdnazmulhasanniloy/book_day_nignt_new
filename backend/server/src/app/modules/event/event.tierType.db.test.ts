import { after, before, describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import express from 'express';
import type { PrismaClient } from '@prisma/client';
import {
  assertSafeTestDatabaseUrl,
  closeTestPrisma,
  dbTestSkipReason,
  getTestPrisma,
} from '@/testing/testDb';
import { FakeQueue, installFakeRedis, startTestServer } from '@/testing/fakes';

// T-016 (CR-03): tierType through the real POST /event and PUT /event/:id routes,
// real auth middlewares and global error handler. Connect readiness (Stripe) is
// a pass-through, the system queue is a FakeQueue, Redis is the in-memory fake.

const run = randomUUID().replace(/-/g, '').slice(0, 12);

describe('tierType on POST /event and PUT /event/:id (T-016)', { skip: dbTestSkipReason() }, () => {
  let appPrisma: PrismaClient;
  let srv: Awaited<ReturnType<typeof startTestServer>>;
  let ownerId: string;
  let ownerToken: string;
  const queue = new FakeQueue();
  const db = () => getTestPrisma();

  const send = (method: 'POST' | 'PUT', path: string, body: unknown) =>
    fetch(`${srv.baseUrl}/api/v1${path}`, {
      method,
      headers: { 'content-type': 'application/json', authorization: `Bearer ${ownerToken}` },
      body: JSON.stringify(body),
    });

  const eventBody = (ticketTiers?: unknown[]) => ({
    eventName: `T016 ${run}`,
    thumbnail: 'https://example.test/t.png',
    images: [],
    lat: 23.78,
    lng: 90.4,
    location: 'Somewhere',
    startAt: '2031-01-01T10:00:00Z',
    endAt: '2031-01-02T10:00:00Z',
    dressCode: 'casual',
    eventPrice: 10,
    currency: 'USD',
    ...(ticketTiers ? { ticketTiers } : {}),
  });

  const tier = (tierName: string, extra: Record<string, unknown> = {}) => ({
    tierName,
    price: 10,
    capacity: 50,
    ...extra,
  });

  before(async () => {
    process.env.DATABASE_URL = assertSafeTestDatabaseUrl(process.env.TEST_DATABASE_URL);
    installFakeRedis();
    appPrisma = (await import('@/app/configs/db.configs')).default;

    const swap = (id: string, exports: unknown) => {
      const p = require.resolve(id);
      require.cache[p] = { id: p, filename: p, loaded: true, exports } as unknown as NodeJS.Module;
    };
    swap('@/app/modules/connect/connect.middlewares', {
      checkConnectReadinessMiddleware: (_q: unknown, _r: unknown, next: () => void) => next(),
    });
    swap('@/app/queues/system/system.queue', { getSystemQueue: () => queue });
    // getUsersNearby would call redis.call (not faked): replace the notification helpers.
    swap('@/app/modules/notification/notification.helpers', {
      getUsersNearby: async () => [],
      sendPushNotification: async () => undefined,
    });

    const owner = await db().user.create({
      data: {
        name: 'T016 owner',
        email: `t016-${run}-owner@example.test`,
        phoneNumber: `+1555${Math.floor(Math.random() * 1e7)}`,
        accountRole: 'CLUB_OWNER',
        isVerified: true,
      },
    });
    ownerId = owner.id;
    const jwt = await import('@/app/utils/jwt.utils');
    ownerToken = jwt.generateAccessTokenForUser({
      sub: owner.id,
      role: owner.accountRole,
      isVerified: true,
      accountStatus: owner.accountStatus,
      rememberMe: true,
    } as never);

    const routes = (await import('@/app/modules/event/event.routes')).default;
    const { globalErrorMiddleware } = await import('@/app/middlewares/globalError.middlewares');
    const app = express();
    app.use(express.json());
    app.use('/api/v1', routes);
    app.use(globalErrorMiddleware);
    srv = await startTestServer(app);
  });

  after(async () => {
    try {
      const events = await db().event.findMany({ where: { userId: ownerId }, select: { id: true } });
      await db().event.deleteMany({ where: { id: { in: events.map((e) => e.id) } } });
      await db().user.deleteMany({ where: { id: ownerId } });
    } finally {
      await srv?.close();
      await appPrisma?.$disconnect();
      await closeTestPrisma();
    }
  });

  it('create without tierType stores TICKET (old client)', async () => {
    const r = await send('POST', '/event', eventBody([tier('Early')]));
    assert.equal(r.status, 201);
    const { data } = (await r.json()) as { data: { id: string } };
    const rows = await db().eventTicketTier.findMany({ where: { eventId: data.id } });
    assert.equal(rows.length, 1);
    assert.equal(rows[0].tierType, 'TICKET');
  });

  it('create with PASS on a section and TICKET on a child persists both and returns them on detail', async () => {
    const r = await send(
      'POST',
      '/event',
      eventBody([tier('2-Day Pass', { tierType: 'PASS', children: [tier('Blind Pass', { tierType: 'PASS' }), tier('Early')] })])
    );
    assert.equal(r.status, 201);
    const { data } = (await r.json()) as { data: { id: string } };
    const rows = await db().eventTicketTier.findMany({ where: { eventId: data.id } });
    assert.equal(rows.find((t) => t.tierName === '2-Day Pass')?.tierType, 'PASS');
    assert.equal(rows.find((t) => t.tierName === 'Blind Pass')?.tierType, 'PASS');
    assert.equal(rows.find((t) => t.tierName === 'Early')?.tierType, 'TICKET');

    const d = await fetch(`${srv.baseUrl}/api/v1/event/${data.id}`, {
      headers: { authorization: `Bearer ${ownerToken}` },
    });
    assert.equal(d.status, 200);
    const body = (await d.json()) as {
      data: { ticketTiers: { tierName: string; tierType: string; children: { tierName: string; tierType: string }[] }[] };
    };
    assert.equal(body.data.ticketTiers[0].tierType, 'PASS');
    const kids = Object.fromEntries(body.data.ticketTiers[0].children.map((c) => [c.tierName, c.tierType]));
    assert.deepEqual(kids, { 'Blind Pass': 'PASS', Early: 'TICKET' });
  });

  it('create with an invalid tierType returns 422 and creates nothing', async () => {
    const count = await db().event.count({ where: { userId: ownerId } });
    const r = await send('POST', '/event', eventBody([tier('X', { tierType: 'VIP' })]));
    assert.equal(r.status, 422);
    assert.equal(await db().event.count({ where: { userId: ownerId } }), count);
  });

  it('update with PASS (matched by id) persists; omitting tierType later keeps PASS; invalid value is 422', async () => {
    const created = await send('POST', '/event', eventBody([tier('Standard')]));
    const { data } = (await created.json()) as { data: { id: string } };
    const row = (await db().eventTicketTier.findMany({ where: { eventId: data.id } }))[0];

    const up = await send('PUT', `/event/${data.id}`, { ticketTiers: [tier('Standard Pass', { id: row.id, tierType: 'PASS' })] });
    assert.equal(up.status, 200);
    assert.equal((await db().eventTicketTier.findUniqueOrThrow({ where: { id: row.id } })).tierType, 'PASS');

    // Live-app style update: no id, no tierType; matched by name; tierType must not reset.
    const old = await send('PUT', `/event/${data.id}`, { ticketTiers: [tier('Standard Pass', { price: 12 })] });
    assert.equal(old.status, 200);
    const reread = await db().eventTicketTier.findUniqueOrThrow({ where: { id: row.id } });
    assert.equal(reread.tierType, 'PASS');
    assert.equal(Number(reread.price), 12);

    const bad = await send('PUT', `/event/${data.id}`, { ticketTiers: [tier('Standard Pass', { id: row.id, tierType: 'NOPE' })] });
    assert.equal(bad.status, 422);
    assert.equal((await db().eventTicketTier.findUniqueOrThrow({ where: { id: row.id } })).tierType, 'PASS');
  });

  it('update can switch PASS back to TICKET explicitly', async () => {
    const created = await send('POST', '/event', eventBody([tier('Late Pass', { tierType: 'PASS' })]));
    const { data } = (await created.json()) as { data: { id: string } };
    const row = (await db().eventTicketTier.findMany({ where: { eventId: data.id } }))[0];
    const up = await send('PUT', `/event/${data.id}`, { ticketTiers: [tier('Late', { id: row.id, tierType: 'TICKET' })] });
    assert.equal(up.status, 200);
    assert.equal((await db().eventTicketTier.findUniqueOrThrow({ where: { id: row.id } })).tierType, 'TICKET');
  });

  it('a tier that already has sales cannot become a section (422), nothing changes', async () => {
    const created = await send('POST', '/event', eventBody([tier('Day 1')]));
    const { data } = (await created.json()) as { data: { id: string } };
    const row = (await db().eventTicketTier.findMany({ where: { eventId: data.id } }))[0];
    await db().eventTicketTier.update({ where: { id: row.id }, data: { soldCount: 3 } });
    const r = await send('PUT', `/event/${data.id}`, { ticketTiers: [tier('Day 1', { id: row.id, children: [tier('Early')] })] });
    assert.equal(r.status, 422);
    assert.equal(await db().eventTicketTier.count({ where: { eventId: data.id } }), 1);
  });
});
