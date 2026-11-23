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

// T-035 (CR-09, CR-10): GET /explore group=day, from, to, dateFilter=this_week and meta.total.
// Service tests inject the clock (`now`), so they do not depend on the real date. Route tests use
// events in the year 2090 only. Rows carry a per-run prefix and are removed in after().
// Calendar facts: 2027-03-24 is a Wednesday; Europe/Rome switches to summer time on Sunday 2027-03-28.

const run = randomUUID().replace(/-/g, '').slice(0, 8).toUpperCase();
const P = `T35${run}`;
const CENTRE = { lat: -60, lng: -121 };
const H = 3_600_000;

type Item = { id: string; name: string; type: string; [k: string]: unknown };
type Group = { label: string; date: string; items: Item[] };
type Body = { success: boolean; data: Item[] | Group[]; meta: { total: number; totalPages: number; links: unknown } };

describe('explore day grouping, date range, this_week, total (T-035)', { skip: dbTestSkipReason() }, () => {
  let appPrisma: PrismaClient;
  let srv: Awaited<ReturnType<typeof startTestServer>>;
  let ownerId: string;
  let cityId: string;
  let listService: typeof import('@/app/modules/explore/explore.services').exploreListService;
  let schema: typeof import('@/app/modules/explore/explore.schema').exploreQuerySchema;
  const db = () => getTestPrisma();

  const NOW = new Date('2027-03-24T12:00:00Z'); // Wednesday, 13:00 in Rome

  const mkEvent = async (name: string, startIso: string, timezone: string, durationH = 5) => {
    const startAt = new Date(startIso);
    const e = await db().event.create({
      data: {
        userId: ownerId,
        eventName: `${P} ${name}`,
        thumbnail: 'https://example.test/t.png',
        lat: CENTRE.lat,
        lng: CENTRE.lng,
        location: 'Remote',
        startAt,
        endAt: new Date(startAt.getTime() + durationH * H),
        dressCode: 'casual',
        eventPrice: 10,
        currency: 'USD',
        timezone,
      },
    });
    await db().$executeRaw`UPDATE "Event" SET geog = ST_SetSRID(ST_MakePoint(${CENTRE.lng}, ${CENTRE.lat}), 4326)::geography WHERE id = ${e.id}`;
    return e;
  };

  const call = async (q: Record<string, unknown>, now = NOW) => {
    const query = schema.parse({ search: P, type: 'EVENT', limit: 50, ...q });
    return listService({ query, now });
  };
  const names = (rows: { name: string }[]) => rows.map((r) => r.name.replace(`${P} `, ''));

  const get = async (qs: string) => {
    const r = await fetch(`${srv.baseUrl}/api/v1/explore?${qs}`);
    return { status: r.status, body: (await r.json()) as Body };
  };

  before(async () => {
    process.env.DATABASE_URL = assertSafeTestDatabaseUrl(process.env.TEST_DATABASE_URL);
    installFakeRedis();
    appPrisma = (await import('@/app/configs/db.configs')).default;
    listService = (await import('@/app/modules/explore/explore.services')).exploreListService;
    schema = (await import('@/app/modules/explore/explore.schema')).exploreQuerySchema;

    const owner = await db().user.create({
      data: {
        name: 'T035 owner',
        email: `t035-${run}@example.test`,
        phoneNumber: `+1555${Math.floor(Math.random() * 1e7)}`,
        accountRole: 'CLUB_OWNER',
        isVerified: true,
      },
    });
    ownerId = owner.id;

    // Rome events (zone stored on the event).
    await mkEvent('today', '2027-03-24T20:00:00Z', 'Europe/Rome');
    await mkEvent('overnight', '2027-03-25T22:00:00Z', 'Europe/Rome', 5); // Thu 23:00 to Fri 04:00 local
    await mkEvent('weekend', '2027-03-26T22:00:00Z', 'Europe/Rome'); // Fri 23:00 local
    await mkEvent('dstmonday', '2027-03-28T22:30:00Z', 'Europe/Rome'); // Mon 29th 00:30 CEST
    await mkEvent('upcoming', '2027-04-10T20:00:00Z', 'Europe/Rome');
    // Default-zone event: 23:30Z on the 24th is the 24th in UTC but the 25th in Rome.
    await mkEvent('utc', '2027-03-24T23:30:00Z', 'UTC');
    // Far future, for route tests that use the real clock.
    await mkEvent('far1', '2090-06-01T20:00:00Z', 'UTC');
    await mkEvent('far2', '2090-06-02T20:00:00Z', 'UTC');

    const city = await db().city.create({
      data: { name: `${P} City`, countryCode: 'ZZ', lat: CENTRE.lat, lng: CENTRE.lng, timezone: 'Europe/Rome', isLaunched: false },
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
      await db().city.deleteMany({ where: { name: { startsWith: P } } });
      await db().user.deleteMany({ where: { id: ownerId } });
    } finally {
      await srv?.close();
      await appPrisma?.$disconnect();
      await closeTestPrisma();
    }
  });

  it('group=day buckets each event in its own zone; the UTC-default event is bucketed by UTC day', async () => {
    const { data, total } = (await call({ group: 'day' })) as unknown as { data: Group[]; total: number };
    assert.deepEqual(
      data.map((g) => [g.label, g.date, names(g.items)]),
      [
        ['Today', '2027-03-24', ['today', 'utc']],
        ['Tomorrow', '2027-03-25', ['overnight']],
        ['This Weekend', '2027-03-26', ['weekend']],
        ['Upcoming', '2027-03-29', ['dstmonday', 'upcoming', 'far1', 'far2']],
      ]
    );
    assert.equal(total, 8); // grouping does not change the count; the two 2090 events sit in Upcoming
  });

  it('group=day with cityId uses the city zone for every event', async () => {
    const { data } = (await call({ group: 'day', cityId, radiusKm: 10 })) as unknown as { data: Group[] };
    // utc event (23:30Z on the 24th) is the 25th in Rome.
    const tomorrow = data.find((g) => g.label === 'Tomorrow');
    assert.deepEqual(names(tomorrow?.items ?? []), ['utc', 'overnight']);
    const today = data.find((g) => g.label === 'Today');
    assert.deepEqual(names(today?.items ?? []), ['today']);
  });

  it('from and to select by local start date and are inclusive; a DST-shifted Monday stays on Monday', async () => {
    const a = await call({ from: '2027-03-25', to: '2027-03-26' });
    assert.deepEqual(names(a.data as { name: string }[]), ['overnight', 'weekend']);
    assert.equal(a.total, 2);
    const b = await call({ from: '2027-03-28', to: '2027-03-28' });
    assert.deepEqual(names(b.data as { name: string }[]), []);
    const c = await call({ from: '2027-03-29', to: '2027-03-29' });
    assert.deepEqual(names(c.data as { name: string }[]), ['dstmonday']);
    // only from / only to
    const d = await call({ to: '2027-03-24' });
    assert.deepEqual(names(d.data as { name: string }[]), ['today', 'utc']);
  });

  it('from and to with cityId use the city zone', async () => {
    const r = await call({ from: '2027-03-25', to: '2027-03-25', cityId, radiusKm: 10 });
    assert.deepEqual(names(r.data as { name: string }[]), ['utc', 'overnight']);
  });

  it('this_week is Monday to Sunday of the local week', async () => {
    const r = await call({ dateFilter: 'this_week' });
    assert.deepEqual(names(r.data as { name: string }[]), ['today', 'utc', 'overnight', 'weekend']);
    assert.equal(r.total, 4);
  });

  it('this_week does not shift at the DST change (now = Monday 00:45 local, still Sunday 22:45Z)', async () => {
    const mondayLocal = new Date('2027-03-28T22:45:00Z'); // 00:45 CEST on Monday the 29th
    const r = await call({ dateFilter: 'this_week' }, mondayLocal);
    assert.deepEqual(names(r.data as { name: string }[]), ['dstmonday']);
  });

  it('total equals the unpaged count with the same filters; paging does not change it', async () => {
    const all = await call({ from: '2027-03-24', to: '2027-04-30' });
    const page = await call({ from: '2027-03-24', to: '2027-04-30', limit: 2, page: 2 });
    assert.equal(all.total, all.data.length);
    assert.equal(page.total, all.total);
    assert.equal(page.data.length, 2);
    assert.deepEqual(names(page.data as { name: string }[]), names((all.data as { name: string }[]).slice(2, 4)));
  });

  it('route: from after to returns 422; malformed date returns 422; group=day with type=CLUB returns 422', async () => {
    assert.equal((await get('from=2090-06-02&to=2090-06-01')).status, 422);
    assert.equal((await get('from=2090-6-2')).status, 422);
    assert.equal((await get('group=day&type=CLUB')).status, 422);
    assert.equal((await get('from=2090-06-01&to=2090-06-01')).status, 200);
  });

  it('route: meta.total equals the unpaged count', async () => {
    const q = `type=EVENT&search=${P}&from=2090-01-01&to=2090-12-31`;
    const paged = await get(`${q}&limit=1`);
    const full = await get(`${q}&limit=50`);
    assert.equal(paged.status, 200);
    assert.equal(paged.body.data.length, 1);
    assert.equal(full.body.data.length, 2);
    assert.equal(paged.body.meta.total, 2);
    assert.equal(full.body.meta.total, 2);
  });

  it('route: without the new params the response keeps the old shape plus total', async () => {
    const { status, body } = await get(`type=EVENT&search=${P}&limit=50`);
    assert.equal(status, 200);
    assert.equal(body.success, true);
    assert.ok(Array.isArray(body.data));
    assert.equal(typeof body.meta.total, 'number');
    assert.equal(typeof body.meta.totalPages, 'number');
    assert.ok(body.meta.links);
    for (const i of body.data as Item[]) {
      assert.equal('items' in i, false, 'flat items, not groups');
      assert.equal('label' in i, false);
      assert.deepEqual(
        Object.keys(i).sort(),
        ['currency', 'id', 'lat', 'lng', 'location', 'name', 'price', 'thumbnail', 'type'].sort()
      );
    }
    // old ordering (createdAt DESC) is kept: the last created fixture comes first
    assert.equal((body.data as Item[])[0]?.name, `${P} far2`);
    const g = await get(`type=EVENT&search=${P}&group=none`);
    assert.deepEqual(g.body.data, (await get(`type=EVENT&search=${P}`)).body.data);
  });

  it('route: group=day returns [{label, date, items}] with the same meta', async () => {
    const { status, body } = await get(`type=EVENT&search=${P}&group=day&from=2090-01-01&to=2090-12-31`);
    assert.equal(status, 200);
    const groups = body.data as Group[];
    assert.equal(groups.length, 1);
    assert.equal(groups[0]?.label, 'Upcoming');
    assert.equal(groups[0]?.date, '2090-06-01');
    assert.deepEqual(names(groups[0]?.items ?? []), ['far1', 'far2']);
    assert.equal(body.meta.total, 2);
  });
});
