import { after, before, describe, it } from 'node:test';
import assert from 'node:assert/strict';
import express from 'express';
import type { PrismaClient } from '@prisma/client';
import {
  assertSafeTestDatabaseUrl,
  closeTestPrisma,
  dbTestSkipReason,
  getTestPrisma,
} from '@/testing/testDb';
import { installFakeRedis, startTestServer } from '@/testing/fakes';

// S-23: GET /explore/club/:id and /explore/event/:id build HTML from database values.
// Stored markup in a name/description/location/thumbnail must never execute.

const OWNER_ID = '023a0000-0000-4000-8000-000000000001';
const EVIL_CLUB_ID = '023a0000-0000-4000-8000-0000000000c1';
const EVIL_EVENT_ID = '023a0000-0000-4000-8000-0000000000e1';
const URL_CLUB_ID = '023a0000-0000-4000-8000-0000000000c2';
const URL_EVENT_ID = '023a0000-0000-4000-8000-0000000000e2';
const NORMAL_CLUB_ID = '023a0000-0000-4000-8000-0000000000c3';
const NORMAL_EVENT_ID = '023a0000-0000-4000-8000-0000000000e3';

const EVIL_NAME = `"><script>alert(1)</script><img src=x onerror=alert(1)> ' onmouseover='alert(1) </title><script>alert(1)</script> &lt;b&gt; Rock & Roll's Café`;
const EVIL_DESC = `</p><script>alert(2)</script><svg onload=alert(2)> " autofocus onfocus="alert(2)`;
const EVIL_LOC = `<script>alert(3)</script>' onmouseover='alert(3)`;
const EVIL_THUMB = `https://cdn.example.test/x.png"><script>alert(4)</script><img src="x`;

describe('explore share-preview pages escape stored values (S-23)', { skip: dbTestSkipReason() }, () => {
  let appPrisma: PrismaClient;
  let srv: Awaited<ReturnType<typeof startTestServer>>;
  const db = () => getTestPrisma();

  const get = async (path: string) => {
    const r = await fetch(`${srv.baseUrl}${path}`);
    return { status: r.status, type: r.headers.get('content-type'), body: await r.text() };
  };

  const cleanup = async () => {
    await db().event.deleteMany({ where: { userId: OWNER_ID } });
    await db().club.deleteMany({ where: { userId: OWNER_ID } });
    await db().user.deleteMany({ where: { id: OWNER_ID } });
  };

  // Only the page's own inline script (appUrl) is allowed; everything else must come from the template.
  const assertNoInjection = (html: string) => {
    assert.doesNotMatch(html, /<script>alert/i);
    assert.doesNotMatch(html, /<img src=x/i);
    assert.doesNotMatch(html, /<svg[^>]*onload/i);
    assert.doesNotMatch(html, /<\/title><script/i);
    // inside real tags (escaped text has no angle brackets) no event-handler attribute may exist
    for (const tag of html.match(/<[^>]*>/g) ?? []) assert.doesNotMatch(tag.replace(/"[^"]*"/g, '""'), /\son[a-z]+\s*=/i, tag);
    assert.equal((html.match(/<script/gi) ?? []).length, 1, 'only the template script tag may exist');
  };

  before(async () => {
    process.env.DATABASE_URL = assertSafeTestDatabaseUrl(process.env.TEST_DATABASE_URL);
    installFakeRedis();
    appPrisma = (await import('@/app/configs/db.configs')).default;
    await cleanup();
    await db().user.create({
      data: { id: OWNER_ID, name: 'S23 owner', email: 's23-owner@example.test', phoneNumber: '+15550230001', isVerified: true },
    });
    const { createClub, createEvent } = await import('@/testing/fixtures');
    const base = { startAt: new Date('2030-01-10T20:00:00.000Z'), endAt: new Date('2030-01-11T02:00:00.000Z') };
    await createClub(db(), OWNER_ID, { id: EVIL_CLUB_ID, name: EVIL_NAME, description: EVIL_DESC, location: EVIL_LOC, thumbnail: EVIL_THUMB });
    await createEvent(db(), OWNER_ID, { id: EVIL_EVENT_ID, eventName: EVIL_NAME, eventDescription: EVIL_DESC, location: EVIL_LOC, thumbnail: EVIL_THUMB, ...base });
    await createClub(db(), OWNER_ID, { id: URL_CLUB_ID, name: 'Url club', thumbnail: 'javascript:alert(1)' });
    await createEvent(db(), OWNER_ID, { id: URL_EVENT_ID, eventName: 'Url event', thumbnail: 'javascript:alert(1)', ...base });
    await createClub(db(), OWNER_ID, { id: NORMAL_CLUB_ID, name: 'Café Noir & Co', description: "Where it's at", location: '12 Test Lane, Dhaka' });
    await createEvent(db(), OWNER_ID, { id: NORMAL_EVENT_ID, eventName: 'Rock & Roll Night', location: '12 Test Lane, Dhaka', ...base });

    const { getClubSharePreviewController, getEventSharePreviewController } = await import(
      '@/app/modules/explore/explore.controllers'
    );
    const { globalErrorMiddleware } = await import('@/app/middlewares/globalError.middlewares');
    const app = express();
    app.get('/explore/club/:id', getClubSharePreviewController);
    app.get('/explore/event/:id', getEventSharePreviewController);
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

  for (const [label, path] of [
    ['club', `/explore/club/${EVIL_CLUB_ID}`],
    ['event', `/explore/event/${EVIL_EVENT_ID}`],
  ] as const) {
    it(`${label}: markup in name, description, location and thumbnail is escaped`, async () => {
      const { status, type, body } = await get(path);
      assert.equal(status, 200);
      assert.match(type ?? '', /text\/html/);
      assertNoInjection(body);
      assert.ok(body.includes('&lt;script&gt;alert(1)&lt;/script&gt;'), 'escaped name text is present');
      assert.ok(body.includes('&amp;lt;b&amp;gt;'), 'pre-escaped text is shown literally');
      assert.ok(body.includes('Rock &amp; Roll&#39;s Café'), 'ampersand, apostrophe and accents');
      // the quote that would close content="..." must be escaped in every meta tag
      for (const m of body.matchAll(/<meta [^>]*>/g)) {
        assert.match(m[0], /^<meta (?:[a-z:-]+=(?:"[^"]*"|\S+) ?)+\/?>$/i, m[0]);
      }
      // thumbnail with an attribute break-out is a valid http(s) URL string but its quote and angle brackets must be escaped
      assert.doesNotMatch(body, /x\.png"><script/i);
    });
  }

  it('club: a javascript: thumbnail is not used in og:image, twitter:image or img src', async () => {
    const { body } = await get(`/explore/club/${URL_CLUB_ID}`);
    assert.doesNotMatch(body, /javascript:/i);
    assert.match(body, /<meta property="og:image" content="" \/>/);
  });

  it('event: a javascript: thumbnail is not used in og:image, twitter:image or img src', async () => {
    const { body } = await get(`/explore/event/${URL_EVENT_ID}`);
    assert.doesNotMatch(body, /javascript:/i);
    assert.match(body, /<meta name="twitter:image" content="" \/>/);
  });

  it('normal names are rendered unchanged apart from escaped & and apostrophe', async () => {
    const club = await get(`/explore/club/${NORMAL_CLUB_ID}`);
    assert.ok(club.body.includes('<title>Café Noir &amp; Co | BookDiaNight</title>'));
    assert.ok(club.body.includes('<h1>Café Noir &amp; Co</h1>'));
    assert.ok(club.body.includes('<p class="desc">Where it&#39;s at</p>'));
    assert.ok(club.body.includes('<span>12 Test Lane, Dhaka</span>'));
    assert.ok(club.body.includes('<img src="https://example.test/t.png" alt="Café Noir &amp; Co" />'));
    assert.ok(club.body.includes(`var appUrl = "bookdianight://club/${NORMAL_CLUB_ID}";`));
    assert.ok(club.body.includes(`<a class="btn btn-primary" href="bookdianight://club/${NORMAL_CLUB_ID}">`));
    const ev = await get(`/explore/event/${NORMAL_EVENT_ID}`);
    assert.ok(ev.body.includes('<title>Rock &amp; Roll Night | BookDiaNight</title>'));
    assert.ok(ev.body.includes('<h1>Rock &amp; Roll Night</h1>'));
  });

  it('unknown id still returns the 404 page', async () => {
    const r = await get('/explore/club/023a0000-0000-4000-8000-0000000000ff');
    assert.equal(r.status, 404);
    assert.ok(r.body.includes('404 - Club Not Found'));
  });
});
