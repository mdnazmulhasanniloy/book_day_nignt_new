import { after, before, describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import express from 'express';
import type { PrismaClient } from '@prisma/client';
import {
  assertSafeTestDatabaseUrl,
  closeTestPrisma,
  dbTestSkipReason,
  getTestPrisma,
} from '@/testing/testDb';
import { installFakeRedis, startTestServer } from '@/testing/fakes';

// T-045 (CR-13): public event page fields on GET /explore/:id?type=EVENT.
// Existing fields must stay identical (golden snapshot captured from the code before T-045),
// new fields are additive: `mapUrl` and `club`. Fixed ids keep the golden file deterministic.

const GOLDEN = join(__dirname, 'explore.eventDetail.golden.json');
const OWNER_ID = '045a0000-0000-4000-8000-000000000001';
const VIEWER_ID = '045a0000-0000-4000-8000-000000000002';
const OTHER_ID = '045a0000-0000-4000-8000-000000000003';
const OWNER_CLUB_ID = '045a0000-0000-4000-8000-0000000000c1';
const HOST_CLUB_ID = '045a0000-0000-4000-8000-0000000000c2';
const EVENT_ID = '045a0000-0000-4000-8000-0000000000e1';
const CLUBEVENT_ID = '045a0000-0000-4000-8000-0000000000e2';
const SPECIAL_ID = '045a0000-0000-4000-8000-0000000000e3';
const TIER_ID = '045a0000-0000-4000-8000-0000000000a1';
const NEW_KEYS = ['mapUrl', 'club'];

describe('explore event detail fields (T-045)', { skip: dbTestSkipReason() }, () => {
  let appPrisma: PrismaClient;
  let srv: Awaited<ReturnType<typeof startTestServer>>;
  let viewerToken: string;
  const db = () => getTestPrisma();

  const detail = async (id: string, tok?: string) => {
    const r = await fetch(`${srv.baseUrl}/api/v1/explore/${id}?type=EVENT`, {
      headers: tok ? { authorization: `Bearer ${tok}` } : {},
    });
    assert.equal(r.status, 200);
    return ((await r.json()) as { data: Record<string, unknown> }).data;
  };

  const cleanup = async () => {
    await db().event.deleteMany({ where: { userId: { in: [OWNER_ID, VIEWER_ID, OTHER_ID] } } });
    await db().club.deleteMany({ where: { userId: { in: [OWNER_ID, VIEWER_ID, OTHER_ID] } } });
    await db().user.deleteMany({ where: { id: { in: [OWNER_ID, VIEWER_ID, OTHER_ID] } } });
  };

  before(async () => {
    process.env.DATABASE_URL = assertSafeTestDatabaseUrl(process.env.TEST_DATABASE_URL);
    installFakeRedis();
    appPrisma = (await import('@/app/configs/db.configs')).default;
    await cleanup();

    const mkUser = (id: string, label: string) =>
      db().user.create({
        data: {
          id,
          name: `T045 ${label}`,
          email: `t045-${label}@example.test`,
          phoneNumber: `+1555045${label.length}${id.slice(-1)}`,
          isVerified: true,
        },
      });
    const viewer = await mkUser(OWNER_ID, 'owner').then(() => mkUser(VIEWER_ID, 'viewer'));
    await mkUser(OTHER_ID, 'other!');
    const jwt = await import('@/app/utils/jwt.utils');
    viewerToken = jwt.generateAccessTokenForUser({
      sub: viewer.id,
      role: viewer.accountRole,
      isVerified: true,
      accountStatus: viewer.accountStatus,
      rememberMe: true,
    } as never);

    const { createClub, createEvent, createTier } = await import('@/testing/fixtures');
    await createClub(db(), OWNER_ID, { id: OWNER_CLUB_ID, name: 'T045 Owner Club', location: '1 Owner Road', followerCount: 7 });
    await createClub(db(), OTHER_ID, { id: HOST_CLUB_ID, name: 'T045 Host Club', location: '9 Host Street', followerCount: 3, description: 'secret-not-exposed' });
    const base = {
      startAt: new Date('2030-01-10T20:00:00.000Z'),
      endAt: new Date('2030-01-11T02:00:00.000Z'),
      timezone: 'Europe/London',
      moodTags: ['chill', 'late'],
      musicGenres: ['house'],
      location: '12 Test Lane, Dhaka',
      lat: 23.78,
      lng: 90.4,
    };
    await createEvent(db(), OWNER_ID, { id: EVENT_ID, eventName: 'T045 Event', ...base });
    await createTier(db(), EVENT_ID, { id: TIER_ID });
    await createEvent(db(), OWNER_ID, { id: CLUBEVENT_ID, eventName: 'T045 Club Event', ...base, clubId: HOST_CLUB_ID, clubHostStatus: 'APPROVED' });
    await createEvent(db(), OWNER_ID, {
      id: SPECIAL_ID,
      eventName: `Rock & Roll "Night" <script>alert(1)</script> 100% Café 中文`,
      ...base,
      lat: -12.5,
      lng: 130.25,
    });

    const exploreRoutes = (await import('@/app/modules/explore/explore.routes')).default;
    const { globalErrorMiddleware } = await import('@/app/middlewares/globalError.middlewares');
    const app = express();
    app.use(express.json());
    app.use('/api/v1', exploreRoutes);
    app.use(globalErrorMiddleware);
    srv = await startTestServer(app);
  });

  after(async () => {
    try {
      await cleanup();
    } finally {
      await srv?.close();
      await appPrisma?.$disconnect();
      await closeTestPrisma();
    }
  });

  it('existing fields are unchanged (golden snapshot of the pre-T-045 response)', async () => {
    const body = await detail(EVENT_ID);
    const current = { ...body };
    for (const k of NEW_KEYS) delete current[k];
    delete current.createdAt;
    delete current.updatedAt;
    const normalised = JSON.parse(JSON.stringify(current));
    if (process.env.T045_WRITE_GOLDEN === '1') writeFileSync(GOLDEN, JSON.stringify(normalised, null, 2));
    const golden = JSON.parse(readFileSync(GOLDEN, 'utf8'));
    assert.deepEqual(Object.keys(normalised).sort(), Object.keys(golden).sort(), 'old key set must be identical');
    assert.deepEqual(normalised, golden, 'old values must be identical');
  });

  it('page fields: dates, timezone, address, moodTags, club identity and mapUrl are present and correct', async () => {
    const body = await detail(EVENT_ID);
    assert.equal(body.startAt, '2030-01-10T20:00:00.000Z');
    assert.equal(body.endAt, '2030-01-11T02:00:00.000Z');
    assert.equal(body.timezone, 'Europe/London');
    assert.equal(body.location, '12 Test Lane, Dhaka');
    assert.deepEqual(body.moodTags, ['chill', 'late']);
    assert.equal(body.club, null, 'no host club -> club is null');
    assert.equal(
      body.mapUrl,
      'https://www.google.com/maps/search/?api=1&query=T045%20Event%2023.78%2C90.4'
    );
    // out of scope (CR-13): nothing invented
    for (const k of ['startingPrice', 'availability', 'validDays']) assert.ok(!(k in body), `${k} must be absent`);
  });

  it('club identity is the host club with a minimal public field set', async () => {
    const body = await detail(CLUBEVENT_ID);
    assert.deepEqual(body.club, {
      id: HOST_CLUB_ID,
      name: 'T045 Host Club',
      thumbnail: 'https://example.test/t.png',
      location: '9 Host Street',
      followerCount: 3,
    });
    // the old organizer field still describes the owner club
    assert.equal((body.organizer as { id: string }).id, OWNER_CLUB_ID);
  });

  it('a deactivated host club is not exposed', async () => {
    await db().club.update({ where: { id: HOST_CLUB_ID }, data: { deactivatedAt: new Date() } });
    try {
      assert.equal((await detail(CLUBEVENT_ID)).club, null);
    } finally {
      await db().club.update({ where: { id: HOST_CLUB_ID }, data: { deactivatedAt: null } });
    }
  });

  it('mapUrl URL-encodes special characters and never carries raw markup', async () => {
    const body = await detail(SPECIAL_ID);
    const url = String(body.mapUrl);
    assert.match(url, /^https:\/\/www\.google\.com\/maps\/search\/\?api=1&query=[A-Za-z0-9%._~-]+$/);
    for (const bad of ['<', '>', '"', ' ']) assert.ok(!url.includes(bad), `url contains ${bad}`);
    assert.equal(url.split('&').length, 2, 'the name cannot add parameters');
    const q = new URL(url).searchParams.get('query');
    assert.equal(q, `${body.eventName} -12.5,130.25`);
  });

  it('isInterested is true only for the caller own interest and absent without a token', async () => {
    assert.ok(!('isInterested' in (await detail(EVENT_ID))));
    // another user is interested, the caller is not
    await db().eventInterest.create({ data: { userId: OTHER_ID, eventId: EVENT_ID } });
    try {
      const other = await detail(EVENT_ID, viewerToken);
      assert.equal(other.isInterested, false, 'someone else interest must not count for the caller');
      assert.equal(other.interestedCount, 1);
      await db().eventInterest.create({ data: { userId: VIEWER_ID, eventId: EVENT_ID } });
      const mine = await detail(EVENT_ID, viewerToken);
      assert.equal(mine.isInterested, true);
      assert.equal(mine.interestedCount, 2);
      assert.ok(!('isInterested' in (await detail(EVENT_ID))), 'anonymous never gets isInterested');
      // never any user identity in the payload
      assert.ok(!JSON.stringify(mine).includes('T045 other'));
    } finally {
      await db().eventInterest.deleteMany({ where: { eventId: EVENT_ID } });
    }
  });
});
