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

// T-038 (CR-10): GET /explore/map. Same filters, centre and radius as GET /explore (shared builder),
// capped lightweight pins, meta reports truncation. Fixtures sit around a remote ocean point.
// Rows carry a per-run prefix and are removed in after().

const run = randomUUID().replace(/-/g, '').slice(0, 8).toUpperCase();
const P = `T38${run}`;
const CENTRE = { lat: -62, lng: -122 };
const KM_PER_DEG = 111.195;
const DISTANCES = [5, 15, 19, 25, 35, 45, 55];
const DAY = 86_400_000;

type Pin = { id: string; type: 'CLUB' | 'EVENT'; name: string; [k: string]: unknown };
type MapBody = {
  success: boolean;
  data: Pin[];
  meta: { total: number; returned: number; maxPins: number; truncated: boolean };
  message?: string;
};

describe('explore map pins (T-038)', { skip: dbTestSkipReason() }, () => {
  let appPrisma: PrismaClient;
  let srv: Awaited<ReturnType<typeof startTestServer>>;
  let ownerId: string;
  let cityId: string;
  let listService: typeof import('@/app/modules/explore/explore.services').exploreListService;
  let mapService: typeof import('@/app/modules/explore/explore.services').exploreMapService;
  let listSchema: typeof import('@/app/modules/explore/explore.schema').exploreQuerySchema;
  let mapSchema: typeof import('@/app/modules/explore/explore.schema').exploreMapQuerySchema;
  const db = () => getTestPrisma();
  const NOW = new Date();

  const getMap = async (qs: string) => {
    const r = await fetch(`${srv.baseUrl}/api/v1/explore/map?${qs}`);
    return { status: r.status, body: (await r.json()) as MapBody };
  };
  const centreQs = `lat=${CENTRE.lat}&lng=${CENTRE.lng}`;
  const mine = <T extends { name: string }>(pins: T[]) => pins.filter((p) => p.name.startsWith(P));

  /** ids from /explore (list) and from the map for the same params. */
  const both = async (params: Record<string, unknown>) => {
    const list = await listService({
      query: listSchema.parse({ search: P, limit: 50, ...params }),
      now: NOW,
    });
    const map = await mapService({ query: mapSchema.parse({ search: P, ...params }), now: NOW });
    return { listIds: list.data.map((i) => i.id), map };
  };

  before(async () => {
    process.env.DATABASE_URL = assertSafeTestDatabaseUrl(process.env.TEST_DATABASE_URL);
    installFakeRedis();
    appPrisma = (await import('@/app/configs/db.configs')).default;
    const services = await import('@/app/modules/explore/explore.services');
    listService = services.exploreListService;
    mapService = services.exploreMapService;
    const schemas = await import('@/app/modules/explore/explore.schema');
    listSchema = schemas.exploreQuerySchema;
    mapSchema = schemas.exploreMapQuerySchema;

    const owner = await db().user.create({
      data: {
        name: 'T038 owner',
        email: `t038-${run}@example.test`,
        phoneNumber: `+1555${Math.floor(Math.random() * 1e7)}`,
        accountRole: 'CLUB_OWNER',
        isVerified: true,
      },
    });
    ownerId = owner.id;

    const base = Date.now();
    for (const [i, d] of DISTANCES.entries()) {
      const lat = CENTRE.lat + d / KM_PER_DEG;
      const club = await db().club.create({
        data: {
          userId: ownerId,
          name: `${P} club ${d}km`,
          thumbnail: 'https://example.test/t.png',
          dressCode: 'casual',
          lat,
          lng: CENTRE.lng,
          isVip: i % 2 === 0,
          createdAt: new Date(base - i * 60_000),
        },
      });
      if (i !== 1) {
        // club 15km has no package: minPrice must be null
        await db().clubPackage.create({
          data: { clubId: club.id, name: 'Table', capacity: 4, price: 100 + i, currency: 'USD', features: [] },
        });
        await db().clubPackage.create({
          data: { clubId: club.id, name: 'Booth', capacity: 8, price: 300 + i, currency: 'USD', features: [] },
        });
      }
      const event = await db().event.create({
        data: {
          userId: ownerId,
          eventName: `${P} event ${d}km`,
          thumbnail: 'https://example.test/t.png',
          lat,
          lng: CENTRE.lng,
          location: 'Remote',
          startAt: new Date(base + (i + 1) * DAY),
          endAt: new Date(base + (i + 1) * DAY + 5 * 3_600_000),
          dressCode: 'casual',
          eventPrice: i === 2 ? 0 : 10 + i,
          currency: 'USD',
          musicGenres: i % 2 === 0 ? ['TECHNO'] : ['HOUSE'],
          moodTags: i < 3 ? ['Chill'] : ['Wild'],
          createdAt: new Date(base - i * 60_000),
        },
      });
      await db().$executeRaw`UPDATE "Club" SET geog = ST_SetSRID(ST_MakePoint(${CENTRE.lng}, ${lat}), 4326)::geography WHERE id = ${club.id}`;
      await db().$executeRaw`UPDATE "Event" SET geog = ST_SetSRID(ST_MakePoint(${CENTRE.lng}, ${lat}), 4326)::geography WHERE id = ${event.id}`;
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

  it('is served at /explore/map, not captured by /explore/:id', async () => {
    const { status, body } = await getMap(`type=EVENT&${centreQs}&search=${P}`);
    assert.equal(status, 200);
    assert.equal(body.success, true);
    assert.ok(Array.isArray(body.data));
    assert.equal(mine(body.data).length, 3); // 5, 15, 19 km within the default 20 km
  });

  it('pins carry only the lightweight fields', async () => {
    const { body } = await getMap(`type=EVENT&${centreQs}&search=${P}`);
    for (const p of mine(body.data)) {
      assert.deepEqual(Object.keys(p).sort(), [
        'distanceKm', 'id', 'lat', 'lng', 'minPrice', 'name', 'startAt', 'thumbnail', 'type',
      ]);
      assert.equal(p.type, 'EVENT');
      assert.equal(typeof p.lat, 'number');
      assert.equal(typeof p.lng, 'number');
      assert.equal(typeof p.startAt, 'string');
      assert.equal(typeof p.minPrice, 'number');
    }
    const clubs = await getMap(`type=CLUB&${centreQs}&search=${P}`);
    const c5 = clubs.body.data.find((p) => p.name === `${P} club 5km`);
    assert.ok(c5);
    assert.deepEqual(Object.keys(c5).sort(), [
      'distanceKm', 'id', 'lat', 'lng', 'minPrice', 'name', 'startAt', 'thumbnail', 'type',
    ]);
    assert.equal(c5.startAt, null);
    assert.equal(c5.minPrice, 100); // cheapest active package
    const c15 = clubs.body.data.find((p) => p.name === `${P} club 15km`);
    assert.ok(c15);
    assert.equal(c15.minPrice, null); // no package: no price
  });

  it('distanceKm is absent without a centre', async () => {
    const { body } = await getMap(`type=EVENT&search=${P}`);
    assert.equal(mine(body.data).length, DISTANCES.length);
    for (const p of mine(body.data)) assert.equal('distanceKm' in p, false);
  });

  it('sorts by distance when a centre exists', async () => {
    const { body } = await getMap(`type=EVENT&${centreQs}&radiusKm=50&search=${P}`);
    const d = mine(body.data).map((p) => p.distanceKm as number);
    assert.equal(d.length, 6);
    assert.deepEqual([...d].sort((a, b) => a - b), d);
  });

  it('map ids equal /explore ids for the same params while under the cap', async () => {
    const cases: Record<string, unknown>[] = [
      { type: 'CLUB', lat: CENTRE.lat, lng: CENTRE.lng },
      { type: 'EVENT', lat: CENTRE.lat, lng: CENTRE.lng, radiusKm: 50 },
      { type: 'EVENT', lat: CENTRE.lat, lng: CENTRE.lng, radiusKm: 50, genres: 'techno' },
      { type: 'EVENT', lat: CENTRE.lat, lng: CENTRE.lng, radiusKm: 50, mood: 'Wild' },
      { type: 'EVENT', lat: CENTRE.lat, lng: CENTRE.lng, radiusKm: 50, isFree: true },
      { type: 'EVENT', lat: CENTRE.lat, lng: CENTRE.lng, radiusKm: 50, minPrice: 12, maxPrice: 14 },
      { type: 'CLUB', lat: CENTRE.lat, lng: CENTRE.lng, radiusKm: 50, minPrice: 301, maxPrice: 303 },
      { type: 'CLUB', lat: CENTRE.lat, lng: CENTRE.lng, radiusKm: 50, isVip: true },
      { type: 'EVENT', cityId, radiusKm: 30 },
      { type: 'EVENT', cityId, radiusKm: 50, from: new Date(NOW.getTime() + 2 * DAY).toISOString().slice(0, 10) },
      { type: 'EVENT', cityId, radiusKm: 50, dateFilter: 'this_week' },
    ];
    for (const params of cases) {
      const { listIds, map } = await both(params);
      assert.deepEqual(
        [...map.data.map((p) => p.id)].sort(),
        [...listIds].sort(),
        `ids differ for ${JSON.stringify(params)}`
      );
      assert.equal(map.meta.truncated, false);
      assert.equal(map.meta.total, listIds.length);
      assert.equal(map.meta.returned, map.data.length);
    }
    // at least one case must be non-trivial
    const nonTrivial = await both({ type: 'EVENT', lat: CENTRE.lat, lng: CENTRE.lng, radiusKm: 50, genres: 'techno' });
    assert.ok(nonTrivial.map.data.length > 0 && nonTrivial.map.data.length < 6);
  });

  it('cap is enforced and meta reports truncation; pins are a subset of /explore', async () => {
    const params = { type: 'EVENT', lat: CENTRE.lat, lng: CENTRE.lng, radiusKm: 50 };
    const list = await listService({ query: listSchema.parse({ search: P, limit: 50, ...params }), now: NOW });
    const map = await mapService({ query: mapSchema.parse({ search: P, ...params }), now: NOW, maxPins: 3 });
    assert.equal(map.data.length, 3);
    assert.deepEqual(map.meta, { total: 6, returned: 3, maxPins: 3, truncated: true });
    const listIds = new Set(list.data.map((i) => i.id));
    for (const p of map.data) assert.ok(listIds.has(p.id), 'pin id is in /explore');
    // truncation keeps the nearest pins
    assert.deepEqual(
      map.data.map((p) => p.name),
      [`${P} event 5km`, `${P} event 15km`, `${P} event 19km`]
    );
    // exactly at the cap: not truncated
    const exact = await mapService({ query: mapSchema.parse({ search: P, ...params }), now: NOW, maxPins: 6 });
    assert.equal(exact.meta.truncated, false);
  });

  it('default cap in meta is 300 (route)', async () => {
    const { body } = await getMap(`type=EVENT&${centreQs}&search=${P}`);
    assert.equal(body.meta.maxPins, 300);
    assert.equal(body.meta.truncated, false);
    assert.equal(body.meta.total, 3);
  });

  it('radiusKm: allowed values work, invalid gives 422', async () => {
    const r30 = await getMap(`type=EVENT&${centreQs}&radiusKm=30&search=${P}`);
    assert.equal(mine(r30.body.data).length, 4);
    const bad = await getMap(`type=EVENT&${centreQs}&radiusKm=25`);
    assert.equal(bad.status, 422);
  });

  it('cityId is the centre; unknown cityId is 404; bad uuid is 422', async () => {
    const ok = await getMap(`type=EVENT&cityId=${cityId}&radiusKm=30&search=${P}`);
    assert.equal(ok.status, 200);
    assert.equal(mine(ok.body.data).length, 4);
    const unknown = await getMap(`type=EVENT&cityId=${randomUUID()}`);
    assert.equal(unknown.status, 404);
    const bad = await getMap(`type=EVENT&cityId=nope`);
    assert.equal(bad.status, 422);
  });

  it('type is required; EVENT rejects club-only filters like /explore', async () => {
    assert.equal((await getMap(centreQs)).status, 422);
    assert.equal((await getMap(`type=EVENT&isVip=true`)).status, 422);
  });

  it('page, limit, sort and group are not part of the map contract (ignored, no pagination)', async () => {
    const { status, body } = await getMap(`type=EVENT&${centreQs}&radiusKm=50&search=${P}&limit=1&page=2&group=day`);
    assert.equal(status, 200);
    assert.equal(mine(body.data).length, 6);
  });
});
