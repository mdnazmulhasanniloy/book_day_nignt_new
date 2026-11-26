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
import { installFakeRedis, startTestServer } from '@/testing/fakes';

// T-040 (CR-11): POST/DELETE /events/:eventId/interested and interestedCount.
// Real interest router + explore router, real auth middlewares, error handler.
// Client decision (Q6d): count only, no route may list who is interested.

const run = randomUUID().replace(/-/g, '').slice(0, 12);

describe('Interested (T-040)', { skip: dbTestSkipReason() }, () => {
  let appPrisma: PrismaClient;
  let srv: Awaited<ReturnType<typeof startTestServer>>;
  let router: { stack: { route?: { path: string; methods: Record<string, boolean> } }[] };
  const tokens: string[] = [];
  const userIds: string[] = [];
  let eventId: string;
  let canceledId: string;
  let deactivatedId: string;
  const db = () => getTestPrisma();
  type Body = {
    success: boolean;
    message: string;
    errorType?: string;
    data?: Record<string, unknown>;
  };

  const call = (method: 'POST' | 'DELETE', id: string, tok?: string) =>
    fetch(`${srv.baseUrl}/api/v1/events/${id}/interested`, {
      method,
      headers: tok ? { authorization: `Bearer ${tok}` } : {},
    });
  const dbCount = (id = eventId) => db().eventInterest.count({ where: { eventId: id } });
  const detail = async (tok?: string) => {
    const r = await fetch(`${srv.baseUrl}/api/v1/explore/${eventId}?type=EVENT`, {
      headers: tok ? { authorization: `Bearer ${tok}` } : {},
    });
    assert.equal(r.status, 200);
    return ((await r.json()) as Body).data as Record<string, unknown>;
  };

  before(async () => {
    process.env.DATABASE_URL = assertSafeTestDatabaseUrl(process.env.TEST_DATABASE_URL);
    installFakeRedis();
    appPrisma = (await import('@/app/configs/db.configs')).default;
    const [{ current_database: name }] = await appPrisma.$queryRaw<{ current_database: string }[]>`select current_database()`;
    assert.match(name, /_test$/, 'app prisma client must target the test DB');

    const jwt = await import('@/app/utils/jwt.utils');
    for (let i = 0; i < 3; i++) {
      const user = await db().user.create({
        data: {
          name: `T040 user ${i}`,
          email: `t040-${run}-${i}@example.test`,
          phoneNumber: `+1555${Math.floor(Math.random() * 1e7)}`,
          isVerified: true,
        },
      });
      userIds.push(user.id);
      tokens.push(
        jwt.generateAccessTokenForUser({
          sub: user.id,
          role: user.accountRole,
          isVerified: true,
          accountStatus: user.accountStatus,
          rememberMe: true,
        } as never)
      );
    }
    const { createEvent } = await import('@/testing/fixtures');
    eventId = (await createEvent(db(), userIds[0], { eventName: `T040 Event ${run}` })).id;
    canceledId = (await createEvent(db(), userIds[0], { eventName: `T040 Canceled ${run}`, eventStatus: 'CANCELED' })).id;
    deactivatedId = (await createEvent(db(), userIds[0], { eventName: `T040 Off ${run}`, deactivatedAt: new Date() })).id;

    const interestRoutes = (await import('@/app/modules/interest/interest.routes')).default;
    router = interestRoutes as unknown as typeof router;
    const exploreRoutes = (await import('@/app/modules/explore/explore.routes')).default;
    const { globalErrorMiddleware } = await import('@/app/middlewares/globalError.middlewares');
    const app = express();
    app.use(express.json());
    app.use('/api/v1', interestRoutes);
    app.use('/api/v1', exploreRoutes);
    app.use(globalErrorMiddleware);
    srv = await startTestServer(app);
  });

  after(async () => {
    try {
      await db().eventInterest.deleteMany({ where: { userId: { in: userIds } } });
      await db().event.deleteMany({ where: { userId: { in: userIds } } });
      await db().user.deleteMany({ where: { id: { in: userIds } } });
    } finally {
      await srv?.close();
      await appPrisma?.$disconnect();
      await closeTestPrisma();
    }
  });

  it('POST twice: 200 both times (no 409), same state, one row', async () => {
    const r1 = await call('POST', eventId, tokens[0]);
    assert.equal(r1.status, 200);
    const b1 = (await r1.json()) as Body;
    assert.equal(b1.success, true);
    assert.deepEqual(b1.data, { isInterested: true, interestedCount: 1 });
    const r2 = await call('POST', eventId, tokens[0]);
    assert.equal(r2.status, 200);
    assert.deepEqual(((await r2.json()) as Body).data, { isInterested: true, interestedCount: 1 });
    assert.equal(await dbCount(), 1);
  });

  it('two users give count 2', async () => {
    const r = await call('POST', eventId, tokens[1]);
    assert.equal(r.status, 200);
    assert.deepEqual(((await r.json()) as Body).data, { isInterested: true, interestedCount: 2 });
  });

  it('explore detail shows the live count and only the caller own state', async () => {
    const d = await detail(tokens[2]);
    assert.equal(d.interestedCount, 2);
    assert.equal(d.isInterested, false);
    assert.equal((await detail(tokens[0])).isInterested, true);
    const a = await detail();
    assert.equal(a.interestedCount, 2);
    assert.ok(!('isInterested' in a), 'isInterested is bearer only');
    // live COUNT(*): a row added behind the API shows up at once
    await db().eventInterest.create({ data: { userId: userIds[2], eventId } });
    assert.equal((await detail()).interestedCount, 3);
    await db().eventInterest.deleteMany({ where: { userId: userIds[2], eventId } });
  });

  it('DELETE twice is idempotent and never negative', async () => {
    const r1 = await call('DELETE', eventId, tokens[1]);
    assert.equal(r1.status, 200);
    assert.deepEqual(((await r1.json()) as Body).data, { isInterested: false, interestedCount: 1 });
    const r2 = await call('DELETE', eventId, tokens[1]);
    assert.equal(r2.status, 200);
    assert.deepEqual(((await r2.json()) as Body).data, { isInterested: false, interestedCount: 1 });
    // a user who never marked interest
    const r3 = await call('DELETE', eventId, tokens[2]);
    assert.equal(r3.status, 200);
    assert.deepEqual(((await r3.json()) as Body).data, { isInterested: false, interestedCount: 1 });
    await call('DELETE', eventId, tokens[0]);
    const r4 = await call('DELETE', eventId, tokens[0]);
    assert.deepEqual(((await r4.json()) as Body).data, { isInterested: false, interestedCount: 0 });
    assert.equal(await dbCount(), 0);
  });

  it('only touches the token user rows', async () => {
    await call('POST', eventId, tokens[0]);
    await call('POST', eventId, tokens[1]);
    await call('DELETE', eventId, tokens[1]);
    const rows = await db().eventInterest.findMany({ where: { eventId } });
    assert.deepEqual(rows.map((x) => x.userId), [userIds[0]]);
    await call('DELETE', eventId, tokens[0]);
  });

  it('unknown, canceled and deactivated events -> 404 (never 401/403)', async () => {
    for (const id of [randomUUID(), canceledId, deactivatedId]) {
      for (const m of ['POST', 'DELETE'] as const) {
        const r = await call(m, id, tokens[0]);
        assert.equal(r.status, 404, `${m} ${id}`);
        const b = (await r.json()) as Body;
        assert.equal(b.success, false);
        assert.equal(b.errorType, 'NOT_FOUND');
      }
    }
    assert.equal(await dbCount(canceledId), 0);
  });

  it('malformed id -> 422', async () => {
    const r = await call('POST', 'not-a-uuid', tokens[0]);
    assert.equal(r.status, 422);
  });

  it('unauthenticated or bad token -> 401', async () => {
    assert.equal((await call('POST', eventId)).status, 401);
    assert.equal((await call('DELETE', eventId)).status, 401);
    assert.equal((await call('POST', eventId, 'garbage')).status, 401);
    assert.equal(await dbCount(), 0);
  });

  it('PARALLEL identical POSTs leave exactly one row and no 500', async () => {
    const rs = await Promise.all(Array.from({ length: 12 }, () => call('POST', eventId, tokens[2])));
    assert.deepEqual(rs.map((r) => r.status), Array(12).fill(200));
    for (const r of rs) {
      assert.deepEqual(((await r.json()) as Body).data, { isInterested: true, interestedCount: 1 });
    }
    assert.equal(await db().eventInterest.count({ where: { eventId, userId: userIds[2] } }), 1);
    await call('DELETE', eventId, tokens[2]);
  });

  it('there is NO route that lists interested users (count only, Q6d)', async () => {
    const paths = router.stack
      .filter((l) => l.route)
      .map((l) => `${Object.keys(l.route!.methods).join(',').toUpperCase()} ${l.route!.path}`)
      .sort();
    assert.deepEqual(paths, [
      'DELETE /events/:eventId/interested',
      'POST /events/:eventId/interested',
    ]);
    const plausible = [
      `/events/${eventId}/interested`,
      `/events/${eventId}/interested/users`,
      `/events/${eventId}/interested-users`,
      `/events/${eventId}/attendees`,
      `/events/${eventId}/interests`,
      `/explore/${eventId}/interested`,
      `/me/interested`,
    ];
    for (const p of plausible) {
      const r = await fetch(`${srv.baseUrl}/api/v1${p}`, { headers: { authorization: `Bearer ${tokens[0]}` } });
      assert.ok([404, 405, 422].includes(r.status), `GET ${p} -> ${r.status}`);
      const text = await r.text();
      assert.ok(!text.includes('T040 user'), `GET ${p} must not reveal names`);
    }
  });
});
