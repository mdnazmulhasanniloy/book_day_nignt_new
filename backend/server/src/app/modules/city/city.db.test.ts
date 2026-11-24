import { after, before, describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import express from 'express';
import cookieParser from 'cookie-parser';
import type { PrismaClient } from '@prisma/client';
import {
  assertSafeTestDatabaseUrl,
  closeTestPrisma,
  dbTestSkipReason,
  getTestPrisma,
} from '@/testing/testDb';
import { installFakeRedis, startTestServer } from '@/testing/fakes';

// T-033: GET /cities, GET/POST /admin/cities, PATCH /admin/cities/{id}
// through the real city router, real admin middlewares, real global error
// handler, fake Redis. Rows use a per-run name prefix and are removed in after().

const run = randomUUID().replace(/-/g, '').slice(0, 8).toUpperCase();
const P = `T33${run}`;

type CityBody = {
  success: boolean;
  message: string;
  errorType?: string;
  data?: Record<string, unknown> & { id?: string };
  meta?: { page: number; limit: number; total: number; totalPages: number };
};

describe('cities (T-033)', { skip: dbTestSkipReason() }, () => {
  let appPrisma: PrismaClient;
  let srv: Awaited<ReturnType<typeof startTestServer>>;
  const db = () => getTestPrisma();
  const csrf = 'csrf-' + run;
  let adminToken: string;
  let userToken: string;
  const emails = `t033-${run}-`;

  const call = (
    method: string,
    path: string,
    opts: {
      token?: string;
      csrfHeader?: string | null;
      csrfCookie?: boolean;
      body?: unknown;
    } = {}
  ) => {
    const cookies: string[] = [];
    if (opts.token) cookies.push(`access_token=${opts.token}`);
    if (opts.csrfCookie !== false) cookies.push(`admin_csrf_token=${csrf}`);
    const headers: Record<string, string> = {
      'content-type': 'application/json',
      cookie: cookies.join('; '),
    };
    const h = opts.csrfHeader === undefined ? csrf : opts.csrfHeader;
    if (h !== null) headers['x-csrf-token'] = h;
    return fetch(`${srv.baseUrl}/api/v1${path}`, {
      method,
      headers,
      ...(opts.body !== undefined ? { body: JSON.stringify(opts.body) } : {}),
    });
  };
  const adminCall = (method: string, path: string, body?: unknown) =>
    call(method, path, { token: adminToken, body });
  const json = async (r: Response) => (await r.json()) as CityBody;
  const mk = (suffix: string, extra: Record<string, unknown> = {}) =>
    db().city.create({
      data: {
        name: `${P} ${suffix}`,
        countryCode: 'FR',
        lat: 43.7,
        lng: 7.26,
        timezone: 'Europe/Paris',
        ...extra,
      },
    });

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

    const jwt = await import('@/app/utils/jwt.utils');
    const mkUser = async (tag: string, role: 'ADMIN' | 'USER') => {
      const u = await db().user.create({
        data: {
          name: `T033 ${tag}`,
          email: `${emails}${tag}@example.test`,
          phoneNumber: `+1555${Math.floor(Math.random() * 1e7)}`,
          accountRole: role,
          isVerified: true,
        },
      });
      return jwt.generateAccessTokenForAdmin({
        sub: u.id,
        role: u.accountRole,
        isVerified: true,
        accountStatus: u.accountStatus,
        rememberMe: true,
      });
    };
    adminToken = await mkUser('admin', 'ADMIN');
    userToken = await mkUser('user', 'USER');

    const cityRoutes = (await import('@/app/modules/city/city.routes')).default;
    const { globalErrorMiddleware } = await import(
      '@/app/middlewares/globalError.middlewares'
    );
    const app = express();
    app.use(express.json());
    app.use(cookieParser());
    app.use('/api/v1', cityRoutes);
    app.use(globalErrorMiddleware);
    srv = await startTestServer(app);
  });

  after(async () => {
    try {
      await db().city.deleteMany({ where: { name: { startsWith: P } } });
      await db().user.deleteMany({ where: { email: { startsWith: emails } } });
    } finally {
      await srv?.close();
      await appPrisma?.$disconnect();
      await closeTestPrisma();
    }
  });

  describe('GET /cities (public)', () => {
    before(async () => {
      await mk('Charlie', { isLaunched: true });
      await mk('Alpha', { isLaunched: true });
      await mk('Bravo', { isLaunched: false });
      await mk('Delta', { isLaunched: false });
    });

    it('needs no auth; returns the City fields sorted by name with meta', async () => {
      const r = await fetch(`${srv.baseUrl}/api/v1/cities?q=${P}`);
      assert.equal(r.status, 200);
      const b = await json(r);
      assert.equal(b.success, true);
      const rows = b.data as unknown as Record<string, unknown>[];
      assert.deepEqual(
        rows.map((c) => c.name),
        [`${P} Alpha`, `${P} Bravo`, `${P} Charlie`, `${P} Delta`]
      );
      assert.deepEqual(Object.keys(rows[0]).sort(), [
        'countryCode',
        'id',
        'isLaunched',
        'lat',
        'lng',
        'name',
        'timezone',
      ]);
      assert.deepEqual(b.meta, { page: 1, limit: 10, total: 4, totalPages: 1 });
    });

    it('q is a case-insensitive prefix match', async () => {
      const lower = await json(
        await fetch(`${srv.baseUrl}/api/v1/cities?q=${P.toLowerCase()}%20br`)
      );
      assert.deepEqual(
        (lower.data as unknown as { name: string }[]).map((c) => c.name),
        [`${P} Bravo`]
      );
      const infix = await json(
        await fetch(`${srv.baseUrl}/api/v1/cities?q=Bravo`)
      );
      assert.equal((infix.data as unknown as unknown[]).length, 0);
    });

    it('launchedOnly=true filters; false returns unlaunched cities too', async () => {
      const only = await json(
        await fetch(`${srv.baseUrl}/api/v1/cities?q=${P}&launchedOnly=true`)
      );
      assert.deepEqual(
        (only.data as unknown as { name: string }[]).map((c) => c.name),
        [`${P} Alpha`, `${P} Charlie`]
      );
      assert.equal(only.meta?.total, 2);
      const all = await json(
        await fetch(`${srv.baseUrl}/api/v1/cities?q=${P}&launchedOnly=false`)
      );
      assert.equal(all.meta?.total, 4);
    });

    it('pages results', async () => {
      const p2 = await json(
        await fetch(`${srv.baseUrl}/api/v1/cities?q=${P}&limit=3&page=2`)
      );
      assert.deepEqual(
        (p2.data as unknown as { name: string }[]).map((c) => c.name),
        [`${P} Delta`]
      );
      assert.deepEqual(p2.meta, { page: 2, limit: 3, total: 4, totalPages: 2 });
    });

    it('rejects bad query values with 422', async () => {
      for (const qs of ['limit=51', 'limit=0', 'page=0', 'launchedOnly=maybe']) {
        const r = await fetch(`${srv.baseUrl}/api/v1/cities?${qs}`);
        assert.equal(r.status, 422, qs);
      }
    });
  });

  describe('admin auth chain', () => {
    const valid = () => ({ name: `${P} Auth`, lat: 1, lng: 2 });

    it('rejects a missing cookie (401) on every admin route', async () => {
      const id = randomUUID();
      for (const [m, p, body] of [
        ['GET', '/admin/cities', undefined],
        ['POST', '/admin/cities', valid()],
        ['PATCH', `/admin/cities/${id}`, { name: 'x' }],
      ] as const) {
        const r = await call(m, p, { body });
        assert.equal(r.status, 401, `${m} ${p}`);
      }
    });

    it('rejects a customer token (403) on every admin route', async () => {
      const id = randomUUID();
      for (const [m, p, body] of [
        ['GET', '/admin/cities', undefined],
        ['POST', '/admin/cities', valid()],
        ['PATCH', `/admin/cities/${id}`, { name: 'x' }],
      ] as const) {
        const r = await call(m, p, { token: userToken, body });
        assert.equal(r.status, 403, `${m} ${p}`);
      }
      assert.equal(await db().city.count({ where: { name: `${P} Auth` } }), 0);
    });

    it('POST and PATCH reject a missing or wrong CSRF header (403); GET needs none', async () => {
      const row = await mk('CsrfTarget');
      for (const csrfHeader of [null, 'wrong']) {
        const post = await call('POST', '/admin/cities', {
          token: adminToken,
          csrfHeader,
          body: valid(),
        });
        assert.equal(post.status, 403);
        const patch = await call('PATCH', `/admin/cities/${row.id}`, {
          token: adminToken,
          csrfHeader,
          body: { isLaunched: true },
        });
        assert.equal(patch.status, 403);
      }
      const noCookie = await call('POST', '/admin/cities', {
        token: adminToken,
        csrfCookie: false,
        body: valid(),
      });
      assert.equal(noCookie.status, 403);
      assert.equal(
        (await db().city.findUniqueOrThrow({ where: { id: row.id } })).isLaunched,
        false
      );
      const list = await call('GET', '/admin/cities', {
        token: adminToken,
        csrfHeader: null,
        csrfCookie: false,
      });
      assert.equal(list.status, 200);
    });
  });

  describe('GET /admin/cities', () => {
    it('lists launched and unlaunched, q prefix, paging', async () => {
      await mk('ListA', { isLaunched: true });
      await mk('ListB', { isLaunched: false });
      const b = await json(await adminCall('GET', `/admin/cities?q=${P}%20list&limit=1`));
      assert.equal(b.meta?.total, 2);
      assert.equal(b.meta?.totalPages, 2);
      assert.equal((b.data as unknown as unknown[]).length, 1);
      const p2 = await json(
        await adminCall('GET', `/admin/cities?q=${P}%20list&limit=1&page=2`)
      );
      assert.equal((p2.data as unknown as { name: string }[])[0].name, `${P} ListB`);
      assert.equal((await adminCall('GET', '/admin/cities?limit=500')).status, 422);
    });
  });

  describe('POST /admin/cities', () => {
    it('creates with isLaunched false and UTC timezone by default', async () => {
      const r = await adminCall('POST', '/admin/cities', {
        name: `${P} Created`,
        countryCode: 'it',
        lat: 43.7,
        lng: 7.26,
      });
      assert.equal(r.status, 201);
      const b = await json(r);
      assert.equal(b.data?.isLaunched, false);
      assert.equal(b.data?.timezone, 'UTC');
      assert.equal(b.data?.countryCode, 'IT');
      assert.equal(b.data?.name, `${P} Created`);
    });

    it('accepts a valid IANA timezone and isLaunched true', async () => {
      const r = await adminCall('POST', '/admin/cities', {
        name: `${P} Tz`,
        countryCode: 'FR',
        lat: 1,
        lng: 2,
        timezone: 'Europe/Paris',
        isLaunched: true,
      });
      assert.equal(r.status, 201);
      const b = await json(r);
      assert.equal(b.data?.timezone, 'Europe/Paris');
      assert.equal(b.data?.isLaunched, true);
    });

    it('duplicate (name, countryCode) -> 409, also with no country', async () => {
      await mk('Dup');
      const dup = await adminCall('POST', '/admin/cities', {
        name: `${P} Dup`,
        countryCode: 'FR',
        lat: 1,
        lng: 2,
      });
      assert.equal(dup.status, 409);
      const other = await adminCall('POST', '/admin/cities', {
        name: `${P} Dup`,
        countryCode: 'IT',
        lat: 1,
        lng: 2,
      });
      assert.equal(other.status, 201);
      const body = { name: `${P} NoCountry`, lat: 1, lng: 2 };
      assert.equal((await adminCall('POST', '/admin/cities', body)).status, 201);
      assert.equal((await adminCall('POST', '/admin/cities', body)).status, 409);
    });

    it('invalid body -> 422 and nothing is stored', async () => {
      const ok = { name: `${P} Bad`, lat: 1, lng: 2 };
      const cases: Record<string, unknown> = {
        'bad timezone': { ...ok, timezone: 'Mars/Olympus' },
        'empty name': { ...ok, name: '   ' },
        'missing name': { lat: 1, lng: 2 },
        'missing lat': { name: ok.name, lng: 2 },
        'lat too big': { ...ok, lat: 91 },
        'lng too big': { ...ok, lng: 181 },
        'lat string': { ...ok, lat: 'x' },
        'bad country': { ...ok, countryCode: 'FRA' },
        'isLaunched string': { ...ok, isLaunched: 'yes' },
      };
      for (const [label, body] of Object.entries(cases)) {
        const r = await adminCall('POST', '/admin/cities', body);
        assert.equal(r.status, 422, label);
      }
      assert.equal(await db().city.count({ where: { name: `${P} Bad` } }), 0);
    });
  });

  describe('PATCH /admin/cities/{id}', () => {
    it('updates fields, launches and unlaunches without deleting; public list can still return it', async () => {
      const row = await mk('Toggle', { isLaunched: false });
      const up = await adminCall('PATCH', `/admin/cities/${row.id}`, {
        isLaunched: true,
        timezone: 'Europe/Rome',
        lat: 44,
        name: `${P} Toggle2`,
      });
      assert.equal(up.status, 200);
      const b = await json(up);
      assert.equal(b.data?.isLaunched, true);
      assert.equal(b.data?.timezone, 'Europe/Rome');
      assert.equal(b.data?.lat, 44);
      assert.equal(b.data?.lng, 7.26);

      const down = await adminCall('PATCH', `/admin/cities/${row.id}`, {
        isLaunched: false,
      });
      assert.equal(down.status, 200);
      assert.equal(await db().city.count({ where: { id: row.id } }), 1);
      const pub = await json(
        await fetch(`${srv.baseUrl}/api/v1/cities?q=${P}%20Toggle2`)
      );
      assert.equal(
        (pub.data as unknown as { id: string }[]).some((c) => c.id === row.id),
        true
      );
      const onlyLaunched = await json(
        await fetch(`${srv.baseUrl}/api/v1/cities?q=${P}%20Toggle2&launchedOnly=true`)
      );
      assert.equal((onlyLaunched.data as unknown as unknown[]).length, 0);
    });

    it('unknown id -> 404; non-uuid id -> 422; invalid body -> 422', async () => {
      const row = await mk('PatchBad');
      assert.equal(
        (await adminCall('PATCH', `/admin/cities/${randomUUID()}`, { name: 'x' })).status,
        404
      );
      assert.equal((await adminCall('PATCH', '/admin/cities/not-a-uuid', { name: 'x' })).status, 422);
      for (const body of [
        { timezone: 'Nope/Nope' },
        { lat: -91 },
        { lng: 200 },
        { name: '' },
        { isLaunched: 'true' },
        {},
      ]) {
        const r = await adminCall('PATCH', `/admin/cities/${row.id}`, body);
        assert.equal(r.status, 422, JSON.stringify(body));
      }
    });

    it('renaming onto an existing (name, countryCode) -> 409', async () => {
      await mk('Taken');
      const row = await mk('Renamed');
      const r = await adminCall('PATCH', `/admin/cities/${row.id}`, {
        name: `${P} Taken`,
      });
      assert.equal(r.status, 409);
      assert.equal(
        (await db().city.findUniqueOrThrow({ where: { id: row.id } })).name,
        `${P} Renamed`
      );
    });
  });
});
