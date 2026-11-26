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

// T-044 (CR-12): GET /admin/artists and PATCH /admin/artists/{id} through the real artists router,
// the real admin middlewares (cookie token, CSRF double submit) and the real error handler.

const run = randomUUID().replace(/-/g, '').slice(0, 8).toUpperCase();
const P = `T44A${run}`;

interface Dto {
  [key: string]: unknown;
  id: string;
  name: string;
}
type Body = {
  success: boolean;
  message: string;
  data: Dto & Dto[];
  meta?: { page: number; limit: number; total: number; totalPages: number };
};

describe('admin artists (T-044)', { skip: dbTestSkipReason() }, () => {
  let appPrisma: PrismaClient;
  let srv: Awaited<ReturnType<typeof startTestServer>>;
  const db = () => getTestPrisma();
  const csrf = 'csrf-' + run;
  const emails = `t044a-${run}-`;
  let adminToken: string;
  let userToken: string;
  const art: Record<string, string> = {};

  const call = (
    method: string,
    path: string,
    opts: { token?: string; csrfHeader?: string | null; csrfCookie?: boolean; body?: unknown } = {}
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
  const admin = (method: string, path: string, body?: unknown) =>
    call(method, path, { token: adminToken, body });
  const json = async (r: Response) => (await r.json()) as Body;

  before(async () => {
    process.env.DATABASE_URL = assertSafeTestDatabaseUrl(process.env.TEST_DATABASE_URL);
    installFakeRedis();
    appPrisma = (await import('@/app/configs/db.configs')).default;
    const jwt = await import('@/app/utils/jwt.utils');
    const mkUser = async (tag: string, role: 'ADMIN' | 'USER') => {
      const u = await db().user.create({
        data: {
          name: `T044A ${tag}`,
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

    for (const [key, extra] of [
      ['Alpha', { isVerified: true, bio: 'a', avatar: 'https://example.test/a.png' }],
      ['Bravo', {}],
      ['Charlie', {}],
    ] as const) {
      const name = `${P} ${key}`;
      const a = await db().artist.create({ data: { name, nameKey: name.toLowerCase(), ...extra } });
      art[key] = a.id;
    }

    const routes = (await import('@/app/modules/artists/artists.routes')).default;
    const { globalErrorMiddleware } = await import('@/app/middlewares/globalError.middlewares');
    const app = express();
    app.use(express.json());
    app.use(cookieParser());
    app.use('/api/v1', routes);
    app.use(globalErrorMiddleware);
    srv = await startTestServer(app);
  });

  after(async () => {
    try {
      await db().artist.deleteMany({ where: { name: { startsWith: P } } });
      await db().user.deleteMany({ where: { email: { startsWith: emails } } });
    } finally {
      await srv?.close();
      await appPrisma?.$disconnect();
      await closeTestPrisma();
    }
  });

  describe('auth chain', () => {
    it('rejects a missing cookie (401) on both routes', async () => {
      for (const [m, p, body] of [
        ['GET', '/admin/artists', undefined],
        ['PATCH', `/admin/artists/${art.Alpha}`, { bio: 'x' }],
      ] as const) {
        assert.equal((await call(m, p, { body })).status, 401, `${m} ${p}`);
      }
    });

    it('rejects a customer token (403) on both routes and changes nothing', async () => {
      for (const [m, p, body] of [
        ['GET', '/admin/artists', undefined],
        ['PATCH', `/admin/artists/${art.Alpha}`, { bio: 'hacked' }],
      ] as const) {
        assert.equal((await call(m, p, { token: userToken, body })).status, 403, `${m} ${p}`);
      }
      const a = await db().artist.findUniqueOrThrow({ where: { id: art.Alpha } });
      assert.equal(a.bio, 'a');
    });

    it('PATCH rejects a missing or wrong CSRF header and a missing CSRF cookie (403); GET needs none', async () => {
      for (const csrfHeader of [null, 'wrong']) {
        const r = await call('PATCH', `/admin/artists/${art.Alpha}`, { token: adminToken, csrfHeader, body: { bio: 'x' } });
        assert.equal(r.status, 403);
      }
      const noCookie = await call('PATCH', `/admin/artists/${art.Alpha}`, { token: adminToken, csrfCookie: false, body: { bio: 'x' } });
      assert.equal(noCookie.status, 403);
      const get = await call('GET', '/admin/artists', { token: adminToken, csrfHeader: null, csrfCookie: false });
      assert.equal(get.status, 200);
      const a = await db().artist.findUniqueOrThrow({ where: { id: art.Alpha } });
      assert.equal(a.bio, 'a');
    });
  });

  describe('GET /admin/artists', () => {
    it('lists all artists including those without events, profile shape, sorted by name', async () => {
      const r = await admin('GET', `/admin/artists?search=${P}`);
      assert.equal(r.status, 200);
      const b = await json(r);
      assert.deepEqual(b.data.map((a) => a.name), [`${P} Alpha`, `${P} Bravo`, `${P} Charlie`]);
      assert.deepEqual(b.meta, { page: 1, limit: 10, total: 3, totalPages: 1 });
      const a = b.data[0];
      assert.equal(a.photo, 'https://example.test/a.png');
      assert.equal(a.bio, 'a');
      assert.equal(a.isVerified, true);
      assert.ok(!('isFollowing' in a));
    });

    it('filters by isVerified, searches and pages', async () => {
      const v = await json(await admin('GET', `/admin/artists?search=${P}&isVerified=true`));
      assert.deepEqual(v.data.map((a) => a.name), [`${P} Alpha`]);
      const nv = await json(await admin('GET', `/admin/artists?search=${P}&isVerified=false`));
      assert.equal(nv.meta?.total, 2);
      const s = await json(await admin('GET', `/admin/artists?search=${P.toLowerCase()}%20char`));
      assert.deepEqual(s.data.map((a) => a.name), [`${P} Charlie`]);
      const p2 = await json(await admin('GET', `/admin/artists?search=${P}&limit=2&page=2`));
      assert.deepEqual(p2.data.map((a) => a.name), [`${P} Charlie`]);
      assert.deepEqual(p2.meta, { page: 2, limit: 2, total: 3, totalPages: 2 });
    });

    it('rejects bad query values with 422', async () => {
      for (const qs of ['limit=51', 'page=0', 'isVerified=maybe']) {
        assert.equal((await admin('GET', `/admin/artists?${qs}`)).status, 422, qs);
      }
    });
  });

  describe('PATCH /admin/artists/{id}', () => {
    it('edits photo, bio, links and verifies; returns the profile', async () => {
      const r = await admin('PATCH', `/admin/artists/${art.Bravo}`, {
        photo: 'https://example.test/b.png',
        bio: 'Bravo bio',
        spotifyUrl: 'https://open.spotify.com/artist/b',
        socialLinks: { instagram: 'https://instagram.com/b', website: 'https://b.example.test' },
        isVerified: true,
      });
      assert.equal(r.status, 200);
      const b = await json(r);
      assert.equal(b.data.photo, 'https://example.test/b.png');
      assert.equal(b.data.isVerified, true);
      assert.deepEqual(b.data.socialLinks, { instagram: 'https://instagram.com/b', website: 'https://b.example.test' });
      const a = await db().artist.findUniqueOrThrow({ where: { id: art.Bravo } });
      assert.equal(a.avatar, 'https://example.test/b.png');
      assert.equal(a.isVerified, true);
    });

    it('renames and keeps nameKey in sync; a duplicate name is 409 and changes nothing', async () => {
      const r = await admin('PATCH', `/admin/artists/${art.Charlie}`, { name: `  ${P} Charlie  Renamed ` });
      assert.equal(r.status, 200);
      const a = await db().artist.findUniqueOrThrow({ where: { id: art.Charlie } });
      assert.equal(a.name, `${P} Charlie  Renamed`);
      assert.equal(a.nameKey, `${P} charlie renamed`.toLowerCase());
      const dup = await admin('PATCH', `/admin/artists/${art.Charlie}`, { name: `${P} ALPHA` });
      assert.equal(dup.status, 409);
      const again = await db().artist.findUniqueOrThrow({ where: { id: art.Charlie } });
      assert.equal(again.name, `${P} Charlie  Renamed`);
    });

    it('unknown id 404, bad id 422, invalid body 422', async () => {
      assert.equal((await admin('PATCH', `/admin/artists/${randomUUID()}`, { bio: 'x' })).status, 404);
      assert.equal((await admin('PATCH', '/admin/artists/nope', { bio: 'x' })).status, 422);
      for (const body of [{}, { socialLinks: { tiktok2: 'https://x.test' } }, { socialLinks: { x: 'javascript:alert(1)' } }, { isVerified: 'yes' }, { unknown: 1 }, { name: '' }]) {
        assert.equal((await admin('PATCH', `/admin/artists/${art.Alpha}`, body)).status, 422, JSON.stringify(body));
      }
    });
  });
});
