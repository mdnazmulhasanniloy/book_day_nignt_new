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

// T-036 (CR-09, BUG-B28): GET /explore/feed honours lat/lng, cityId and radiusKm in every module
// (today, tomorrow, blowingUp, popularOrganizers, genres). Through the real explore router and
// error handler, fake Redis. Fixtures sit around a remote ocean point so no other data can fall
// inside the radius. Rows carry a per-run prefix and are removed in after().

const run = randomUUID().replace(/-/g, '').slice(0, 8).toUpperCase();
const P = `T36${run}`;
const CENTRE = { lat: -60, lng: -120 };
const KM_PER_DEG = 111.195;
const NEAR = 5;
const FAR = 35;

type Ev = { id: string; eventName: string; location: string; [k: string]: unknown };
type Club = { id: string; name: string; [k: string]: unknown };
type Feed = {
  today: Ev[];
  tomorrow: Ev[];
  blowingUp: Ev[];
  popularOrganizers: Club[];
  genres: string[];
};
type Body = { success: boolean; data: Feed };

describe('explore feed centre and radius (T-036)', { skip: dbTestSkipReason() }, () => {
  let appPrisma: PrismaClient;
  let srv: Awaited<ReturnType<typeof startTestServer>>;
  let ownerId: string;
  let cityId: string;
  const db = () => getTestPrisma();

  const get = async (qs = '') => {
    const r = await fetch(`${srv.baseUrl}/api/v1/explore/feed${qs ? `?${qs}` : ''}`);
    return { status: r.status, body: (await r.json()) as Body };
  };
  const evNames = (list: Ev[]) => list.filter((e) => e.eventName.startsWith(P)).map((e) => e.eventName).sort();
  // blowingUp can also hold the other fixture events (low viewCount); only the high-viewCount 'blow' rows are asserted.
  const blowNames = (list: Ev[]) => evNames(list).filter((n) => n.includes(' blow '));
  const clubNames = (list: Club[]) => list.filter((c) => c.name.startsWith(P)).map((c) => c.name).sort();
  const myGenres = (b: Body) => b.data.genres.filter((g) => g.startsWith(P)).sort();
  const centreQs = `lat=${CENTRE.lat}&lng=${CENTRE.lng}`;
  const ev = (kind: string, d: number) => `${P} ${kind} ${d}km`;
  const genre = (d: number) => `${P}G${d}`;

  before(async () => {
    process.env.DATABASE_URL = assertSafeTestDatabaseUrl(process.env.TEST_DATABASE_URL);
    installFakeRedis();
    appPrisma = (await import('@/app/configs/db.configs')).default;

    const owner = await db().user.create({
      data: {
        name: 'T036 owner',
        email: `t036-${run}@example.test`,
        phoneNumber: `+1555${Math.floor(Math.random() * 1e7)}`,
        accountRole: 'CLUB_OWNER',
        isVerified: true,
      },
    });
    ownerId = owner.id;

    const now = new Date();
    const startToday = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 0, 0, 0);
    const startTom = new Date(startToday.getTime() + 86_400_000);
    const HOUR = 3_600_000;
    for (const d of [NEAR, FAR]) {
      const lat = CENTRE.lat + d / KM_PER_DEG;
      const mk = async (
        kind: string,
        startAt: Date,
        endAt: Date,
        extra: { viewCount?: number } = {}
      ) => {
        const e = await db().event.create({
          data: {
            userId: ownerId,
            eventName: ev(kind, d),
            thumbnail: 'https://example.test/t.png',
            lat,
            lng: CENTRE.lng,
            location: `Remote ${P}`,
            startAt,
            endAt,
            dressCode: 'casual',
            eventPrice: 10,
            currency: 'USD',
            musicGenres: [genre(d)],
            ...extra,
          },
        });
        await db().$executeRaw`UPDATE "Event" SET geog = ST_SetSRID(ST_MakePoint(${CENTRE.lng}, ${lat}), 4326)::geography WHERE id = ${e.id}`;
      };
      // today: overlaps only today (00:00-01:00 local), so it is not in blowingUp (endAt may be past).
      await mk('today', startToday, new Date(startToday.getTime() + HOUR));
      await mk('tomorrow', new Date(startTom.getTime() + HOUR), new Date(startTom.getTime() + 2 * HOUR));
      // blowingUp: starts in 3 days, huge viewCount to beat any other row.
      await mk(
        'blow',
        new Date(now.getTime() + 3 * 86_400_000),
        new Date(now.getTime() + 3 * 86_400_000 + HOUR),
        { viewCount: 2_000_000_000 - d }
      );
      const club = await db().club.create({
        data: {
          userId: ownerId,
          name: `${P} club ${d}km`,
          thumbnail: 'https://example.test/t.png',
          dressCode: 'casual',
          lat,
          lng: CENTRE.lng,
          location: `Remote ${P}`,
          followerCount: 2_000_000_000 - d,
        },
      });
      await db().$executeRaw`UPDATE "Club" SET geog = ST_SetSRID(ST_MakePoint(${CENTRE.lng}, ${lat}), 4326)::geography WHERE id = ${club.id}`;
    }
    const city = await db().city.create({
      data: { name: `${P} City`, countryCode: 'ZZ', lat: CENTRE.lat, lng: CENTRE.lng, isLaunched: false },
    });
    cityId = city.id;

    const routes = (await import('@/app/modules/explore/explore.routes')).default;
    const { globalErrorMiddleware } = await import('@/app/middlewares/globalError.middlewares');
    const app = express();
    app.use(express.json());
    app.use('/api/v1', routes);
    app.use(globalErrorMiddleware);
    srv = await startTestServer(app);
  });

  after(async () => {
    try {
      await db().event.deleteMany({ where: { userId: ownerId } });
      await db().club.deleteMany({ where: { userId: ownerId } });
      await db().city.deleteMany({ where: { name: { startsWith: P } } });
      await db().user.deleteMany({ where: { id: ownerId } });
    } finally {
      await srv?.close();
      await appPrisma?.$disconnect();
      await closeTestPrisma();
    }
  });

  const both = (kind: string) => [ev(kind, NEAR), ev(kind, FAR)].sort();
  const near = (kind: string) => [ev(kind, NEAR)];

  it('without new params the response is unchanged: same modules, keys and all rows (no radius)', async () => {
    const { status, body } = await get();
    assert.equal(status, 200);
    assert.deepEqual(Object.keys(body.data), ['today', 'tomorrow', 'blowingUp', 'popularOrganizers', 'genres']);
    assert.deepEqual(evNames(body.data.today), both('today'));
    assert.deepEqual(evNames(body.data.tomorrow), both('tomorrow'));
    assert.deepEqual(blowNames(body.data.blowingUp), both('blow'));
    assert.deepEqual(clubNames(body.data.popularOrganizers), [`${P} club ${NEAR}km`, `${P} club ${FAR}km`].sort());
    assert.deepEqual(myGenres(body), [genre(NEAR), genre(FAR)].sort());
    // item shapes: the pre-T-036 selects, no extra fields
    assert.deepEqual(
      Object.keys(body.data.today.find((e) => e.eventName.startsWith(P))!).sort(),
      ['categoryType', 'currency', 'endAt', 'eventName', 'eventPrice', 'id', 'location', 'musicGenres', 'startAt', 'thumbnail']
    );
    assert.deepEqual(
      Object.keys(body.data.blowingUp.find((e) => e.eventName.startsWith(P))!).sort(),
      ['categoryType', 'currency', 'endAt', 'eventName', 'eventPrice', 'id', 'location', 'musicGenres', 'startAt', 'thumbnail', 'viewCount']
    );
    assert.deepEqual(
      Object.keys(body.data.popularOrganizers.find((c) => c.name.startsWith(P))!).sort(),
      ['followerCount', 'id', 'location', 'name', 'rulesAndVibe', 'thumbnail']
    );
  });

  it('city text filter alone still works and does not touch genres (unchanged)', async () => {
    const hit = await get(`city=${P}`);
    assert.deepEqual(evNames(hit.body.data.today), both('today'));
    assert.deepEqual(myGenres(hit.body), [genre(NEAR), genre(FAR)].sort());
    const miss = await get('city=NoSuchPlaceAnywhere');
    assert.deepEqual(miss.body.data.today, []);
    assert.deepEqual(miss.body.data.popularOrganizers, []);
    assert.deepEqual(myGenres(miss.body), [genre(NEAR), genre(FAR)].sort());
  });

  it('lat/lng are no longer ignored: default 20 km keeps only the near rows in every module', async () => {
    const { status, body } = await get(centreQs);
    assert.equal(status, 200);
    assert.deepEqual(evNames(body.data.today), near('today'));
    assert.deepEqual(evNames(body.data.tomorrow), near('tomorrow'));
    assert.deepEqual(blowNames(body.data.blowingUp), near('blow'));
    assert.deepEqual(clubNames(body.data.popularOrganizers), [`${P} club ${NEAR}km`]);
    assert.deepEqual(myGenres(body), [genre(NEAR)]);
    // nothing from outside the radius at all (remote point: no other data nearby)
    assert.equal(body.data.today.length, 1);
    assert.equal(body.data.genres.length, 1);
  });

  it('radiusKm=50 widens, radiusKm=10 keeps near, in every module', async () => {
    const wide = (await get(`${centreQs}&radiusKm=50`)).body;
    assert.deepEqual(evNames(wide.data.today), both('today'));
    assert.deepEqual(evNames(wide.data.tomorrow), both('tomorrow'));
    assert.deepEqual(blowNames(wide.data.blowingUp), both('blow'));
    assert.deepEqual(clubNames(wide.data.popularOrganizers).length, 2);
    assert.deepEqual(myGenres(wide), [genre(NEAR), genre(FAR)].sort());
    const narrow = (await get(`${centreQs}&radiusKm=10`)).body;
    assert.deepEqual(blowNames(narrow.data.blowingUp), near('blow'));
    assert.deepEqual(myGenres(narrow), [genre(NEAR)]);
  });

  it('with cityId the modules only contain items within the radius (inactive city works)', async () => {
    const def = (await get(`cityId=${cityId}`)).body;
    assert.deepEqual(evNames(def.data.today), near('today'));
    assert.deepEqual(clubNames(def.data.popularOrganizers), [`${P} club ${NEAR}km`]);
    assert.deepEqual(myGenres(def), [genre(NEAR)]);
    const r30 = (await get(`cityId=${cityId}&radiusKm=30`)).body;
    assert.deepEqual(evNames(r30.data.tomorrow), near('tomorrow'));
    const r40 = (await get(`cityId=${cityId}&radiusKm=40`)).body;
    assert.deepEqual(evNames(r40.data.tomorrow), both('tomorrow'));
    assert.deepEqual(blowNames(r40.data.blowingUp), both('blow'));
    assert.equal(r40.data.today.length, 2);
  });

  it('lat/lng win over cityId when both are sent', async () => {
    const lat = CENTRE.lat + FAR / KM_PER_DEG;
    const { status, body } = await get(`cityId=${cityId}&lat=${lat}&lng=${CENTRE.lng}&radiusKm=10`);
    assert.equal(status, 200);
    assert.deepEqual(evNames(body.data.today), [ev('today', FAR)]);
    assert.deepEqual(clubNames(body.data.popularOrganizers), [`${P} club ${FAR}km`]);
  });

  it('a centre combines with the city text filter (both apply)', async () => {
    const { body } = await get(`${centreQs}&city=NoSuchPlaceAnywhere`);
    assert.deepEqual(body.data.today, []);
  });

  it('radiusKm without a centre changes nothing', async () => {
    const a = (await get()).body;
    const b = (await get('radiusKm=10')).body;
    assert.deepEqual(evNames(b.data.today), evNames(a.data.today));
    assert.deepEqual(myGenres(b), myGenres(a));
  });

  it('lat without lng is not a centre (unchanged result)', async () => {
    const { status, body } = await get(`lat=${CENTRE.lat}`);
    assert.equal(status, 200);
    assert.deepEqual(evNames(body.data.today), both('today'));
  });

  it('unknown cityId returns 404', async () => {
    const { status, body } = await get(`cityId=${randomUUID()}`);
    assert.equal(status, 404);
    assert.equal(body.success, false);
  });

  it('malformed cityId returns 422', async () => {
    assert.equal((await get('cityId=not-a-uuid')).status, 422);
  });

  it('radiusKm outside 10,20,30,40,50 returns 422 (as GET /explore)', async () => {
    for (const bad of ['25', '0', '60', '5', 'abc', '-10']) {
      assert.equal((await get(`${centreQs}&radiusKm=${bad}`)).status, 422, `radiusKm=${bad}`);
    }
    for (const ok of ['10', '20', '30', '40', '50']) {
      assert.equal((await get(`${centreQs}&radiusKm=${ok}`)).status, 200, `radiusKm=${ok}`);
    }
  });
});
