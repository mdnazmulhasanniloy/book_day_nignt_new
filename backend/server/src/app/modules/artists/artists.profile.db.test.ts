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

// T-044 (CR-12): GET /artists, GET /artists/{id}, PATCH /artists/{id} (owner) through the real
// artists router and middlewares, plus a snapshot of the EXISTING follow routes (written before
// the change and kept as the regression guard). Fake Redis, per-run name prefix, cleaned in after().

const run = randomUUID().replace(/-/g, '').slice(0, 8).toUpperCase();
const P = `T44${run}`;
const DAY = 86_400_000;

interface ArtistDto {
  [key: string]: unknown;
  id: string;
  name: string;
  isFollowing?: boolean;
  upcomingEvents: { id: string; [key: string]: unknown }[];
}
type Body = {
  success: boolean;
  message: string;
  errorType?: string;
  data: ArtistDto & ArtistDto[];
  meta?: { page: number; limit: number; total: number; totalPages: number };
};

describe('artists list, profile, owner edit, follow snapshot (T-044)', { skip: dbTestSkipReason() }, () => {
  let appPrisma: PrismaClient;
  let srv: Awaited<ReturnType<typeof startTestServer>>;
  const db = () => getTestPrisma();
  const emails = `t044-${run}-`;
  const tok: Record<string, string> = {};
  const ids: Record<string, string> = {};
  const art: Record<string, string> = {};
  const ev: Record<string, string> = {};

  const call = (method: string, path: string, opts: { token?: string; body?: unknown } = {}) =>
    fetch(`${srv.baseUrl}/api/v1${path}`, {
      method,
      headers: {
        'content-type': 'application/json',
        ...(opts.token ? { authorization: `Bearer ${opts.token}` } : {}),
      },
      ...(opts.body !== undefined ? { body: JSON.stringify(opts.body) } : {}),
    });
  const json = async (r: Response) => (await r.json()) as Body;

  before(async () => {
    process.env.DATABASE_URL = assertSafeTestDatabaseUrl(process.env.TEST_DATABASE_URL);
    installFakeRedis();
    appPrisma = (await import('@/app/configs/db.configs')).default;
    const jwt = await import('@/app/utils/jwt.utils');
    const mkUser = async (tag: string, role: 'CLUB_OWNER' | 'USER') => {
      const u = await db().user.create({
        data: {
          name: `T044 ${tag}`,
          email: `${emails}${tag}@example.test`,
          phoneNumber: `+1555${Math.floor(Math.random() * 1e7)}`,
          accountRole: role,
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
    };
    await mkUser('ownerA', 'CLUB_OWNER');
    await mkUser('ownerB', 'CLUB_OWNER');
    await mkUser('custC', 'USER');
    await mkUser('custD', 'USER');

    const mkArtist = async (key: string, extra: Record<string, unknown> = {}) => {
      const name = `${P} ${key}`;
      const a = await db().artist.create({
        data: { name, nameKey: name.toLowerCase(), ...extra },
      });
      art[key] = a.id;
    };
    await mkArtist('Alpha', {
      avatar: 'https://example.test/alpha.png',
      spotifyUrl: 'https://open.spotify.com/artist/alpha',
      bio: 'Alpha bio',
      socialLinks: { instagram: 'https://instagram.com/alpha' },
      isVerified: true,
      followerCount: 1,
    });
    await mkArtist('Bravo');
    await mkArtist('Charlie');
    await mkArtist('Delta');

    const mkEvent = async (
      key: string,
      owner: string,
      artists: string[],
      extra: Record<string, unknown> = {}
    ) => {
      const e = await db().event.create({
        data: {
          userId: ids[owner],
          eventName: `${P} ${key}`,
          thumbnail: 'https://example.test/t.png',
          lat: 23.78,
          lng: 90.4,
          startAt: new Date(Date.now() + DAY),
          endAt: new Date(Date.now() + 2 * DAY),
          dressCode: 'casual',
          eventPrice: 12,
          currency: 'USD',
          ...extra,
        },
      });
      ev[key] = e.id;
      for (const [i, a] of artists.entries()) {
        await db().eventLineup.create({
          data: { eventId: e.id, artistId: art[a], artistName: a, sortOrder: i },
        });
      }
    };
    // Alpha: two upcoming events (owner A); Bravo: one upcoming event (owner B);
    // Charlie: only a deactivated event and a canceled one (owner A); Delta: no events.
    await mkEvent('E1', 'ownerA', ['Alpha']);
    await mkEvent('E2', 'ownerA', ['Alpha', 'Bravo'], { startAt: new Date(Date.now() + 3 * DAY), endAt: new Date(Date.now() + 4 * DAY) });
    await mkEvent('E3', 'ownerA', ['Charlie'], { deactivatedAt: new Date() });
    await mkEvent('E4', 'ownerA', ['Charlie'], { eventStatus: 'CANCELED' });
    await mkEvent('E5', 'ownerA', ['Charlie'], { startAt: new Date(Date.now() - 3 * DAY), endAt: new Date(Date.now() - 2 * DAY), eventStatus: 'COMPLETED' });

    // custC follows Alpha (followerCount 1 above); custD does not.
    await db().artistFollower.create({ data: { userId: ids.custC, artistId: art.Alpha } });

    const routes = (await import('@/app/modules/artists/artists.routes')).default;
    const { globalErrorMiddleware } = await import('@/app/middlewares/globalError.middlewares');
    const app = express();
    app.use(express.json());
    app.use('/api/v1', routes);
    app.use(globalErrorMiddleware);
    srv = await startTestServer(app);
  });

  after(async () => {
    try {
      await db().artist.deleteMany({ where: { name: { startsWith: P } } });
      await db().event.deleteMany({ where: { eventName: { startsWith: P } } });
      await db().user.deleteMany({ where: { email: { startsWith: emails } } });
    } finally {
      await srv?.close();
      await appPrisma?.$disconnect();
      await closeTestPrisma();
    }
  });

  describe('existing follow routes (snapshot, unchanged)', () => {
    it('POST follow: 200 {isFollowing:true}, count +1 once, idempotent', async () => {
      const r = await call('POST', `/artists/${art.Bravo}/follow`, { token: tok.custD });
      assert.equal(r.status, 200);
      const b = await json(r);
      assert.equal(b.message, 'Artist followed successfully');
      assert.deepEqual(b.data, { isFollowing: true });
      const again = await call('POST', `/artists/${art.Bravo}/follow`, { token: tok.custD });
      assert.equal(again.status, 200);
      const a = await db().artist.findUniqueOrThrow({ where: { id: art.Bravo } });
      assert.equal(a.followerCount, 1);
    });

    it('GET /me/artists: only the caller follows, legacy item shape', async () => {
      const r = await call('GET', '/me/artists', { token: tok.custD });
      assert.equal(r.status, 200);
      const b = await json(r);
      assert.equal(b.message, 'Followed artists retrieved successfully');
      assert.deepEqual(b.data.map((a: { id: string }) => a.id), [art.Bravo]);
      assert.deepEqual(Object.keys(b.data[0]).sort(), [
        'audioPreviewUrl', 'avatar', 'followerCount', 'id', 'isVerified', 'name', 'soundcloudUrl', 'spotifyUrl',
      ]);
      assert.deepEqual(b.meta, { page: 1, limit: 20, total: 1, totalPages: 1 });
      // another user's follow is never returned
      const c = await json(await call('GET', '/me/artists', { token: tok.custC }));
      assert.deepEqual(c.data.map((a: { id: string }) => a.id), [art.Alpha]);
    });

    it('DELETE follow: 200 {isFollowing:false}, count back to 0, unknown artist is a no-op 200', async () => {
      const r = await call('DELETE', `/artists/${art.Bravo}/follow`, { token: tok.custD });
      assert.equal(r.status, 200);
      const b = await json(r);
      assert.equal(b.message, 'Artist unfollowed successfully');
      assert.deepEqual(b.data, { isFollowing: false });
      const a = await db().artist.findUniqueOrThrow({ where: { id: art.Bravo } });
      assert.equal(a.followerCount, 0);
    });

    it('follow: unknown artist 404, no token 401, bad id 422', async () => {
      assert.equal((await call('POST', `/artists/${randomUUID()}/follow`, { token: tok.custD })).status, 404);
      assert.equal((await call('POST', `/artists/${art.Bravo}/follow`)).status, 401);
      assert.equal((await call('POST', '/artists/not-a-uuid/follow', { token: tok.custD })).status, 422);
    });
  });

  describe('GET /artists', () => {
    it('lists only artists with an upcoming event, sorted by upcoming event count then name, profile shape', async () => {
      const r = await call('GET', `/artists?search=${P}`);
      assert.equal(r.status, 200);
      const b = await json(r);
      assert.equal(b.success, true);
      assert.deepEqual(b.data.map((a: { name: string }) => a.name), [`${P} Alpha`, `${P} Bravo`]);
      assert.deepEqual(b.meta, { page: 1, limit: 10, total: 2, totalPages: 1 });
      const alpha = b.data[0];
      assert.equal(alpha.id, art.Alpha);
      assert.equal(alpha.photo, 'https://example.test/alpha.png');
      assert.equal(alpha.bio, 'Alpha bio');
      assert.deepEqual(alpha.socialLinks, { instagram: 'https://instagram.com/alpha' });
      assert.equal(alpha.spotifyUrl, 'https://open.spotify.com/artist/alpha');
      assert.equal(alpha.isVerified, true);
      assert.equal(alpha.followerCount, 1);
      assert.equal(alpha.upcomingEventCount, 2);
      assert.equal(b.data[1].photo, null);
      assert.equal(b.data[1].bio, null);
      assert.equal(b.data[1].socialLinks, null);
    });

    it('isFollowing only with a token, and only for the token user', async () => {
      const anon = await json(await call('GET', `/artists?search=${P}`));
      for (const a of anon.data) assert.ok(!('isFollowing' in a), 'no isFollowing without a token');
      const c = await json(await call('GET', `/artists?search=${P}`, { token: tok.custC }));
      assert.deepEqual(c.data.map((a: { isFollowing: boolean }) => a.isFollowing), [true, false]);
      const d = await json(await call('GET', `/artists?search=${P}`, { token: tok.custD }));
      assert.deepEqual(d.data.map((a: { isFollowing: boolean }) => a.isFollowing), [false, false]);
    });

    it('search is case-insensitive, treats % and _ literally; paging works', async () => {
      const s = await json(await call('GET', `/artists?search=${P.toLowerCase()}%20bra`));
      assert.deepEqual(s.data.map((a: { name: string }) => a.name), [`${P} Bravo`]);
      const wild = await json(await call('GET', '/artists?search=%25'));
      assert.equal(wild.data.filter((a: { name: string }) => a.name.startsWith(P)).length, 0);
      const p2 = await json(await call('GET', `/artists?search=${P}&limit=1&page=2`));
      assert.deepEqual(p2.data.map((a: { name: string }) => a.name), [`${P} Bravo`]);
      assert.deepEqual(p2.meta, { page: 2, limit: 1, total: 2, totalPages: 2 });
    });

    it('rejects bad query values (422) and a bad token (401)', async () => {
      for (const qs of ['limit=51', 'limit=0', 'page=0', 'cityId=nope']) {
        assert.equal((await call('GET', `/artists?${qs}`)).status, 422, qs);
      }
      assert.equal((await call('GET', '/artists', { token: 'garbage' })).status, 401);
    });

    it('cityId: unknown city is 404; a far-away city hides the artists, a near one keeps them', async () => {
      assert.equal((await call('GET', `/artists?cityId=${randomUUID()}`)).status, 404);
      const far = await db().city.create({ data: { name: `${P} Far`, countryCode: 'FR', lat: 48.85, lng: 2.35, timezone: 'Europe/Paris' } });
      const near = await db().city.create({ data: { name: `${P} Near`, countryCode: 'BD', lat: 23.78, lng: 90.4, timezone: 'Asia/Dhaka' } });
      try {
        const f = await json(await call('GET', `/artists?search=${P}&cityId=${far.id}`));
        assert.equal(f.data.length, 0);
        const n = await json(await call('GET', `/artists?search=${P}&cityId=${near.id}`));
        assert.equal(n.data.length, 2);
      } finally {
        await db().city.deleteMany({ where: { id: { in: [far.id, near.id] } } });
      }
    });
  });

  describe('GET /artists/{id}', () => {
    it('returns the profile with upcoming events (explore item shape), no isFollowing without a token', async () => {
      const r = await call('GET', `/artists/${art.Alpha}`);
      assert.equal(r.status, 200);
      const b = await json(r);
      const d = b.data;
      assert.equal(d.id, art.Alpha);
      assert.equal(d.photo, 'https://example.test/alpha.png');
      assert.equal(d.bio, 'Alpha bio');
      assert.deepEqual(d.socialLinks, { instagram: 'https://instagram.com/alpha' });
      assert.equal(d.spotifyUrl, 'https://open.spotify.com/artist/alpha');
      assert.equal(d.followerCount, 1);
      assert.ok(!('isFollowing' in d));
      assert.deepEqual(d.upcomingEvents.map((e: { id: string }) => e.id), [ev.E1, ev.E2]);
      const e = d.upcomingEvents[0];
      assert.equal(e.type, 'EVENT');
      assert.equal(e.name, `${P} E1`);
      assert.equal(e.price, 12);
      assert.equal(e.currency, 'USD');
      for (const k of ['id', 'name', 'lat', 'lng', 'location', 'thumbnail', 'startAt']) assert.ok(k in e, k);
    });

    it('past, canceled and deactivated events are not upcoming; artist without events still has a profile', async () => {
      const c = await json(await call('GET', `/artists/${art.Charlie}`));
      assert.deepEqual(c.data.upcomingEvents, []);
      const dl = await call('GET', `/artists/${art.Delta}`);
      assert.equal(dl.status, 200);
    });

    it('isFollowing true/false for the token user only', async () => {
      const c = await json(await call('GET', `/artists/${art.Alpha}`, { token: tok.custC }));
      assert.equal(c.data.isFollowing, true);
      const d = await json(await call('GET', `/artists/${art.Alpha}`, { token: tok.custD }));
      assert.equal(d.data.isFollowing, false);
    });

    it('unknown id 404, bad id 422, bad token 401', async () => {
      assert.equal((await call('GET', `/artists/${randomUUID()}`)).status, 404);
      assert.equal((await call('GET', '/artists/nope')).status, 422);
      assert.equal((await call('GET', `/artists/${art.Alpha}`, { token: 'garbage' })).status, 401);
    });
  });

  describe('PATCH /artists/{id} (owner)', () => {
    const body = { bio: 'New bio', photo: 'https://example.test/new.png', spotifyUrl: 'https://open.spotify.com/artist/new', socialLinks: { instagram: 'https://instagram.com/new' } };

    it('an unrelated owner gets 404 and nothing changes (artist managed by owner A only)', async () => {
      const r = await call('PATCH', `/artists/${art.Alpha}`, { token: tok.ownerB, body });
      assert.equal(r.status, 404);
      const a = await db().artist.findUniqueOrThrow({ where: { id: art.Alpha } });
      assert.equal(a.bio, 'Alpha bio');
    });

    it('an owner whose deactivated or non-lineup events only exist cannot edit; unknown artist 404', async () => {
      assert.equal((await call('PATCH', `/artists/${art.Charlie}`, { token: tok.ownerA, body })).status, 404);
      assert.equal((await call('PATCH', `/artists/${art.Delta}`, { token: tok.ownerA, body })).status, 404);
      assert.equal((await call('PATCH', `/artists/${randomUUID()}`, { token: tok.ownerA, body })).status, 404);
    });

    it('an owner whose event lists the artist can edit; response is the profile; other fields untouched', async () => {
      const r = await call('PATCH', `/artists/${art.Alpha}`, { token: tok.ownerA, body });
      assert.equal(r.status, 200);
      const b = await json(r);
      assert.equal(b.data.bio, 'New bio');
      assert.equal(b.data.photo, 'https://example.test/new.png');
      assert.equal(b.data.spotifyUrl, 'https://open.spotify.com/artist/new');
      assert.deepEqual(b.data.socialLinks, { instagram: 'https://instagram.com/new' });
      assert.equal(b.data.name, `${P} Alpha`);
      assert.equal(b.data.isVerified, true);
      const a = await db().artist.findUniqueOrThrow({ where: { id: art.Alpha } });
      assert.equal(a.avatar, 'https://example.test/new.png');
      assert.equal(a.bio, 'New bio');
    });

    it('null clears bio, photo and socialLinks; empty bio becomes null; omitted fields are kept', async () => {
      const r = await call('PATCH', `/artists/${art.Alpha}`, { token: tok.ownerA, body: { bio: '   ', photo: null, socialLinks: null } });
      assert.equal(r.status, 200);
      const a = await db().artist.findUniqueOrThrow({ where: { id: art.Alpha } });
      assert.equal(a.bio, null);
      assert.equal(a.avatar, null);
      assert.equal(a.socialLinks, null);
      assert.equal(a.spotifyUrl, 'https://open.spotify.com/artist/new');
    });

    it('an owner cannot verify or rename (422), invalid socialLinks and URLs are 422, empty body 422', async () => {
      for (const b of [
        { isVerified: true },
        { name: 'Renamed' },
        { socialLinks: { myspace: 'https://x.test/a' } },
        { socialLinks: { instagram: 'http://insecure.test/a' } },
        { socialLinks: { instagram: 'not a url' } },
        { photo: 'ftp://x.test/a.png' },
        { spotifyUrl: 'nope' },
        { bio: 'x'.repeat(2001) },
        {},
      ]) {
        const r = await call('PATCH', `/artists/${art.Alpha}`, { token: tok.ownerA, body: b });
        assert.equal(r.status, 422, JSON.stringify(b).slice(0, 60));
      }
      const a = await db().artist.findUniqueOrThrow({ where: { id: art.Alpha } });
      assert.equal(a.isVerified, true);
      assert.equal(a.name, `${P} Alpha`);
    });

    it('no token is 401 and a customer token is 403 (role), data untouched', async () => {
      assert.equal((await call('PATCH', `/artists/${art.Alpha}`, { body })).status, 401);
      assert.equal((await call('PATCH', `/artists/${art.Alpha}`, { token: tok.custC, body })).status, 403);
    });
  });
});
