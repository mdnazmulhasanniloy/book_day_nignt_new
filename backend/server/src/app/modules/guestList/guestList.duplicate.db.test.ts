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

// T-020 (B-29, CR-06): a user with a PENDING or CONFIRMED (the "approved"
// state in the schema) entry for the same event cannot join again: 409
// GUEST_LIST_DUPLICATE. A REJECTED entry does not block. Parallel identical
// joins create exactly one row. Real guestList router, auth middlewares and
// error handler. Rows are committed (parallel requests use several
// connections), so the after hook deletes them.

const run = randomUUID().replace(/-/g, '').slice(0, 12);

describe('POST /event/:eventId/guest-list/join duplicates (T-020)', { skip: dbTestSkipReason() }, () => {
  let appPrisma: PrismaClient;
  let srv: Awaited<ReturnType<typeof startTestServer>>;
  const db = () => getTestPrisma();
  const userIds: string[] = [];
  const tokens: Record<string, string> = {};
  let ownerId: string;
  let eventId: string;
  let otherEventId: string;
  let guestListId: string;
  type Body = { success: boolean; message: string; errorType?: string; data?: { id: string } };

  const join = (who: string, event = eventId) =>
    fetch(`${srv.baseUrl}/api/v1/event/${event}/guest-list/join`, {
      method: 'POST',
      headers: { 'content-type': 'application/json', authorization: `Bearer ${tokens[who]}` },
      body: JSON.stringify({
        name: 'Guest',
        email: `guest-${who}-${run}@example.test`,
        phone: '+15550001111',
        menCount: 1,
        womenCount: 0,
        otherCount: 0,
        acceptedTerms: true,
      }),
    });

  const mkUser = async (label: string) => {
    const user = await db().user.create({
      data: {
        name: `T020 ${label}`,
        email: `t020-${run}-${label}@example.test`,
        phoneNumber: `+1555${Math.floor(Math.random() * 1e7)}`,
        isVerified: true,
      },
    });
    userIds.push(user.id);
    const jwt = await import('@/app/utils/jwt.utils');
    tokens[label] = jwt.generateAccessTokenForUser({
      sub: user.id,
      role: user.accountRole,
      isVerified: true,
      accountStatus: user.accountStatus,
      rememberMe: true,
    } as never);
    return user.id;
  };

  const rowsFor = (userId: string) =>
    db().eventGuestListEntry.findMany({ where: { guestListId, userId } });

  before(async () => {
    process.env.DATABASE_URL = assertSafeTestDatabaseUrl(process.env.TEST_DATABASE_URL);
    installFakeRedis();
    appPrisma = (await import('@/app/configs/db.configs')).default;
    const [{ current_database: name }] = await appPrisma.$queryRaw<{ current_database: string }[]>`select current_database()`;
    assert.match(name, /_test$/, 'app prisma client must target the test DB');

    ownerId = await mkUser('owner');
    for (const l of ['a', 'b', 'c', 'd', 'e']) await mkUser(l);
    const { createEvent } = await import('@/testing/fixtures');
    eventId = (await createEvent(db(), ownerId, { eventName: `T020 Event ${run}` })).id;
    otherEventId = (await createEvent(db(), ownerId, { eventName: `T020 Other ${run}` })).id;
    for (const id of [eventId, otherEventId]) {
      const gl = await db().eventGuestList.create({ data: { eventId: id, isEnabled: true } });
      if (id === eventId) guestListId = gl.id;
    }

    const routes = (await import('@/app/modules/guestList/guestList.routes')).default;
    const { globalErrorMiddleware } = await import('@/app/middlewares/globalError.middlewares');
    const app = express();
    app.use(express.json());
    app.use('/api/v1', routes);
    app.use(globalErrorMiddleware);
    srv = await startTestServer(app);
  });

  after(async () => {
    try {
      await db().eventGuestListEntry.deleteMany({ where: { guestList: { eventId: { in: [eventId, otherEventId] } } } });
      await db().eventGuestList.deleteMany({ where: { eventId: { in: [eventId, otherEventId] } } });
      await db().event.deleteMany({ where: { userId: ownerId } });
      await db().user.deleteMany({ where: { id: { in: userIds } } });
    } finally {
      await srv?.close();
      await appPrisma?.$disconnect();
      await closeTestPrisma();
    }
  });

  it('second join by the same user -> 409 GUEST_LIST_DUPLICATE; the first still stands', async () => {
    const first = await join('a');
    assert.equal(first.status, 201);
    const firstBody = (await first.json()) as Body;
    const second = await join('a');
    assert.equal(second.status, 409);
    const b = (await second.json()) as Body;
    assert.equal(b.success, false);
    assert.equal(b.errorType, 'GUEST_LIST_DUPLICATE');
    const [uid] = await db().user.findMany({ where: { email: `t020-${run}-a@example.test` }, select: { id: true } });
    const rows = await rowsFor(uid.id);
    assert.equal(rows.length, 1);
    assert.equal(rows[0].id, firstBody.data?.id);
    assert.equal(rows[0].status, 'PENDING');
  });

  it('a CONFIRMED entry also blocks a new join', async () => {
    assert.equal((await join('b')).status, 201);
    const [u] = await db().user.findMany({ where: { email: `t020-${run}-b@example.test` }, select: { id: true } });
    await db().eventGuestListEntry.updateMany({ where: { guestListId, userId: u.id }, data: { status: 'CONFIRMED' } });
    const r = await join('b');
    assert.equal(r.status, 409);
    assert.equal(((await r.json()) as Body).errorType, 'GUEST_LIST_DUPLICATE');
    assert.equal((await rowsFor(u.id)).length, 1);
  });

  it('join after a REJECTED entry succeeds', async () => {
    assert.equal((await join('c')).status, 201);
    const [u] = await db().user.findMany({ where: { email: `t020-${run}-c@example.test` }, select: { id: true } });
    await db().eventGuestListEntry.updateMany({ where: { guestListId, userId: u.id }, data: { status: 'REJECTED' } });
    assert.equal((await join('c')).status, 201);
    const rows = await rowsFor(u.id);
    assert.equal(rows.length, 2);
    assert.deepEqual(rows.map((r) => r.status).sort(), ['PENDING', 'REJECTED']);
  });

  it('the same user can join a different event', async () => {
    assert.equal((await join('d')).status, 201);
    assert.equal((await join('d', otherEventId)).status, 201);
  });

  it('a different user is not blocked by someone else\'s entry', async () => {
    assert.equal((await join('e')).status, 201);
    const total = await db().eventGuestListEntry.count({ where: { guestListId } });
    assert.ok(total >= 4);
  });

  it('parallel identical joins create exactly one row', async () => {
    const fresh = await mkUser('p');
    const results = await Promise.all(Array.from({ length: 8 }, () => join('p')));
    const statuses = results.map((r) => r.status).sort();
    assert.deepEqual(statuses, [201, 409, 409, 409, 409, 409, 409, 409]);
    for (const r of results) {
      if (r.status === 409) assert.equal(((await r.json()) as Body).errorType, 'GUEST_LIST_DUPLICATE');
    }
    assert.equal((await rowsFor(fresh)).length, 1);
  });
});
