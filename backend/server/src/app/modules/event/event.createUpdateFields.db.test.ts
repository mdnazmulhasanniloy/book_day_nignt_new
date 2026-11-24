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

// T-017 (CR-03, CR-17): timezone, pricingMode and optional descriptions through the real
// POST /event and PUT /event/:id routes. Connect readiness is a pass-through, the system queue
// is a FakeQueue, nearby-user helpers are faked, Redis is the in-memory fake.

const run = randomUUID().replace(/-/g, '').slice(0, 12);

type EventData = Record<string, unknown> & { id: string };

describe('timezone, pricingMode, descriptions on POST /event and PUT /event/:id (T-017)', { skip: dbTestSkipReason() }, () => {
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

  // lat/lng are in Dhaka on purpose: the time zone must NOT be inferred from them.
  const eventBody = (extra: Record<string, unknown> = {}) => ({
    eventName: `T017 ${run}`,
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
    ...extra,
  });
  const tier = (tierName: string, price: number, extra: Record<string, unknown> = {}) => ({
    tierName,
    price,
    capacity: 50,
    ...extra,
  });
  const create = async (extra: Record<string, unknown> = {}) => {
    const r = await send('POST', '/event', eventBody(extra));
    const json = (await r.json()) as { data: EventData };
    return { status: r.status, data: json.data };
  };
  const eventCount = () => db().event.count({ where: { userId: ownerId } });

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
    swap('@/app/modules/notification/notification.helpers', {
      getUsersNearby: async () => [],
      sendPushNotification: async () => undefined,
    });

    const owner = await db().user.create({
      data: {
        name: 'T017 owner',
        email: `t017-${run}-owner@example.test`,
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

  it('create without the new fields: timezone UTC (not inferred from coordinates), pricingMode derived, old fields intact', async () => {
    const single = await create();
    assert.equal(single.status, 201);
    assert.equal(single.data.timezone, 'UTC');
    assert.equal(single.data.pricingMode, 'SINGLE');
    for (const key of ['id', 'eventName', 'eventPrice', 'currency', 'lat', 'lng', 'startAt', 'endAt', 'eventDescription']) {
      assert.ok(key in single.data, `response keeps ${key}`);
    }

    const free = await create({ eventPrice: 0 });
    assert.equal(free.status, 201);
    assert.equal(free.data.pricingMode, 'FREE');
    assert.equal(free.data.timezone, 'UTC');

    const tiered = await create({ eventPrice: 0, ticketTiers: [tier('Early', 10)] });
    assert.equal(tiered.status, 201);
    assert.equal(tiered.data.pricingMode, 'TIERED');
    const stored = await db().event.findUniqueOrThrow({ where: { id: tiered.data.id } });
    assert.equal(stored.pricingMode, 'TIERED');
    assert.equal(stored.timezone, 'UTC');
  });

  it('create with timezone and pricingMode stores and returns them; detail returns them too', async () => {
    const r = await create({
      timezone: 'Asia/Dhaka',
      pricingMode: 'MIXED',
      ticketTiers: [tier('Free entry', 0), tier('VIP', 30)],
    });
    assert.equal(r.status, 201);
    assert.equal(r.data.timezone, 'Asia/Dhaka');
    assert.equal(r.data.pricingMode, 'MIXED');
    const d = await fetch(`${srv.baseUrl}/api/v1/event/${r.data.id}`, { headers: { authorization: `Bearer ${ownerToken}` } });
    const body = (await d.json()) as { data: EventData };
    assert.equal(body.data.timezone, 'Asia/Dhaka');
    assert.equal(body.data.pricingMode, 'MIXED');
  });

  it('invalid timezone is 422 on create and update and changes nothing', async () => {
    const before = await eventCount();
    const bad = await send('POST', '/event', eventBody({ timezone: 'Mars/Olympus' }));
    assert.equal(bad.status, 422);
    assert.equal(await eventCount(), before);

    const ok = await create({ timezone: 'Europe/Paris' });
    const up = await send('PUT', `/event/${ok.data.id}`, { timezone: 'not a zone' });
    assert.equal(up.status, 422);
    assert.equal((await db().event.findUniqueOrThrow({ where: { id: ok.data.id } })).timezone, 'Europe/Paris');
  });

  it('update changes timezone; an update without it keeps the stored one (old client)', async () => {
    const ok = await create({ timezone: 'Europe/Paris' });
    const keep = await send('PUT', `/event/${ok.data.id}`, { eventName: `T017 renamed ${run}` });
    assert.equal(keep.status, 200);
    assert.equal((await db().event.findUniqueOrThrow({ where: { id: ok.data.id } })).timezone, 'Europe/Paris');
    const change = await send('PUT', `/event/${ok.data.id}`, { timezone: 'America/New_York' });
    assert.equal(change.status, 200);
    const json = (await change.json()) as { data: EventData };
    assert.equal(json.data.timezone, 'America/New_York');
  });

  it('each pricingMode inconsistency is 422 on create and creates nothing', async () => {
    const before = await eventCount();
    const cases: Array<Record<string, unknown>> = [
      { pricingMode: 'TIERED' },
      { pricingMode: 'SINGLE', ticketTiers: [tier('A', 5)] },
      { pricingMode: 'FREE', eventPrice: 5 },
      { pricingMode: 'FREE', eventPrice: 0, ticketTiers: [tier('A', 5)] },
      { pricingMode: 'MIXED', ticketTiers: [tier('A', 5)] },
      { pricingMode: 'MIXED', ticketTiers: [tier('A', 0)] },
      { pricingMode: 'NOPE' },
    ];
    for (const extra of cases) {
      const r = await send('POST', '/event', eventBody(extra));
      assert.equal(r.status, 422, JSON.stringify(extra));
    }
    assert.equal(await eventCount(), before);
  });

  it('update: inconsistent pricingMode is 422 and rolls back; consistent change works; not sent keeps the stored mode', async () => {
    const ev = await create({ ticketTiers: [tier('Early', 10)] });
    assert.equal(ev.data.pricingMode, 'TIERED');

    const bad = await send('PUT', `/event/${ev.data.id}`, { pricingMode: 'SINGLE', eventName: `T017 nope ${run}` });
    assert.equal(bad.status, 422);
    const after = await db().event.findUniqueOrThrow({ where: { id: ev.data.id } });
    assert.equal(after.pricingMode, 'TIERED');
    assert.equal(after.eventName, `T017 ${run}`);

    const mixed = await send('PUT', `/event/${ev.data.id}`, {
      pricingMode: 'MIXED',
      ticketTiers: [tier('Early', 10), tier('Guest list', 0)],
    });
    assert.equal(mixed.status, 200);
    assert.equal((await db().event.findUniqueOrThrow({ where: { id: ev.data.id } })).pricingMode, 'MIXED');

    // Old client: sends tiers, no pricingMode. MIXED stays while still consistent.
    const old = await send('PUT', `/event/${ev.data.id}`, { ticketTiers: [tier('Early', 12), tier('Guest list', 0)] });
    assert.equal(old.status, 200);
    assert.equal((await db().event.findUniqueOrThrow({ where: { id: ev.data.id } })).pricingMode, 'MIXED');

    // Old client drops the free tier: stored MIXED is no longer consistent, so it is derived (TIERED), never a 422.
    const drop = await send('PUT', `/event/${ev.data.id}`, { ticketTiers: [tier('Early', 12)] });
    assert.equal(drop.status, 200);
    assert.equal((await db().event.findUniqueOrThrow({ where: { id: ev.data.id } })).pricingMode, 'TIERED');

    // Explicit pricingMode alone is checked against the stored tiers.
    const alone = await send('PUT', `/event/${ev.data.id}`, { pricingMode: 'FREE' });
    assert.equal(alone.status, 422);
  });

  it('description round trip: event, section and tier; empty string is stored as NULL', async () => {
    const ev = await create({
      eventDescription: 'Big night',
      ticketTiers: [tier('Day 1', 10, { description: 'Section text', children: [tier('Early', 10, { description: 'Tier text' }), tier('Late', 12, { description: '' })] })],
    });
    assert.equal(ev.status, 201);
    assert.equal(ev.data.eventDescription, 'Big night');
    const rows = await db().eventTicketTier.findMany({ where: { eventId: ev.data.id } });
    assert.equal(rows.find((t) => t.tierName === 'Day 1')?.description, 'Section text');
    assert.equal(rows.find((t) => t.tierName === 'Early')?.description, 'Tier text');
    assert.equal(rows.find((t) => t.tierName === 'Late')?.description, null);

    const d = await fetch(`${srv.baseUrl}/api/v1/event/${ev.data.id}`, { headers: { authorization: `Bearer ${ownerToken}` } });
    const body = (await d.json()) as {
      data: { eventDescription: string; ticketTiers: { description: string | null; children: { tierName: string; description: string | null }[] }[] };
    };
    assert.equal(body.data.eventDescription, 'Big night');
    assert.equal(body.data.ticketTiers[0].description, 'Section text');
    assert.deepEqual(
      Object.fromEntries(body.data.ticketTiers[0].children.map((c) => [c.tierName, c.description])),
      { Early: 'Tier text', Late: null }
    );

    const clear = await send('PUT', `/event/${ev.data.id}`, {
      eventDescription: '',
      ticketTiers: [tier('Day 1', 10, { description: '', children: [tier('Early', 10, { description: 'Tier text' }), tier('Late', 12)] })],
    });
    assert.equal(clear.status, 200);
    assert.equal((await db().event.findUniqueOrThrow({ where: { id: ev.data.id } })).eventDescription, null);
    const reread = await db().eventTicketTier.findMany({ where: { eventId: ev.data.id } });
    assert.equal(reread.find((t) => t.tierName === 'Day 1')?.description, null);
    assert.equal(reread.find((t) => t.tierName === 'Early')?.description, 'Tier text');

    const noDesc = await create();
    assert.equal(noDesc.status, 201);
    assert.equal(noDesc.data.eventDescription, null);
  });
});
