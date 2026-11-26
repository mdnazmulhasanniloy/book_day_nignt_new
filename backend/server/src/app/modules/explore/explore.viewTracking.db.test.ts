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
import { FakeRedis, installFakeRedis, startTestServer } from '@/testing/fakes';

// T-041 (CR-11): GET /explore/:id?type=EVENT records a view in a Redis day hash
// (views:<yyyy-mm-dd UTC>, field <eventId>) and, for a logged-in user, a
// UserRecentEventView row (20 newest kept). The request path does NOT write
// EventViewDaily and does NOT touch Event.viewCount (the worker flush does).
// Tracking is best effort: it never delays or fails the response.

const run = randomUUID().replace(/-/g, '').slice(0, 12);
const wait = (ms: number) => new Promise((r) => setTimeout(r, ms));
const until = async (fn: () => Promise<boolean> | boolean, what: string) => {
  for (let i = 0; i < 100; i++) {
    if (await fn()) return;
    await wait(20);
  }
  assert.fail(`timed out waiting for ${what}`);
};

describe('explore view tracking (T-041)', { skip: dbTestSkipReason() }, () => {
  let appPrisma: PrismaClient;
  let srv: Awaited<ReturnType<typeof startTestServer>>;
  let fake: FakeRedis;
  let ownerId: string;
  let viewerId: string;
  let viewerToken: string;
  let eventId: string;
  let canceledId: string;
  let deactivatedId: string;
  const db = () => getTestPrisma();
  const dayKey = () => `views:${new Date().toISOString().slice(0, 10)}`;

  const detail = (id: string, tok?: string) =>
    fetch(`${srv.baseUrl}/api/v1/explore/${id}?type=EVENT`, {
      headers: tok ? { authorization: `Bearer ${tok}` } : {},
    });
  const hash = () => fake.hgetall(dayKey());

  before(async () => {
    process.env.DATABASE_URL = assertSafeTestDatabaseUrl(process.env.TEST_DATABASE_URL);
    fake = installFakeRedis();
    appPrisma = (await import('@/app/configs/db.configs')).default;
    const [{ current_database: name }] = await appPrisma.$queryRaw<{ current_database: string }[]>`select current_database()`;
    assert.match(name, /_test$/, 'app prisma client must target the test DB');

    const mkUser = (label: string) =>
      db().user.create({
        data: {
          name: `T041 ${label}`,
          email: `t041-${run}-${label}@example.test`,
          phoneNumber: `+1555${Math.floor(Math.random() * 1e7)}`,
          isVerified: true,
        },
      });
    const owner = await mkUser('owner');
    const viewer = await mkUser('viewer');
    ownerId = owner.id;
    viewerId = viewer.id;
    const jwt = await import('@/app/utils/jwt.utils');
    viewerToken = jwt.generateAccessTokenForUser({
      sub: viewer.id,
      role: viewer.accountRole,
      isVerified: true,
      accountStatus: viewer.accountStatus,
      rememberMe: true,
    } as never);

    const { createEvent } = await import('@/testing/fixtures');
    eventId = (await createEvent(db(), ownerId, { eventName: `T041 Event ${run}` })).id;
    canceledId = (await createEvent(db(), ownerId, { eventName: `T041 Canceled ${run}`, eventStatus: 'CANCELED' })).id;
    deactivatedId = (await createEvent(db(), ownerId, { eventName: `T041 Off ${run}`, deactivatedAt: new Date() })).id;

    const exploreRoutes = (await import('@/app/modules/explore/explore.routes')).default;
    const { globalErrorMiddleware } = await import('@/app/middlewares/globalError.middlewares');
    const app = express();
    app.use(express.json());
    app.use('/api/v1', exploreRoutes);
    app.use(globalErrorMiddleware);
    srv = await startTestServer(app);
  });

  after(async () => {
    try {
      await db().event.deleteMany({ where: { userId: ownerId } });
      await db().user.deleteMany({ where: { id: { in: [ownerId, viewerId] } } });
    } finally {
      await srv?.close();
      await appPrisma?.$disconnect();
      await closeTestPrisma();
    }
  });

  it('10 anonymous views make 10 Redis increments and no DB write', async () => {
    for (let i = 0; i < 10; i++) {
      const r = await detail(eventId);
      assert.equal(r.status, 200);
    }
    await until(async () => (await hash())[eventId] === '10', '10 increments');
    await wait(100); // any stray DB write would have landed by now
    assert.deepEqual(await hash(), { [eventId]: '10' });
    assert.equal(await db().eventViewDaily.count({ where: { eventId } }), 0);
    const ev = await db().event.findUniqueOrThrow({ where: { id: eventId } });
    assert.equal(ev.viewCount, 0, 'viewCount must not be incremented per request');
    assert.equal(await db().userRecentEventView.count({ where: { eventId } }), 0, 'anonymous gets no recent view');
  });

  it('the day hash gets a 3 day TTL', async () => {
    const ttl = await fake.ttl(dayKey());
    assert.ok(ttl > 3 * 86400 - 60 && ttl <= 3 * 86400, `ttl was ${ttl}`);
  });

  it('a canceled, deactivated or missing event records nothing', async () => {
    const before = await hash();
    const canceled = await detail(canceledId, viewerToken);
    assert.equal(canceled.status, 200, 'canceled event detail still answers as before');
    assert.equal((await detail(deactivatedId, viewerToken)).status, 404);
    assert.equal((await detail(randomUUID(), viewerToken)).status, 404);
    await wait(150);
    assert.deepEqual(await hash(), before);
    assert.equal(await db().userRecentEventView.count({ where: { userId: viewerId } }), 0);
    assert.equal(await db().eventViewDaily.count({ where: { eventId: { in: [canceledId, deactivatedId] } } }), 0);
  });

  it('a logged-in view also records a recent view; a repeat view does not duplicate it', async () => {
    assert.equal((await detail(eventId, viewerToken)).status, 200);
    await until(async () => (await db().userRecentEventView.count({ where: { userId: viewerId } })) === 1, 'recent view');
    const first = await db().userRecentEventView.findFirstOrThrow({ where: { userId: viewerId } });
    await wait(15);
    assert.equal((await detail(eventId, viewerToken)).status, 200);
    await until(async () => {
      const row = await db().userRecentEventView.findFirstOrThrow({ where: { userId: viewerId } });
      return row.lastViewedAt > first.lastViewedAt;
    }, 'refreshed lastViewedAt');
    assert.equal(await db().userRecentEventView.count({ where: { userId: viewerId } }), 1);
    await until(async () => (await hash())[eventId] === '12', 'redis counts both');
  });

  it('keeps only the 20 newest recent views per user', async () => {
    const { createEvent } = await import('@/testing/fixtures');
    const ids: string[] = [];
    for (let i = 0; i < 24; i++) {
      ids.push((await createEvent(db(), ownerId, { eventName: `T041 R${i} ${run}` })).id);
    }
    for (const id of ids) {
      assert.equal((await detail(id, viewerToken)).status, 200);
      await until(async () => (await db().userRecentEventView.count({ where: { userId: viewerId, eventId: id } })) === 1, 'recent row');
      await wait(5);
    }
    await until(async () => (await db().userRecentEventView.count({ where: { userId: viewerId } })) === 20, 'trimmed to 20');
    const rows = await db().userRecentEventView.findMany({ where: { userId: viewerId }, select: { eventId: true } });
    const kept = new Set(rows.map((r) => r.eventId));
    for (const id of ids.slice(4)) assert.ok(kept.has(id), 'newest 20 are kept');
    for (const id of ids.slice(0, 4)) assert.ok(!kept.has(id), 'oldest are dropped');
    assert.ok(!kept.has(eventId), 'the older view of the first event is dropped too');
  });

  it('when Redis throws the request still answers 200 with the normal body and the view is dropped', async () => {
    const client = (await import('@/app/configs/redis.configs')).getRedisClient() as unknown as Record<string, unknown>;
    const saved = client.hincrby;
    client.hincrby = async () => {
      throw new Error('redis down');
    };
    try {
      const before = await hash();
      const r = await detail(eventId);
      assert.equal(r.status, 200);
      const body = (await r.json()) as { success: boolean; data: { id: string; eventName: string; interestedCount: number } };
      assert.equal(body.success, true);
      assert.equal(body.data.id, eventId);
      assert.equal(body.data.eventName, `T041 Event ${run}`);
      assert.equal(typeof body.data.interestedCount, 'number');
      await wait(100);
      assert.deepEqual(await hash(), before);
    } finally {
      client.hincrby = saved;
    }
  });
});
