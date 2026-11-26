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

// T-044 (CR-12): optional `artistId` on lineup items of POST /event and PUT /event/{id}.
// Same harness as event.createUpdateFields.db.test.ts (Connect readiness pass-through, FakeQueue,
// faked nearby-user helpers, fake Redis).

const run = randomUUID().replace(/-/g, '').slice(0, 8).toUpperCase();
const P = `T44L${run}`;

describe('lineup artistId on POST /event and PUT /event/:id (T-044)', { skip: dbTestSkipReason() }, () => {
  let appPrisma: PrismaClient;
  let srv: Awaited<ReturnType<typeof startTestServer>>;
  let ownerId: string;
  let ownerToken: string;
  let artistId: string;
  const queue = new FakeQueue();
  const db = () => getTestPrisma();

  const send = (method: 'POST' | 'PUT', path: string, body: unknown) =>
    fetch(`${srv.baseUrl}/api/v1${path}`, {
      method,
      headers: { 'content-type': 'application/json', authorization: `Bearer ${ownerToken}` },
      body: JSON.stringify(body),
    });
  const eventBody = (extra: Record<string, unknown> = {}) => ({
    eventName: `${P} event`,
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
  const lineupOf = (eventId: string) =>
    db().eventLineup.findMany({ where: { eventId }, orderBy: { sortOrder: 'asc' } });
  const artistCount = () => db().artist.count({ where: { name: { startsWith: P } } });
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
        name: 'T044L owner',
        email: `t044l-${run}-owner@example.test`,
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

    const name = `${P} Linked`;
    const a = await db().artist.create({
      data: { name, nameKey: name.toLowerCase(), avatar: 'https://example.test/orig.png', bio: 'orig bio' },
    });
    artistId = a.id;

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
      await db().artist.deleteMany({ where: { name: { startsWith: P } } });
      await db().user.deleteMany({ where: { id: ownerId } });
    } finally {
      await srv?.close();
      await appPrisma?.$disconnect();
      await closeTestPrisma();
    }
  });

  it('POST: a lineup item with artistId links that artist, even when artistName differs, and does not touch the artist row', async () => {
    const r = await send('POST', '/event', eventBody({ lineup: [{ artistId, artistName: `${P} Billed As`, isVerified: true, artistAvatar: 'https://example.test/other.png' }] }));
    assert.equal(r.status, 201);
    const { data } = (await r.json()) as { data: { id: string } };
    const rows = await lineupOf(data.id);
    assert.equal(rows.length, 1);
    assert.equal(rows[0].artistId, artistId);
    assert.equal(rows[0].artistName, `${P} Billed As`);
    assert.equal(await artistCount(), 1, 'no new Artist is created from the name');
    const a = await db().artist.findUniqueOrThrow({ where: { id: artistId } });
    assert.equal(a.avatar, 'https://example.test/orig.png', 'linking never overwrites the shared artist');
    assert.equal(a.isVerified, false);
  });

  it('POST: an unknown artistId is 404 and nothing is created (no event, no artist)', async () => {
    const before = await eventCount();
    const r = await send('POST', '/event', eventBody({ lineup: [{ artistId: randomUUID(), artistName: `${P} Ghost` }] }));
    assert.equal(r.status, 404);
    const b = (await r.json()) as { success: boolean; message: string };
    assert.equal(b.success, false);
    assert.equal(b.message, 'Artist not found');
    assert.equal(await eventCount(), before);
    assert.equal(await artistCount(), 1);
  });

  it('POST: a non-uuid artistId is 422; items without artistId still upsert by name (unchanged behaviour)', async () => {
    assert.equal((await send('POST', '/event', eventBody({ lineup: [{ artistId: 'nope', artistName: 'X' }] }))).status, 422);
    const r = await send('POST', '/event', eventBody({ lineup: [{ artistName: `${P} ByName` }] }));
    assert.equal(r.status, 201);
    const { data } = (await r.json()) as { data: { id: string } };
    const rows = await lineupOf(data.id);
    assert.ok(rows[0].artistId);
    assert.equal((await db().artist.findUniqueOrThrow({ where: { id: rows[0].artistId as string } })).name, `${P} ByName`);
  });

  it('PUT: the link survives the delete-and-recreate of the lineup; unknown artistId is 404 and keeps the old lineup', async () => {
    const created = await send('POST', '/event', eventBody({ lineup: [{ artistId, artistName: `${P} Linked` }] }));
    const { data } = (await created.json()) as { data: { id: string } };

    const put = await send('PUT', `/event/${data.id}`, {
      eventName: `${P} renamed`,
      lineup: [{ artistId, artistName: `${P} Linked`, sortOrder: 0 }, { artistName: `${P} Second`, sortOrder: 1 }],
    });
    assert.equal(put.status, 200);
    const rows = await lineupOf(data.id);
    assert.deepEqual(rows.map((x) => x.artistName), [`${P} Linked`, `${P} Second`]);
    assert.equal(rows[0].artistId, artistId);
    assert.ok(rows[1].artistId && rows[1].artistId !== artistId);

    const bad = await send('PUT', `/event/${data.id}`, { lineup: [{ artistId: randomUUID(), artistName: `${P} Ghost` }] });
    assert.equal(bad.status, 404);
    const after = await lineupOf(data.id);
    assert.deepEqual(after.map((x) => x.artistId), rows.map((x) => x.artistId), 'failed update rolls back');

    // omitting lineup leaves it alone
    const keep = await send('PUT', `/event/${data.id}`, { eventName: `${P} again` });
    assert.equal(keep.status, 200);
    assert.equal((await lineupOf(data.id)).length, 2);
  });

  it('PUT with the same name but no artistId (legacy client) keeps pointing at the same artist', async () => {
    const created = await send('POST', '/event', eventBody({ lineup: [{ artistId, artistName: `${P} Linked` }] }));
    const { data } = (await created.json()) as { data: { id: string } };
    const put = await send('PUT', `/event/${data.id}`, { lineup: [{ artistName: `${P} Linked` }] });
    assert.equal(put.status, 200);
    assert.equal((await lineupOf(data.id))[0].artistId, artistId);
  });
});
