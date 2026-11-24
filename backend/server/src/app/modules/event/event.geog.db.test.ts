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

// T-030 (CR-09, BUG-B02, BUG-B25): Event.geog must follow lat/lng on create, update and
// duplicate, through the real routes. Connect readiness is a pass-through, the system queue is a
// FakeQueue, nearby-user helpers are faked, Redis is the in-memory fake.

const run = randomUUID().replace(/-/g, '').slice(0, 12);

type EventData = Record<string, unknown> & { id: string };
type Point = { lat: number; lng: number } | null;

describe('Event.geog stays in step with lat/lng (T-030)', { skip: dbTestSkipReason() }, () => {
  let appPrisma: PrismaClient;
  let srv: Awaited<ReturnType<typeof startTestServer>>;
  let ownerId: string;
  let ownerToken: string;
  const queue = new FakeQueue();
  const db = () => getTestPrisma();

  const send = (method: 'POST' | 'PUT', path: string, body?: unknown) =>
    fetch(`${srv.baseUrl}/api/v1${path}`, {
      method,
      headers: { 'content-type': 'application/json', authorization: `Bearer ${ownerToken}` },
      ...(body === undefined ? {} : { body: JSON.stringify(body) }),
    });

  // Remote spot (south of New Zealand) so the explore radius check cannot see other test data.
  const eventBody = (extra: Record<string, unknown> = {}) => ({
    eventName: `T030 ${run}`,
    thumbnail: 'https://example.test/t.png',
    images: [],
    lat: -45.5,
    lng: 170.25,
    location: 'Remote',
    startAt: '2031-01-01T10:00:00Z',
    endAt: '2031-01-02T10:00:00Z',
    dressCode: 'casual',
    eventPrice: 10,
    currency: 'USD',
    ...extra,
  });
  const create = async (extra: Record<string, unknown> = {}) => {
    const r = await send('POST', '/event', eventBody(extra));
    const json = (await r.json()) as { data: EventData };
    return { status: r.status, data: json.data };
  };
  const geogOf = async (id: string): Promise<Point> => {
    const rows = await db().$queryRaw<{ lat: number | null; lng: number | null }[]>`
      SELECT ST_Y(geog::geometry) AS lat, ST_X(geog::geometry) AS lng FROM "Event" WHERE id = ${id}`;
    const row = rows[0];
    return row && row.lat !== null && row.lng !== null ? { lat: row.lat, lng: row.lng } : null;
  };
  const near = (p: Point, lat: number, lng: number) => {
    assert.ok(p, 'geog is not null');
    assert.ok(Math.abs(p.lat - lat) < 1e-9, `geog lat ${p.lat} vs ${lat}`);
    assert.ok(Math.abs(p.lng - lng) < 1e-9, `geog lng ${p.lng} vs ${lng}`);
  };

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
        name: 'T030 owner',
        email: `t030-${run}-owner@example.test`,
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

  it('create sets geog from lat/lng', async () => {
    const c = await create();
    assert.equal(c.status, 201);
    near(await geogOf(c.data.id), -45.5, 170.25);
  });

  it('update with new lat and lng moves geog', async () => {
    const c = await create();
    const r = await send('PUT', `/event/${c.data.id}`, { lat: -44.1, lng: 169.5 });
    assert.equal(r.status, 200);
    near(await geogOf(c.data.id), -44.1, 169.5);
  });

  it('update with only lat or only lng recomputes geog from the stored pair', async () => {
    const c = await create();
    assert.equal((await send('PUT', `/event/${c.data.id}`, { lat: -40 })).status, 200);
    near(await geogOf(c.data.id), -40, 170.25);
    assert.equal((await send('PUT', `/event/${c.data.id}`, { lng: 171 })).status, 200);
    near(await geogOf(c.data.id), -40, 171);
    const row = await db().event.findUniqueOrThrow({ where: { id: c.data.id } });
    assert.equal(row.lat, -40);
    assert.equal(row.lng, 171);
  });

  it('update that does not touch lat/lng leaves geog as it is', async () => {
    const c = await create();
    // Plant a recognisable geog that differs from lat/lng; an unrelated update must not rewrite it.
    await db().$executeRaw`UPDATE "Event" SET geog = ST_SetSRID(ST_MakePoint(10, 20), 4326)::geography WHERE id = ${c.data.id}`;
    const r = await send('PUT', `/event/${c.data.id}`, { eventName: `T030 renamed ${run}` });
    assert.equal(r.status, 200);
    near(await geogOf(c.data.id), 20, 10);
  });

  it('invalid coordinates are rejected (422) and geog and lat/lng stay as they were', async () => {
    const c = await create();
    for (const body of [{ lat: 91, lng: 0 }, { lat: 0, lng: 181 }, { lat: 'x', lng: 1 }]) {
      const r = await send('PUT', `/event/${c.data.id}`, body);
      assert.equal(r.status, 422);
    }
    const bad = await send('POST', '/event', eventBody({ lat: 95 }));
    assert.equal(bad.status, 422);
    near(await geogOf(c.data.id), -45.5, 170.25);
    const row = await db().event.findUniqueOrThrow({ where: { id: c.data.id } });
    assert.equal(row.lat, -45.5);
  });

  it('duplicate copies lat/lng and sets geog; the copy appears in /explore with ST_DWithin', async () => {
    const src = await create({ lat: -46.25, lng: 168.75 });
    const r = await send('POST', `/event/${src.data.id}/duplicate`);
    assert.equal(r.status, 201);
    const copy = ((await r.json()) as { data: EventData }).data;
    assert.notEqual(copy.id, src.data.id);
    assert.equal(copy.lat, -46.25);
    assert.equal(copy.lng, 168.75);
    near(await geogOf(copy.id), -46.25, 168.75);

    const { exploreListService } = await import('@/app/modules/explore/explore.services');
    const res = await exploreListService({
      query: { type: 'EVENT', lat: -46.25, lng: 168.75, page: 1, limit: 50 } as never,
    });
    const hit = res.data.find((i) => i.id === copy.id);
    assert.ok(hit, 'duplicated event is returned by the geo-filtered explore list');
    assert.equal(hit.lat, -46.25);
    assert.equal(hit.lng, 168.75);
    const far = await exploreListService({
      query: { type: 'EVENT', lat: 51.5, lng: -0.12, page: 1, limit: 50 } as never,
    });
    assert.ok(!far.data.some((i) => i.id === copy.id), 'not returned for a far-away centre');
  });

  it('no event of this run has lat set and geog NULL', async () => {
    const rows = await db().$queryRaw<{ n: bigint }[]>`
      SELECT COUNT(*) AS n FROM "Event" WHERE "userId" = ${ownerId} AND geog IS NULL AND lat IS NOT NULL`;
    assert.equal(Number(rows[0].n), 0);
  });
});
