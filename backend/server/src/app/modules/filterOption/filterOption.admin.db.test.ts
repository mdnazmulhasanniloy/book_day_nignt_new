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

// T-037: GET/POST /admin/filter-options and PATCH /admin/filter-options/{id}
// through the real router, real admin middlewares, real global error handler,
// fake Redis. Rows use a per-run label prefix and are removed in after().

const run = randomUUID().replace(/-/g, '').slice(0, 8).toUpperCase();
const P = `T37${run}`;

type Opt = {
  id: string;
  kind: string;
  label: string;
  sortOrder: number;
  isActive: boolean;
};
type Body = {
  success: boolean;
  message: string;
  errorType?: string;
  data?: Opt & Opt[];
};

describe('admin filter-options (T-037)', { skip: dbTestSkipReason() }, () => {
  let appPrisma: PrismaClient;
  let srv: Awaited<ReturnType<typeof startTestServer>>;
  const db = () => getTestPrisma();
  const csrf = 'csrf-' + run;
  let adminToken: string;
  let userToken: string;
  const emails = `t037a-${run}-`;

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
  const json = async (r: Response) => (await r.json()) as Body;
  const mk = (
    suffix: string,
    extra: { kind?: 'GENRE' | 'MOOD'; sortOrder?: number; isActive?: boolean } = {}
  ) =>
    db().filterOption.create({
      data: {
        kind: extra.kind ?? 'GENRE',
        label: `${P} ${suffix}`,
        labelKey: `${P} ${suffix}`.toLowerCase(),
        sortOrder: extra.sortOrder ?? 0,
        isActive: extra.isActive ?? true,
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
          name: `T037 ${tag}`,
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

    const routes = (await import('@/app/modules/filterOption/filterOption.routes'))
      .default;
    const { globalErrorMiddleware } = await import(
      '@/app/middlewares/globalError.middlewares'
    );
    const app = express();
    app.use(express.json());
    app.use(cookieParser());
    app.use('/api/v1', routes);
    app.use(globalErrorMiddleware);
    srv = await startTestServer(app);
  });

  after(async () => {
    try {
      await db().event.deleteMany({ where: { user: { email: { startsWith: emails } } } });
      await db().filterOption.deleteMany({ where: { label: { startsWith: P } } });
      await db().user.deleteMany({ where: { email: { startsWith: emails } } });
    } finally {
      await srv?.close();
      await appPrisma?.$disconnect();
      await closeTestPrisma();
    }
  });

  describe('admin auth chain', () => {
    const valid = () => ({ kind: 'GENRE', label: `${P} Auth` });

    it('rejects a missing cookie (401) on every route', async () => {
      const id = randomUUID();
      for (const [m, p, body] of [
        ['GET', '/admin/filter-options', undefined],
        ['POST', '/admin/filter-options', valid()],
        ['PATCH', `/admin/filter-options/${id}`, { label: 'x' }],
      ] as const) {
        assert.equal((await call(m, p, { body })).status, 401, `${m} ${p}`);
      }
    });

    it('rejects a customer token (403) on every route and writes nothing', async () => {
      const id = randomUUID();
      for (const [m, p, body] of [
        ['GET', '/admin/filter-options', undefined],
        ['POST', '/admin/filter-options', valid()],
        ['PATCH', `/admin/filter-options/${id}`, { label: 'x' }],
      ] as const) {
        assert.equal((await call(m, p, { token: userToken, body })).status, 403, `${m} ${p}`);
      }
      assert.equal(await db().filterOption.count({ where: { label: `${P} Auth` } }), 0);
    });

    it('POST and PATCH reject a missing or wrong CSRF header (403); GET needs none', async () => {
      const row = await mk('CsrfTarget');
      for (const csrfHeader of [null, 'wrong']) {
        const post = await call('POST', '/admin/filter-options', {
          token: adminToken,
          csrfHeader,
          body: valid(),
        });
        assert.equal(post.status, 403);
        const patch = await call('PATCH', `/admin/filter-options/${row.id}`, {
          token: adminToken,
          csrfHeader,
          body: { isActive: false },
        });
        assert.equal(patch.status, 403);
      }
      const noCookie = await call('POST', '/admin/filter-options', {
        token: adminToken,
        csrfCookie: false,
        body: valid(),
      });
      assert.equal(noCookie.status, 403);
      assert.equal(
        (await db().filterOption.findUniqueOrThrow({ where: { id: row.id } })).isActive,
        true
      );
      assert.equal(await db().filterOption.count({ where: { label: `${P} Auth` } }), 0);
      const list = await call('GET', '/admin/filter-options', {
        token: adminToken,
        csrfHeader: null,
        csrfCookie: false,
      });
      assert.equal(list.status, 200);
    });
  });

  describe('GET /admin/filter-options', () => {
    it('lists active and inactive rows with the spec fields, filters by kind', async () => {
      await mk('ListB', { sortOrder: 2 });
      await mk('ListA', { sortOrder: 1, isActive: false });
      await mk('ListMood', { kind: 'MOOD', sortOrder: 1 });
      const all = await json(await adminCall('GET', '/admin/filter-options'));
      const mine = (all.data as unknown as Opt[]).filter((o) => o.label.startsWith(P));
      const labels = mine.map((o) => o.label);
      assert.ok(labels.includes(`${P} ListA`), 'inactive rows are listed');
      assert.ok(labels.includes(`${P} ListMood`));
      const a = mine.find((o) => o.label === `${P} ListA`) as Opt;
      assert.deepEqual(Object.keys(a).sort(), [
        'id',
        'isActive',
        'kind',
        'label',
        'sortOrder',
      ]);
      assert.equal(a.isActive, false);

      const genres = await json(await adminCall('GET', '/admin/filter-options?kind=GENRE'));
      const g = (genres.data as unknown as Opt[]).filter((o) => o.label.startsWith(P));
      const gl = g.map((o) => o.label);
      assert.ok(gl.indexOf(`${P} ListA`) >= 0 && gl.indexOf(`${P} ListA`) < gl.indexOf(`${P} ListB`));
      assert.ok(!gl.includes(`${P} ListMood`));
      assert.ok(g.every((o) => o.kind === 'GENRE'));
      assert.equal((await adminCall('GET', '/admin/filter-options?kind=BAD')).status, 422);
    });
  });

  describe('POST /admin/filter-options', () => {
    it('creates with labelKey lowercased and trimmed, default sortOrder 0, isActive true', async () => {
      const r = await adminCall('POST', '/admin/filter-options', {
        kind: 'MOOD',
        label: `  ${P} Dreamy  `,
        sortOrder: 7,
      });
      assert.equal(r.status, 201);
      const b = await json(r);
      assert.equal(b.data?.label, `${P} Dreamy`);
      assert.equal(b.data?.kind, 'MOOD');
      assert.equal(b.data?.sortOrder, 7);
      assert.equal(b.data?.isActive, true);
      const row = await db().filterOption.findUniqueOrThrow({
        where: { id: b.data?.id as string },
      });
      assert.equal(row.labelKey, `${P} Dreamy`.toLowerCase());

      const d = await json(
        await adminCall('POST', '/admin/filter-options', {
          kind: 'GENRE',
          label: `${P} Defaults`,
        })
      );
      assert.equal(d.data?.sortOrder, 0);
    });

    it('duplicate label that differs only by case or whitespace -> 409, nothing stored', async () => {
      await mk('Dup');
      for (const label of [`${P} DUP`, `  ${P} dup `, `${P} Dup`]) {
        const r = await adminCall('POST', '/admin/filter-options', {
          kind: 'GENRE',
          label,
        });
        assert.equal(r.status, 409, label);
      }
      assert.equal(
        await db().filterOption.count({ where: { labelKey: `${P} Dup`.toLowerCase() } }),
        1
      );
    });

    it('the same label under the other kind is allowed', async () => {
      await mk('Both', { kind: 'GENRE' });
      const r = await adminCall('POST', '/admin/filter-options', {
        kind: 'MOOD',
        label: `${P} both`,
      });
      assert.equal(r.status, 201);
    });

    it('invalid body -> 422 and nothing is stored', async () => {
      const cases: [string, unknown][] = [
        ['no kind', { label: `${P} Bad` }],
        ['bad kind', { kind: 'ARTIST', label: `${P} Bad` }],
        ['no label', { kind: 'GENRE' }],
        ['blank label', { kind: 'GENRE', label: '   ' }],
        ['label too long', { kind: 'GENRE', label: 'x'.repeat(121) }],
        ['float sortOrder', { kind: 'GENRE', label: `${P} Bad`, sortOrder: 1.5 }],
        ['string sortOrder', { kind: 'GENRE', label: `${P} Bad`, sortOrder: '3' }],
        ['isActive on create', { kind: 'GENRE', label: `${P} Bad`, isActive: false }],
        ['unknown field', { kind: 'GENRE', label: `${P} Bad`, extra: 1 }],
      ];
      for (const [name, body] of cases) {
        assert.equal((await adminCall('POST', '/admin/filter-options', body)).status, 422, name);
      }
      assert.equal(await db().filterOption.count({ where: { label: `${P} Bad` } }), 0);
    });
  });

  describe('PATCH /admin/filter-options/{id}', () => {
    it('renames (labelKey follows), reorders and deactivates; response has the spec fields', async () => {
      const row = await mk('Patch', { sortOrder: 1 });
      const r = await adminCall('PATCH', `/admin/filter-options/${row.id}`, {
        label: `  ${P} Renamed `,
        sortOrder: 9,
        isActive: false,
      });
      assert.equal(r.status, 200);
      const b = await json(r);
      assert.deepEqual(b.data, {
        id: row.id,
        kind: 'GENRE',
        label: `${P} Renamed`,
        sortOrder: 9,
        isActive: false,
      });
      const after = await db().filterOption.findUniqueOrThrow({ where: { id: row.id } });
      assert.equal(after.labelKey, `${P} Renamed`.toLowerCase());
    });

    it('a partial body changes only the named field', async () => {
      const row = await mk('Partial', { sortOrder: 4 });
      const r = await adminCall('PATCH', `/admin/filter-options/${row.id}`, {
        isActive: false,
      });
      assert.equal(r.status, 200);
      const after = await db().filterOption.findUniqueOrThrow({ where: { id: row.id } });
      assert.equal(after.label, row.label);
      assert.equal(after.labelKey, row.labelKey);
      assert.equal(after.sortOrder, 4);
      assert.equal(after.isActive, false);
    });

    it('renaming to a case or whitespace variant of another row -> 409; own label in another case is fine', async () => {
      const a = await mk('RenA');
      await mk('RenB');
      const clash = await adminCall('PATCH', `/admin/filter-options/${a.id}`, {
        label: `  ${P} RENB `,
      });
      assert.equal(clash.status, 409);
      assert.equal(
        (await db().filterOption.findUniqueOrThrow({ where: { id: a.id } })).label,
        `${P} RenA`
      );
      const own = await adminCall('PATCH', `/admin/filter-options/${a.id}`, {
        label: `${P} rena`,
      });
      assert.equal(own.status, 200);
    });

    it('unknown id -> 404; non-uuid id -> 422; invalid or empty body -> 422', async () => {
      const row = await mk('Invalid');
      assert.equal(
        (await adminCall('PATCH', `/admin/filter-options/${randomUUID()}`, { isActive: false }))
          .status,
        404
      );
      assert.equal(
        (await adminCall('PATCH', '/admin/filter-options/not-a-uuid', { isActive: false }))
          .status,
        422
      );
      for (const body of [
        {},
        { label: '' },
        { label: '   ' },
        { sortOrder: 'x' },
        { sortOrder: 1.2 },
        { isActive: 'no' },
        { kind: 'MOOD' },
        { labelKey: 'x' },
      ]) {
        assert.equal(
          (await adminCall('PATCH', `/admin/filter-options/${row.id}`, body)).status,
          422,
          JSON.stringify(body)
        );
      }
      const after = await db().filterOption.findUniqueOrThrow({ where: { id: row.id } });
      assert.equal(after.kind, 'GENRE');
      assert.equal(after.label, row.label);
    });

    it('deactivating a value never edits existing events', async () => {
      const row = await mk('InUse');
      const u = await db().user.create({
        data: {
          name: 'T037 owner',
          email: `${emails}owner@example.test`,
          phoneNumber: `+1555${Math.floor(Math.random() * 1e7)}`,
          isVerified: true,
        },
      });
      const ev = await db().event.create({
        data: {
          userId: u.id,
          eventName: 'in use',
          thumbnail: 'https://example.test/t.png',
          lat: 1,
          lng: 2,
          startAt: new Date(Date.now() + 86_400_000),
          endAt: new Date(Date.now() + 2 * 86_400_000),
          dressCode: 'casual',
          eventPrice: 10,
          currency: 'USD',
          musicGenres: [row.label],
          moodTags: [`${P} mood`],
        },
      });
      const snap = JSON.stringify(
        await db().event.findUniqueOrThrow({ where: { id: ev.id } })
      );
      const r = await adminCall('PATCH', `/admin/filter-options/${row.id}`, {
        isActive: false,
        label: `${P} InUse Renamed`,
      });
      assert.equal(r.status, 200);
      const after = JSON.stringify(
        await db().event.findUniqueOrThrow({ where: { id: ev.id } })
      );
      assert.equal(after, snap);
    });
  });
});
