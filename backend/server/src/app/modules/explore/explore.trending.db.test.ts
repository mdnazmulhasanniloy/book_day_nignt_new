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

// T-042 (CR-11, BUG-B28): sort=trending on GET /explore, GET /explore/most-viewed and
// GET /me/recently-viewed. View and interest rows are inserted directly with fixed dates and the
// services get a fixed "now" (2026-12-01T12:00:00Z), so the ranking tests do not depend on the
// real clock. Events sit around a remote ocean point (no other data can be inside the radius).
//
// Trending score = views over the last 7 UTC days (today included) + Interested taps in the same
// window; ties by startAt ASC then id ASC. Most viewed = views over the last 30 UTC days.

const run = randomUUID().replace(/-/g, '').slice(0, 8).toUpperCase();
const P = `T42${run}`;
const CENTRE = { lat: -61, lng: -121 };
const KM_PER_DEG = 111.195;
const NOW = new Date('2026-12-01T12:00:00Z');
const far = (d: string) => new Date(`${d}T00:00:00Z`);

type Item = { id: string; name: string; [k: string]: unknown };
type Body = { success: boolean; data: Item[]; meta?: Record<string, unknown>; message?: string };

describe('trending, most viewed, recently viewed (T-042)', { skip: dbTestSkipReason() }, () => {
  let appPrisma: PrismaClient;
  let srv: Awaited<ReturnType<typeof startTestServer>>;
  let ownerId: string;
  let cityId: string;
  const userIds: string[] = [];
  const tokens: string[] = [];
  const ev: Record<string, string> = {};
  const db = () => getTestPrisma();
  const mine = (items: Item[]) => items.filter((i) => i.name.startsWith(P)).map((i) => i.name.slice(P.length + 1));

  const get = async (path: string, token?: string) => {
    const r = await fetch(`${srv.baseUrl}/api/v1${path}`, { headers: token ? { authorization: `Bearer ${token}` } : {} });
    return { status: r.status, body: (await r.json()) as Body };
  };
  const centreQs = `lat=${CENTRE.lat}&lng=${CENTRE.lng}&radiusKm=10`;

  const services = async () => import('@/app/modules/explore/explore.services');
  const trendingNames = async (extra: Record<string, unknown> = {}) => {
    const { exploreListService } = await services();
    const out = await exploreListService({
      query: { type: 'EVENT', lat: CENTRE.lat, lng: CENTRE.lng, radiusKm: 10, sort: 'trending', page: 1, limit: 50, ...extra } as never,
      now: NOW,
    });
    return mine(out.data as unknown as Item[]);
  };
  const mostViewedNames = async (extra: Record<string, unknown> = {}) => {
    const { exploreMostViewedService } = await services();
    const out = await exploreMostViewedService({
      query: { lat: CENTRE.lat, lng: CENTRE.lng, radiusKm: 10, limit: 20, ...extra } as never,
      now: NOW,
    });
    return mine(out.data as unknown as Item[]);
  };

  const views = (name: string, day: string, n: number) =>
    db().eventViewDaily.create({ data: { eventId: ev[name]!, day: far(day), views: n } });
  const tap = (name: string, userIdx: number, at: string) =>
    db().eventInterest.create({ data: { eventId: ev[name]!, userId: userIds[userIdx]!, createdAt: new Date(at) } });
  const clearSignals = async () => {
    const ids = Object.values(ev);
    await db().eventViewDaily.deleteMany({ where: { eventId: { in: ids } } });
    await db().eventInterest.deleteMany({ where: { eventId: { in: ids } } });
    await db().event.updateMany({ where: { id: { in: ids } }, data: { viewCount: 0 } });
  };

  // Interested taps. Window start for NOW is 2026-11-25T00:00:00Z.
  const seedTaps = async () => {
    for (let u = 1; u <= 5; u++) await tap('B', u, u === 1 ? '2026-11-25T00:00:00Z' : '2026-11-30T10:00:00Z'); // 5 in window
    for (let u = 1; u <= 2; u++) await tap('C', u, '2026-11-24T23:59:59Z'); // 2 just OUTSIDE
    for (let u = 1; u <= 5; u++) await tap('D', u, '2026-12-01T09:00:00Z'); // 5 in window
    await tap('CANCELED', 1, '2026-12-01T09:00:00Z');
  };

  before(async () => {
    process.env.DATABASE_URL = assertSafeTestDatabaseUrl(process.env.TEST_DATABASE_URL);
    installFakeRedis();
    appPrisma = (await import('@/app/configs/db.configs')).default;
    const jwt = await import('@/app/utils/jwt.utils');

    const mkUser = async (label: string, accountRole: 'USER' | 'CLUB_OWNER' = 'USER') => {
      const u = await db().user.create({
        data: {
          name: `T042 ${label}`,
          email: `t042-${run}-${label}@example.test`,
          phoneNumber: `+1555${Math.floor(Math.random() * 1e7)}`,
          accountRole,
          isVerified: true,
        },
      });
      userIds.push(u.id);
      tokens.push(
        jwt.generateAccessTokenForUser({
          sub: u.id,
          role: u.accountRole,
          isVerified: true,
          accountStatus: u.accountStatus,
          rememberMe: true,
        } as never)
      );
      return u;
    };
    ownerId = (await mkUser('owner', 'CLUB_OWNER')).id; // index 0
    for (let i = 1; i <= 5; i++) await mkUser(`u${i}`); // indexes 1..5

    // A and E tie on score and startAt: the id decides, so A gets the smaller id.
    const [idLow, idHigh] = [randomUUID(), randomUUID()].sort();
    const spec: { key: string; startAt: string; createdOffsetMin: number; lat?: number; id?: string; extra?: object }[] = [
      { key: 'A', startAt: '2035-06-01', createdOffsetMin: 0, id: idLow },
      { key: 'B', startAt: '2035-06-03', createdOffsetMin: 1 },
      { key: 'C', startAt: '2035-06-04', createdOffsetMin: 2 },
      { key: 'D', startAt: '2035-06-02', createdOffsetMin: 3 },
      { key: 'E', startAt: '2035-06-01', createdOffsetMin: 4, id: idHigh },
      { key: 'Z', startAt: '2035-06-05', createdOffsetMin: 5 },
      { key: 'FAR', startAt: '2035-06-01', createdOffsetMin: 6, lat: CENTRE.lat + 60 / KM_PER_DEG },
      { key: 'CANCELED', startAt: '2035-06-01', createdOffsetMin: 7, extra: { eventStatus: 'CANCELED' } },
      { key: 'OFF', startAt: '2035-06-01', createdOffsetMin: 8, extra: { deactivatedAt: new Date() } },
    ];
    const base = Date.now();
    for (const s of spec) {
      const lat = s.lat ?? CENTRE.lat + 2 / KM_PER_DEG;
      const e = await db().event.create({
        data: {
          ...(s.id ? { id: s.id } : {}),
          userId: ownerId,
          eventName: `${P} ${s.key}`,
          thumbnail: 'https://example.test/t.png',
          lat,
          lng: CENTRE.lng,
          location: 'Remote',
          startAt: far(s.startAt),
          endAt: new Date(far(s.startAt).getTime() + 86_400_000),
          dressCode: 'casual',
          eventPrice: 10,
          currency: 'USD',
          createdAt: new Date(base - s.createdOffsetMin * 60_000),
          ...(s.extra ?? {}),
        },
      });
      await db().$executeRaw`UPDATE "Event" SET geog = ST_SetSRID(ST_MakePoint(${CENTRE.lng}, ${lat}), 4326)::geography WHERE id = ${e.id}`;
      ev[s.key] = e.id;
    }
    // endAt must be after the fixed clock and the real clock for every phase
    await db().event.updateMany({
      where: { userId: ownerId },
      data: { endAt: far('2036-01-01') },
    });
    const city = await db().city.create({
      data: { name: `${P} City`, countryCode: 'ZZ', lat: CENTRE.lat, lng: CENTRE.lng, isLaunched: false },
    });
    cityId = city.id;

    const exploreRoutes = (await import('@/app/modules/explore/explore.routes')).default;
    const { globalErrorMiddleware } = await import('@/app/middlewares/globalError.middlewares');
    const app = express();
    app.use(express.json());
    app.use('/api/v1', exploreRoutes);
    app.use(globalErrorMiddleware);
    srv = await startTestServer(app);

    await seedTaps();
  });

  after(async () => {
    try {
      await db().event.deleteMany({ where: { userId: ownerId } });
      await db().city.deleteMany({ where: { name: { startsWith: P } } });
      await db().user.deleteMany({ where: { id: { in: userIds } } });
    } finally {
      await srv?.close();
      await appPrisma?.$disconnect();
      await closeTestPrisma();
    }
  });

  describe('fallback until history exists', () => {
    it('trending and most viewed use lifetime Event.viewCount (+ interested taps for trending)', async () => {
      const counts: Record<string, number> = { A: 50, B: 10, C: 30, D: 20, E: 5, Z: 0, FAR: 9000, CANCELED: 9000, OFF: 9000 };
      for (const [k, n] of Object.entries(counts)) await db().event.update({ where: { id: ev[k]! }, data: { viewCount: n } });
      // A recent row only (no day older than the window start): history is too short, so it is ignored.
      await views('E', '2026-12-01', 999);
      // scores: A 50, C 30 + 0 taps, D 20 + 5, B 10 + 5, E 5, Z 0
      assert.deepEqual(await trendingNames(), ['A', 'C', 'D', 'B', 'E', 'Z']);
      // most viewed: lifetime viewCount only (no taps), events without views left out
      assert.deepEqual(await mostViewedNames(), ['A', 'C', 'D', 'B', 'E']);
    });
  });

  describe('windows (history exists)', () => {
    before(async () => {
      await clearSignals();
      await seedTaps();
      // anchor: history older than the 30 day window exists, so no fallback anywhere
      await views('FAR', '2026-10-20', 1);
      // lifetime counters must be ignored once history exists
      await db().event.update({ where: { id: ev.Z! }, data: { viewCount: 12345 } });
      await views('A', '2026-12-01', 7);
      await views('B', '2026-11-25', 3); // first day of the 7 day window
      await views('C', '2026-11-30', 4);
      await views('C', '2026-11-24', 100); // one day too old for trending, inside 30 days
      await views('D', '2026-12-01', 2);
      await views('E', '2026-12-01', 7);
      await views('FAR', '2026-12-01', 1000); // outside the city
      await views('CANCELED', '2026-12-01', 500);
      await views('OFF', '2026-12-01', 500);
      await views('A', '2026-11-10', 20);
      await views('B', '2026-11-02', 40); // first day of the 30 day window
      await views('E', '2026-11-01', 1000); // one day outside the 30 day window
    });

    it('trending = views(7d) + interested(7d); ties by startAt then id; older data ignored; city only', async () => {
      // B 3+5=8; A 7; E 7 (same startAt as A, larger id); D 2+5=7 (later startAt); C 4 (+100 and 2 taps too old); Z 0
      assert.deepEqual(await trendingNames(), ['B', 'A', 'E', 'D', 'C', 'Z']);
    });

    it('trending works through cityId for a City that is not launched', async () => {
      assert.deepEqual(await trendingNames({ lat: undefined, lng: undefined, cityId }), ['B', 'A', 'E', 'D', 'C', 'Z']);
    });

    it('trending pages the ranked list', async () => {
      assert.deepEqual(await trendingNames({ limit: 2, page: 2 }), ['E', 'D']);
    });

    it('most viewed = views over 30 days, city only, no canceled or deactivated, zero views left out', async () => {
      // C 104, B 43, A 27, E 7, D 2; Z has no views in the window (its lifetime counter is ignored)
      assert.deepEqual(await mostViewedNames(), ['C', 'B', 'A', 'E', 'D']);
      assert.deepEqual(await mostViewedNames({ limit: 3 }), ['C', 'B', 'A']);
      assert.deepEqual(await mostViewedNames({ lat: undefined, lng: undefined, cityId }), ['C', 'B', 'A', 'E', 'D']);
    });

    it('a smaller radius removes events outside it from both rankings', async () => {
      const { exploreMostViewedService } = await services();
      const out = await exploreMostViewedService({
        query: { lat: CENTRE.lat + 60 / KM_PER_DEG, lng: CENTRE.lng, radiusKm: 10, limit: 20 } as never,
        now: NOW,
      });
      assert.deepEqual(mine(out.data as unknown as Item[]), ['FAR']);
    });
  });

  describe('HTTP', () => {
    const today = new Date().toISOString().slice(0, 10);
    before(async () => {
      await clearSignals();
      await views('FAR', '2026-10-20', 1);
      await views('C', today, 9);
      await views('A', today, 1);
    });

    it('sort=trending is no longer ignored; the default order is unchanged', async () => {
      const def = await get(`/explore?type=EVENT&${centreQs}&limit=50`);
      const newest = await get(`/explore?type=EVENT&${centreQs}&limit=50&sort=newest`);
      const trending = await get(`/explore?type=EVENT&${centreQs}&limit=50&sort=trending`);
      assert.equal(def.status, 200);
      assert.equal(trending.status, 200);
      assert.deepEqual(mine(def.body.data), ['A', 'B', 'C', 'D', 'E', 'Z']); // createdAt DESC
      assert.deepEqual(mine(newest.body.data), mine(def.body.data));
      assert.deepEqual(mine(trending.body.data), ['C', 'A', 'E', 'D', 'B', 'Z']); // 9, 1, then zeros by startAt, id
      assert.deepEqual(Object.keys(def.body.data[0]!).sort(), Object.keys(trending.body.data[0]!).sort());
    });

    it('GET /explore/most-viewed is public, not captured by /explore/:id, rejects bad input', async () => {
      const ok = await get(`/explore/most-viewed?${centreQs}`);
      assert.equal(ok.status, 200);
      assert.deepEqual(mine(ok.body.data), ['C', 'A']);
      const first = ok.body.data[0]!;
      assert.equal(first.type, 'EVENT');
      assert.ok(!('userId' in first));
      assert.equal((await get(`/explore/most-viewed?cityId=${cityId}&limit=1`)).body.data.length, 1);
      assert.equal((await get(`/explore/most-viewed?limit=21`)).status, 422);
      assert.equal((await get(`/explore/most-viewed?cityId=${randomUUID()}`)).status, 404);
      assert.equal((await get(`/explore/most-viewed?cityId=not-a-uuid`)).status, 422);
    });

    it('GET /me/recently-viewed requires a token', async () => {
      const r = await get('/me/recently-viewed');
      assert.equal(r.status, 401);
      assert.equal((await get('/me/recently-viewed', 'garbage')).status, 401);
    });

    it('recently viewed is personal, newest first, skips deactivated events, never leaks another user', async () => {
      const mk = (userIdx: number, key: string, at: string) =>
        db().userRecentEventView.create({ data: { userId: userIds[userIdx]!, eventId: ev[key]!, lastViewedAt: new Date(at) } });
      await mk(1, 'A', '2026-11-20T10:00:00Z');
      await mk(1, 'B', '2026-11-22T10:00:00Z');
      await mk(1, 'C', '2026-11-21T10:00:00Z');
      await mk(1, 'OFF', '2026-11-23T10:00:00Z');
      await mk(2, 'D', '2026-11-22T11:00:00Z');
      await mk(2, 'E', '2026-11-19T11:00:00Z');

      const u1 = await get('/me/recently-viewed', tokens[1]);
      assert.equal(u1.status, 200);
      assert.deepEqual(mine(u1.body.data), ['B', 'C', 'A']);
      assert.equal(u1.body.data[0]!.viewedAt, '2026-11-22T10:00:00.000Z');
      assert.equal(u1.body.data[0]!.type, 'EVENT');
      assert.ok(!('userId' in u1.body.data[0]!));
      assert.equal(u1.body.meta?.total, 3);

      const u2 = await get('/me/recently-viewed', tokens[2]);
      assert.deepEqual(mine(u2.body.data), ['D', 'E']);
      const u3 = await get('/me/recently-viewed', tokens[3]);
      assert.deepEqual(u3.body.data, []);

      const paged = await get('/me/recently-viewed?limit=2&page=2', tokens[1]);
      assert.deepEqual(mine(paged.body.data), ['A']);
      assert.equal(paged.body.meta?.totalPages, 2);
      assert.equal((await get('/me/recently-viewed?limit=0', tokens[1])).status, 422);
    });

    it('returns at most 20 items', async () => {
      const rows = [];
      for (let i = 0; i < 22; i++) {
        const e = await db().event.create({
          data: {
            userId: ownerId,
            eventName: `${P} R${i}`,
            thumbnail: 'https://example.test/t.png',
            lat: CENTRE.lat,
            lng: CENTRE.lng,
            startAt: far('2035-07-01'),
            endAt: far('2036-01-01'),
            dressCode: 'casual',
            eventPrice: 1,
            currency: 'USD',
          },
        });
        rows.push({ userId: userIds[4]!, eventId: e.id, lastViewedAt: new Date(Date.UTC(2026, 10, 1, 0, i)) });
      }
      await db().userRecentEventView.createMany({ data: rows });
      const r = await get('/me/recently-viewed?limit=50', tokens[4]);
      assert.equal(r.status, 200);
      assert.equal(r.body.data.length, 20);
      assert.equal(r.body.data[0]!.name, `${P} R21`);
      assert.equal(r.body.meta?.total, 20);
    });
  });
});
