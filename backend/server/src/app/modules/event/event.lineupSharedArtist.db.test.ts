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

// W-04: a lineup item WITHOUT artistId must never modify a shared Artist row.
//  - same nameKey already exists: link it, change nothing (not even updatedAt)
//  - no such nameKey: create a new Artist, isVerified always false
//  - creation race: unique violation is treated as "already exists"
// Same harness as event.lineupArtistId.db.test.ts (fake Redis, FakeQueue, faked nearby helpers).
// The test commits across connections, so after() removes every row it created.

const run = randomUUID().replace(/-/g, '').slice(0, 8).toUpperCase();
const P = `W04${run}`;

describe('lineup without artistId never modifies a shared artist (W-04)', { skip: dbTestSkipReason() }, () => {
  let appPrisma: PrismaClient;
  let srv: Awaited<ReturnType<typeof startTestServer>>;
  const ids: Record<string, string> = {};
  const tok: Record<string, string> = {};
  const queue = new FakeQueue();
  const db = () => getTestPrisma();

  const send = (who: 'A' | 'B', method: string, path: string, body?: unknown) =>
    fetch(`${srv.baseUrl}/api/v1${path}`, {
      method,
      headers: { 'content-type': 'application/json', authorization: `Bearer ${tok[who]}` },
      ...(body !== undefined ? { body: JSON.stringify(body) } : {}),
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
  const artistsNamed = (key: string) => db().artist.findMany({ where: { nameKey: key } });
  const mkShared = async (tag: string) => {
    const name = `${P} ${tag}`;
    return db().artist.create({
      data: {
        name,
        nameKey: name.toLowerCase(),
        avatar: 'https://example.test/orig.png',
        audioPreviewUrl: 'https://example.test/orig.mp3',
        spotifyUrl: 'https://open.spotify.com/artist/orig',
        soundcloudUrl: 'https://soundcloud.com/orig',
        bio: 'orig bio',
        socialLinks: { instagram: 'https://instagram.com/orig' },
        isVerified: true,
        followerCount: 7,
      },
    });
  };
  const hostile = {
    artistAvatar: 'https://example.test/EVIL.png',
    audioPreviewUrl: 'https://example.test/EVIL.mp3',
    spotifyUrl: 'https://open.spotify.com/artist/EVIL',
    soundcloudUrl: 'https://soundcloud.com/EVIL',
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

    const jwt = await import('@/app/utils/jwt.utils');
    for (const tag of ['A', 'B'] as const) {
      const u = await db().user.create({
        data: {
          name: `W04 owner ${tag}`,
          email: `w04-${run}-${tag}@example.test`,
          phoneNumber: `+1555${Math.floor(Math.random() * 1e7)}`,
          accountRole: 'CLUB_OWNER',
          isVerified: true,
        },
      });
      ids[tag] = u.id;
      tok[tag] = jwt.generateAccessTokenForUser({
        sub: u.id,
        role: u.accountRole,
        isVerified: true,
        accountStatus: u.accountStatus,
        rememberMe: true,
      } as never);
    }

    const eventRoutes = (await import('@/app/modules/event/event.routes')).default;
    const artistRoutes = (await import('@/app/modules/artists/artists.routes')).default;
    const { globalErrorMiddleware } = await import('@/app/middlewares/globalError.middlewares');
    const app = express();
    app.use(express.json());
    app.use('/api/v1', eventRoutes);
    app.use('/api/v1', artistRoutes);
    app.use(globalErrorMiddleware);
    srv = await startTestServer(app);
  });

  after(async () => {
    try {
      const events = await db().event.findMany({
        where: { userId: { in: Object.values(ids) } },
        select: { id: true },
      });
      await db().event.deleteMany({ where: { id: { in: events.map((e) => e.id) } } });
      await db().artist.deleteMany({ where: { name: { startsWith: P } } });
      await db().user.deleteMany({ where: { id: { in: Object.values(ids) } } });
    } finally {
      await srv?.close();
      await appPrisma?.$disconnect();
      await closeTestPrisma();
    }
  });

  for (const sentVerified of [false, true]) {
    for (const variant of ['same', 'upper+spaces'] as const) {
      it(`POST: same name (${variant}), isVerified=${sentVerified}, other avatar/links: artist row is unchanged and the lineup links to it`, async () => {
        const shared = await mkShared(`Shared ${variant} ${sentVerified}`);
        const sentName = variant === 'same' ? shared.name : `  ${shared.name.toUpperCase()}  `;
        const r = await send('B', 'POST', '/event', eventBody({
          lineup: [{ artistName: sentName, isVerified: sentVerified, ...hostile }],
        }));
        assert.equal(r.status, 201);
        const { data } = (await r.json()) as { data: { id: string } };
        const rows = await lineupOf(data.id);
        assert.equal(rows.length, 1);
        assert.equal(rows[0].artistId, shared.id);
        assert.equal(await db().artist.count({ where: { nameKey: shared.nameKey } }), 1);
        const after = await db().artist.findUniqueOrThrow({ where: { id: shared.id } });
        assert.deepEqual(after, shared, 'every column, including name, isVerified and updatedAt, is unchanged');
      });
    }
  }

  it('PUT: re-sending the lineup keeps the link and does not modify the shared artist; response shape unchanged', async () => {
    const shared = await mkShared('PutShared');
    const created = await send('B', 'POST', '/event', eventBody({ lineup: [{ artistId: shared.id, artistName: shared.name }] }));
    const created2 = (await created.json()) as { success: boolean; data: { id: string } };
    const put = await send('B', 'PUT', `/event/${created2.data.id}`, {
      lineup: [{ artistName: `  ${shared.name.toUpperCase()}`, isVerified: false, ...hostile, sortOrder: 0 }],
    });
    assert.equal(put.status, 200);
    const body = (await put.json()) as Record<string, unknown>;
    assert.deepEqual(Object.keys(body).sort(), Object.keys((await (await send('B', 'PUT', `/event/${created2.data.id}`, { eventName: `${P} x` })).json()) as object).sort());
    assert.equal((await lineupOf(created2.data.id))[0].artistId, shared.id);
    assert.deepEqual(await db().artist.findUniqueOrThrow({ where: { id: shared.id } }), shared);
    assert.equal(await db().artist.count({ where: { nameKey: shared.nameKey } }), 1);
  });

  it('POST response shape: success, message, data with id (unchanged)', async () => {
    const r = await send('B', 'POST', '/event', eventBody({ lineup: [{ artistName: `${P} Shape` }] }));
    assert.equal(r.status, 201);
    const b = (await r.json()) as { success: boolean; message: string; data: { id: string; eventName: string } };
    assert.equal(b.success, true);
    assert.equal(typeof b.message, 'string');
    assert.equal(typeof b.data.id, 'string');
    assert.equal(b.data.eventName, `${P} event`);
  });

  it('a new name creates a new artist from the item with isVerified=false even when the payload says true', async () => {
    const name = `${P} Brand New`;
    const r = await send('B', 'POST', '/event', eventBody({
      lineup: [{ artistName: `  ${name}  `, isVerified: true, ...hostile }],
    }));
    assert.equal(r.status, 201);
    const { data } = (await r.json()) as { data: { id: string } };
    const rows = await lineupOf(data.id);
    const a = await db().artist.findUniqueOrThrow({ where: { id: rows[0].artistId as string } });
    assert.equal(a.name, name);
    assert.equal(a.nameKey, name.toLowerCase());
    assert.equal(a.isVerified, false);
    assert.equal(a.avatar, hostile.artistAvatar);
    assert.equal(a.spotifyUrl, hostile.spotifyUrl);
    assert.equal(a.soundcloudUrl, hostile.soundcloudUrl);
    assert.equal(a.audioPreviewUrl, hostile.audioPreviewUrl);
  });

  it('the same new name sent by two owners results in ONE artist and the second owner cannot change it', async () => {
    const name = `${P} Two Owners`;
    const ra = await send('A', 'POST', '/event', eventBody({
      lineup: [{ artistName: name, artistAvatar: 'https://example.test/a.png', spotifyUrl: 'https://open.spotify.com/artist/a' }],
    }));
    assert.equal(ra.status, 201);
    const first = await artistsNamed(name.toLowerCase());
    assert.equal(first.length, 1);
    const rb = await send('B', 'POST', '/event', eventBody({
      lineup: [{ artistName: name.toUpperCase(), isVerified: true, artistAvatar: 'https://example.test/b.png', spotifyUrl: 'https://open.spotify.com/artist/b' }],
    }));
    assert.equal(rb.status, 201);
    const after = await artistsNamed(name.toLowerCase());
    assert.equal(after.length, 1);
    assert.deepEqual(after[0], first[0]);
    const { data } = (await rb.json()) as { data: { id: string } };
    assert.equal((await lineupOf(data.id))[0].artistId, first[0].id);
  });

  it('8 parallel creations of the same new name give one artist and no 5xx', async () => {
    const name = `${P} Race`;
    const results = await Promise.all(
      Array.from({ length: 8 }, (_, i) =>
        send(i % 2 ? 'A' : 'B', 'POST', '/event', eventBody({
          eventName: `${P} race ${i}`,
          lineup: [{ artistName: name, isVerified: true, artistAvatar: `https://example.test/r${i}.png` }],
        }))
      )
    );
    assert.deepEqual(results.map((r) => r.status), Array(8).fill(201));
    const rows = await artistsNamed(name.toLowerCase());
    assert.equal(rows.length, 1);
    assert.equal(rows[0].isVerified, false);
    const lineups = await db().eventLineup.findMany({ where: { artistName: name } });
    assert.equal(lineups.length, 8);
    assert.ok(lineups.every((l) => l.artistId === rows[0].id));
  });

  it('an item with artistId behaves as before (links, nothing modified, 404 when unknown)', async () => {
    const shared = await mkShared('ById');
    const r = await send('B', 'POST', '/event', eventBody({
      lineup: [{ artistId: shared.id, artistName: `${P} Billed As`, isVerified: true, ...hostile }],
    }));
    assert.equal(r.status, 201);
    const { data } = (await r.json()) as { data: { id: string } };
    assert.equal((await lineupOf(data.id))[0].artistId, shared.id);
    assert.deepEqual(await db().artist.findUniqueOrThrow({ where: { id: shared.id } }), shared);
    const bad = await send('B', 'POST', '/event', eventBody({ lineup: [{ artistId: randomUUID(), artistName: `${P} Ghost` }] }));
    assert.equal(bad.status, 404);
  });

  it('owner A (event lists the artist) can still edit it through PATCH /artists/{id}; owner B (no event) gets 404', async () => {
    const shared = await mkShared('Patchable');
    const ev = await send('A', 'POST', '/event', eventBody({ lineup: [{ artistId: shared.id, artistName: shared.name }] }));
    assert.equal(ev.status, 201);
    const ok = await send('A', 'PATCH', `/artists/${shared.id}`, { bio: 'new bio' });
    assert.equal(ok.status, 200);
    assert.equal((await db().artist.findUniqueOrThrow({ where: { id: shared.id } })).bio, 'new bio');
    const other = await mkShared('NotListed');
    assert.equal((await send('A', 'PATCH', `/artists/${other.id}`, { bio: 'x' })).status, 404);
  });

  it('lineup isVerified comes from the Artist record: a client-sent isVerified is ignored on POST, PUT and read', async () => {
    const plain = await db().artist.create({
      data: { name: `${P} Plain`, nameKey: `${P} Plain`.toLowerCase(), isVerified: false },
    });
    const verified = await mkShared('VerifiedOne');

    // POST: client claims true for an unverified artist, false for a verified one
    const r = await send('B', 'POST', '/event', eventBody({
      lineup: [
        { artistId: plain.id, artistName: plain.name, isVerified: true, sortOrder: 0 },
        { artistId: verified.id, artistName: verified.name, isVerified: false, sortOrder: 1 },
        { artistName: `${P} Fresh One`, isVerified: true, sortOrder: 2 },
      ],
    }));
    assert.equal(r.status, 201);
    const { data } = (await r.json()) as { data: { id: string } };
    let rows = await lineupOf(data.id);
    assert.deepEqual(rows.map((x) => x.isVerified), [false, true, false]);

    // PUT: same rule
    const put = await send('B', 'PUT', `/event/${data.id}`, {
      lineup: [{ artistId: plain.id, artistName: plain.name, isVerified: true, sortOrder: 0 }],
    });
    assert.equal(put.status, 200);
    rows = await lineupOf(data.id);
    assert.deepEqual(rows.map((x) => x.isVerified), [false]);

    // legacy row whose stored flag was client-set: reads still show the Artist's value
    await db().eventLineup.updateMany({ where: { eventId: data.id }, data: { isVerified: true } });
    const detail = await send('B', 'GET', `/event/${data.id}`);
    assert.equal(detail.status, 200);
    const body = (await detail.json()) as { data: { lineup: { isVerified: boolean }[] } };
    assert.deepEqual(body.data.lineup.map((x) => x.isVerified), [false]);

    // when an admin later verifies the artist, the display follows
    await db().artist.update({ where: { id: plain.id }, data: { isVerified: true } });
    const again = (await (await send('B', 'GET', `/event/${data.id}`)).json()) as { data: { lineup: { isVerified: boolean }[] } };
    assert.deepEqual(again.data.lineup.map((x) => x.isVerified), [true]);
  });
});
