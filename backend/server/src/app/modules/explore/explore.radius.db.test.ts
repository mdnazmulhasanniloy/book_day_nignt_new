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

// T-034 (CR-09, BUG-B28): GET /explore radiusKm, cityId, distanceKm through the real explore
// router and error handler, fake Redis. Fixtures sit around a remote ocean point so no other
// data can fall inside the radius. Rows carry a per-run prefix and are removed in after().

const run = randomUUID().replace(/-/g, '').slice(0, 8).toUpperCase();
const P = `T34${run}`;
const CENTRE = { lat: -60, lng: -120 };
const KM_PER_DEG = 111.195; // great-circle km per degree of latitude (R = 6371 km)
// Distances (km) north of the centre. Clubs and events share them.
const DISTANCES = [5, 15, 19, 25, 35, 45, 55];

type Item = {
  id: string;
  name: string;
  type: 'CLUB' | 'EVENT';
  distanceKm?: number;
  [k: string]: unknown;
};
type Body = { success: boolean; data: Item[]; meta: { total: number }; message?: string };

describe('explore radiusKm, cityId, distanceKm (T-034)', { skip: dbTestSkipReason() }, () => {
  let appPrisma: PrismaClient;
  let srv: Awaited<ReturnType<typeof startTestServer>>;
  let ownerId: string;
  let cityId: string;
  const db = () => getTestPrisma();

  const get = async (qs: string) => {
    const r = await fetch(`${srv.baseUrl}/api/v1/explore?${qs}`);
    return { status: r.status, body: (await r.json()) as Body };
  };
  const centreQs = `lat=${CENTRE.lat}&lng=${CENTRE.lng}&limit=50`;
  const names = (b: Body) => b.data.filter((i) => i.name.startsWith(P)).map((i) => i.name);
  const km = (n: number) => `${n}km`;

  before(async () => {
    process.env.DATABASE_URL = assertSafeTestDatabaseUrl(process.env.TEST_DATABASE_URL);
    installFakeRedis();
    appPrisma = (await import('@/app/configs/db.configs')).default;

    const owner = await db().user.create({
      data: {
        name: 'T034 owner',
        email: `t034-${run}@example.test`,
        phoneNumber: `+1555${Math.floor(Math.random() * 1e7)}`,
        accountRole: 'CLUB_OWNER',
        isVerified: true,
      },
    });
    ownerId = owner.id;

    // createdAt descending with distance index so ordering is deterministic: nearest is newest.
    const base = Date.now();
    for (const [i, d] of DISTANCES.entries()) {
      const lat = CENTRE.lat + d / KM_PER_DEG;
      const createdAt = new Date(base - i * 60_000);
      const club = await db().club.create({
        data: {
          userId: ownerId,
          name: `${P} club ${km(d)}`,
          thumbnail: 'https://example.test/t.png',
          dressCode: 'casual',
          lat,
          lng: CENTRE.lng,
          createdAt,
        },
      });
      const event = await db().event.create({
        data: {
          userId: ownerId,
          eventName: `${P} event ${km(d)}`,
          thumbnail: 'https://example.test/t.png',
          lat,
          lng: CENTRE.lng,
          location: 'Remote',
          startAt: new Date(base + 86_400_000),
          endAt: new Date(base + 2 * 86_400_000),
          dressCode: 'casual',
          eventPrice: 10,
          currency: 'USD',
          createdAt,
        },
      });
      // Do not rely on a trigger: set geog explicitly from lat/lng.
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

  const expectedWithin = (radius: number) => {
    const out: string[] = [];
    for (const d of DISTANCES.filter((x) => x <= radius)) {
      out.push(`${P} club ${km(d)}`, `${P} event ${km(d)}`);
    }
    return out;
  };

  it('without radiusKm the server keeps the fixed 20 km radius and old ordering', async () => {
    const { status, body } = await get(centreQs);
    assert.equal(status, 200);
    // Old behaviour: ST_DWithin 20000 m, ORDER BY createdAt DESC (club and event of one distance share createdAt).
    assert.deepEqual(
      [...new Set(names(body).map((n) => n.split(' ').pop()))],
      ['5km', '15km', '19km']
    );
    assert.deepEqual([...names(body)].sort(), expectedWithin(20).sort());
  });

  it('radiusKm=20 equals the default result', async () => {
    const a = await get(centreQs);
    const b = await get(`${centreQs}&radiusKm=20`);
    assert.deepEqual(names(b.body), names(a.body));
  });

  it('radius 50 is a superset of radius 10; items carry distanceKm within the radius', async () => {
    const r10 = await get(`${centreQs}&radiusKm=10`);
    const r50 = await get(`${centreQs}&radiusKm=50`);
    assert.equal(r10.status, 200);
    assert.deepEqual([...names(r10.body)].sort(), expectedWithin(10).sort());
    assert.deepEqual([...names(r50.body)].sort(), expectedWithin(50).sort());
    const set50 = new Set(r50.body.data.map((i) => i.id));
    for (const i of r10.body.data) assert.ok(set50.has(i.id), 'radius 10 item present in radius 50');
    assert.ok(r50.body.data.length > r10.body.data.length);
    for (const i of r50.body.data) {
      assert.equal(typeof i.distanceKm, 'number');
      assert.ok((i.distanceKm as number) <= 50, `distanceKm ${i.distanceKm} within 50`);
      assert.equal(i.distanceKm, Math.round((i.distanceKm as number) * 10) / 10, 'one decimal');
    }
    const c35 = r50.body.data.find((i) => i.name === `${P} club ${km(35)}`);
    assert.ok(c35);
    assert.ok(Math.abs((c35.distanceKm as number) - 35) <= 0.2);
  });

  it('distanceKm is absent when there is no centre', async () => {
    const { status, body } = await get(`limit=50&search=${P}`);
    assert.equal(status, 200);
    assert.ok(body.data.length > 0);
    for (const i of body.data) assert.equal('distanceKm' in i, false);
  });

  it('radiusKm without a centre changes nothing', async () => {
    const a = await get(`limit=50&search=${P}`);
    const b = await get(`limit=50&search=${P}&radiusKm=10`);
    assert.equal(b.status, 200);
    assert.deepEqual(names(b.body), names(a.body));
    assert.equal(a.body.data.length, DISTANCES.length * 2);
  });

  it('cityId is the centre when lat/lng are absent (inactive city works)', async () => {
    const { status, body } = await get(`cityId=${cityId}&radiusKm=30&limit=50`);
    assert.equal(status, 200);
    assert.deepEqual([...names(body)].sort(), expectedWithin(30).sort());
    for (const i of body.data.filter((x) => x.name.startsWith(P))) {
      assert.equal(typeof i.distanceKm, 'number');
    }
  });

  it('cityId without radiusKm uses the 20 km default', async () => {
    const { body } = await get(`cityId=${cityId}&limit=50`);
    assert.deepEqual([...names(body)].sort(), expectedWithin(20).sort());
  });

  it('lat/lng win over cityId when both are sent', async () => {
    // lat/lng point at the 55 km spot; the city centre is 55 km away from it.
    const lat = CENTRE.lat + 55 / KM_PER_DEG;
    const { status, body } = await get(`cityId=${cityId}&lat=${lat}&lng=${CENTRE.lng}&radiusKm=10&limit=50`);
    assert.equal(status, 200);
    assert.deepEqual([...names(body)].sort(), [`${P} club 55km`, `${P} event 55km`]);
  });

  it('unknown cityId returns 404', async () => {
    const { status, body } = await get(`cityId=${randomUUID()}`);
    assert.equal(status, 404);
    assert.equal(body.success, false);
  });

  it('malformed cityId returns 422', async () => {
    const { status } = await get('cityId=not-a-uuid');
    assert.equal(status, 422);
  });

  it('radiusKm outside 10,20,30,40,50 returns 422', async () => {
    for (const bad of ['25', '0', '60', '5', 'abc', '-10']) {
      const { status } = await get(`${centreQs}&radiusKm=${bad}`);
      assert.equal(status, 422, `radiusKm=${bad}`);
    }
    for (const ok of ['10', '20', '30', '40', '50']) {
      const { status } = await get(`${centreQs}&radiusKm=${ok}`);
      assert.equal(status, 200, `radiusKm=${ok}`);
    }
  });
});
