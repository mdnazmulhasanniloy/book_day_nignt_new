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

// T-037: GET /explore/filters (public) and the untouched GET /explore/genres
// through the real explore router, real global error handler, fake Redis.

const run = randomUUID().replace(/-/g, '').slice(0, 8).toUpperCase();
const P = `T37${run}`;

type Body = {
  success: boolean;
  message: string;
  errorType?: string;
  traceId?: string;
  data?: unknown;
};
type FiltersData = { categories: string[]; genres: string[]; moods: string[] };

describe('explore filters (T-037)', { skip: dbTestSkipReason() }, () => {
  let appPrisma: PrismaClient;
  let srv: Awaited<ReturnType<typeof startTestServer>>;
  const db = () => getTestPrisma();
  const emails = `t037f-${run}-`;
  const get = async (path: string) => {
    const r = await fetch(`${srv.baseUrl}/api/v1${path}`);
    return { status: r.status, body: (await r.json()) as Body };
  };
  const filters = (b: Body) => b.data as FiltersData;
  const mkOpt = (
    kind: 'GENRE' | 'MOOD',
    label: string,
    sortOrder: number,
    isActive = true
  ) =>
    db().filterOption.create({
      data: { kind, label, labelKey: label.trim().toLowerCase(), sortOrder, isActive },
    });
  const mine = (list: string[] | undefined) =>
    (list ?? []).filter((l) => l.startsWith(P));

  before(async () => {
    process.env.DATABASE_URL = assertSafeTestDatabaseUrl(
      process.env.TEST_DATABASE_URL
    );
    installFakeRedis();
    appPrisma = (await import('@/app/configs/db.configs')).default;
    const [{ current_database: name }] = await appPrisma.$queryRaw<
      { current_database: string }[]
    >`select current_database()`;
    assert.match(name, /_test$/, 'app prisma client must target the test DB');

    const exploreRoutes = (await import('@/app/modules/explore/explore.routes'))
      .default;
    const { globalErrorMiddleware } = await import(
      '@/app/middlewares/globalError.middlewares'
    );
    const app = express();
    app.use(express.json());
    app.use('/api/v1', exploreRoutes);
    app.use(globalErrorMiddleware);
    srv = await startTestServer(app);
  });

  after(async () => {
    try {
      await db().event.deleteMany({ where: { user: { email: { startsWith: emails } } } });
      await db().user.deleteMany({ where: { email: { startsWith: emails } } });
      await db().filterOption.deleteMany({ where: { label: { startsWith: P } } });
    } finally {
      await srv?.close();
      await appPrisma?.$disconnect();
      await closeTestPrisma();
    }
  });

  describe('GET /explore/filters', () => {
    before(async () => {
      await mkOpt('GENRE', `${P} Zeta`, 3);
      await mkOpt('GENRE', `${P} Alpha`, 1);
      await mkOpt('GENRE', `${P} Hidden`, 2, false);
      await mkOpt('GENRE', `${P} Mid`, 2);
      await mkOpt('MOOD', `${P} Chill`, 2);
      await mkOpt('MOOD', `${P} Wild`, 1);
      await mkOpt('MOOD', `${P} Gone`, 0, false);
    });

    it('returns only active rows in sortOrder, inactive hidden, no auth needed', async () => {
      const { status, body } = await get('/explore/filters?type=EVENT');
      assert.equal(status, 200);
      assert.equal(body.success, true);
      assert.deepEqual(mine(filters(body).genres), [
        `${P} Alpha`,
        `${P} Mid`,
        `${P} Zeta`,
      ]);
      assert.deepEqual(mine(filters(body).moods), [`${P} Wild`, `${P} Chill`]);
      assert.ok(!filters(body).genres.includes(`${P} Hidden`));
      assert.ok(!filters(body).moods.includes(`${P} Gone`));
    });

    it('type=EVENT lists the event categories; type=CLUB lists none (spec leaves venue attributes undefined)', async () => {
      const ev = await get('/explore/filters?type=EVENT');
      assert.deepEqual(filters(ev.body).categories, [
        'CLUB',
        'CONCERT',
        'FESTIVAL',
        'OPEN_AIR',
        'WAREHOUSE',
      ]);
      const club = await get('/explore/filters?type=CLUB');
      assert.equal(club.status, 200);
      assert.deepEqual(filters(club.body).categories, []);
      assert.deepEqual(mine(filters(club.body).genres), [
        `${P} Alpha`,
        `${P} Mid`,
        `${P} Zeta`,
      ]);
    });

    it('a row that is deactivated disappears, and comes back when reactivated', async () => {
      const row = await db().filterOption.findFirstOrThrow({
        where: { label: `${P} Mid` },
      });
      await db().filterOption.update({ where: { id: row.id }, data: { isActive: false } });
      let r = await get('/explore/filters?type=EVENT');
      assert.deepEqual(mine(filters(r.body).genres), [`${P} Alpha`, `${P} Zeta`]);
      await db().filterOption.update({ where: { id: row.id }, data: { isActive: true } });
      r = await get('/explore/filters?type=EVENT');
      assert.deepEqual(mine(filters(r.body).genres), [
        `${P} Alpha`,
        `${P} Mid`,
        `${P} Zeta`,
      ]);
    });

    it('rejects a missing or unknown type with 422 (and is not read as an event id)', async () => {
      for (const qs of ['', '?type=', '?type=BOTH', '?type=event']) {
        const r = await get(`/explore/filters${qs}`);
        assert.equal(r.status, 422, qs);
      }
    });
  });

  describe('GET /explore/genres is unchanged', () => {
    it('keeps its exact shape, counts and order, whatever the vocabulary holds', async () => {
      const u = await db().user.create({
        data: {
          name: 'T037 owner',
          email: `${emails}owner@example.test`,
          phoneNumber: `+1555${Math.floor(Math.random() * 1e7)}`,
          isVerified: true,
        },
      });
      const base = {
        userId: u.id,
        thumbnail: 'https://example.test/t.png',
        lat: 1,
        lng: 2,
        startAt: new Date(Date.now() + 86_400_000),
        endAt: new Date(Date.now() + 2 * 86_400_000),
        dressCode: 'casual',
        eventPrice: 10,
        currency: 'USD',
      };
      await db().event.create({
        data: { ...base, eventName: 'a', musicGenres: [`${P}X`, `${P}Y`] },
      });
      await db().event.create({
        data: { ...base, eventName: 'b', musicGenres: [`${P}X`] },
      });
      await db().event.create({
        data: { ...base, eventName: 'c', musicGenres: [`${P}X`, `${P}Z`] },
      });
      await db().event.create({
        data: {
          ...base,
          eventName: 'inactive',
          musicGenres: [`${P}Z`],
          deactivatedAt: new Date(),
        },
      });

      // Snapshot of the pre-T-037 behaviour on this data: counts desc, array of
      // { genre, eventCount }, envelope { success, message, data, traceId }.
      const expected = [
        { genre: `${P}X`, eventCount: 3 },
        { genre: `${P}Y`, eventCount: 1 },
        { genre: `${P}Z`, eventCount: 1 },
      ];
      const pick = (b: Body) =>
        (b.data as { genre: string; eventCount: number }[]).filter((g) =>
          g.genre.startsWith(P)
        );
      const before1 = await get('/explore/genres');
      assert.equal(before1.status, 200);
      assert.deepEqual(Object.keys(before1.body).sort(), [
        'data',
        'message',
        'success',
        'traceId',
      ]);
      assert.equal(before1.body.message, 'Genres retrieved successfully');
      assert.deepEqual(
        pick(before1.body).sort((a, b) => a.genre.localeCompare(b.genre)),
        expected
      );
      assert.equal(pick(before1.body)[0].genre, `${P}X`);

      // Editing the vocabulary must not change the legacy endpoint.
      await mkOpt('GENRE', `${P}X`, 9);
      await mkOpt('GENRE', `${P}Extra`, 10);
      const after1 = await get('/explore/genres');
      assert.deepEqual(
        { ...after1.body, traceId: undefined },
        { ...before1.body, traceId: undefined }
      );
    });
  });
});
