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

// T-009: POST /auth/social service, DB-backed, provider verification stubbed.
// The service uses the app prisma client (DATABASE_URL), so point it at the
// test database BEFORE the service module is loaded (dynamic import below).
// Tests here COMMIT data (parallel calls cannot share one rollback tx), so
// every row is created with a per-run unique prefix and deleted in after().

const run = randomUUID().replace(/-/g, '').slice(0, 12);
const subOf = (n: string) => `t009${run}${n}`;
const emailOf = (n: string) => `t009-${run}-${n}@example.test`;

type OAuthPayload = Parameters<
  typeof import('@/app/modules/auth/auth.services').oAuthLoginService
>[0]['payload'];

const payloadFor = (
  n: string,
  extra: Partial<OAuthPayload> = {}
): OAuthPayload => ({
  idToken: 'stub-token-that-is-long-enough',
  provider: 'GOOGLE',
  deviceIdentifier: `t009-${run}-device-${n}`,
  platform: 'ANDROID',
  lat: 1,
  lng: 2,
  ...extra,
});

// Stub for verifyOAuthIdToken: the "token" is irrelevant, subject comes from the test.
const stubFor =
  (n: string, withEmail = true) =>
  async () => ({
    sub: subOf(n),
    email: withEmail ? emailOf(n) : null,
    name: 'Social Tester',
  });

const dobYearsAgo = (years: number) => {
  const d = new Date();
  d.setUTCFullYear(d.getUTCFullYear() - years);
  d.setUTCHours(0, 0, 0, 0);
  return d.toISOString();
};

describe('oAuthLoginService (social sign-in)', { skip: dbTestSkipReason() }, () => {
  let service: typeof import('@/app/modules/auth/auth.services').oAuthLoginService;
  let appPrisma: PrismaClient;
  let srv: Awaited<ReturnType<typeof startTestServer>>;
  const db = () => getTestPrisma();

  const countFor = async (n: string) => ({
    users: await db().user.count({
      where: { OR: [{ email: emailOf(n) }, { email: { contains: subOf(n) } }] },
    }),
    identities: await db().oAuthIdentity.count({
      where: { providerUserId: subOf(n) },
    }),
  });

  before(async () => {
    process.env.DATABASE_URL = assertSafeTestDatabaseUrl(
      process.env.TEST_DATABASE_URL
    );
    const fake = installFakeRedis() as unknown as Record<string, unknown>;
    const client = (await import('@/app/configs/redis.configs')).getRedisClient();
    (client as unknown as Record<string, unknown>).geoadd = async () => 1;
    void fake;
    appPrisma = (await import('@/app/configs/db.configs')).default;
    const [{ current_database: name }] = await appPrisma.$queryRaw<
      { current_database: string }[]
    >`select current_database()`;
    assert.match(name, /_test$/, 'app prisma client must target the test DB');
    service = (await import('@/app/modules/auth/auth.services')).oAuthLoginService;

    const { validateReqBody } = await import('@/app/utils/system.utils');
    const { oAuthLoginSchema } = await import('@/app/modules/auth/auth.schema');
    const app = express();
    app.use(express.json());
    app.post('/auth/social', validateReqBody(oAuthLoginSchema), async (req, res) => {
      try {
        const data = await service({
          payload: req.body,
          verifyIdentity: stubFor(String(req.headers['x-case'])),
        });
        res.json({ success: true, data });
      } catch (e) {
        const err = e as { statusCode?: number };
        res.status(err.statusCode ?? 500).json({ success: false });
      }
    });
    srv = await startTestServer(app);
  });

  after(async () => {
    try {
      const ids = await db().oAuthIdentity.findMany({
        where: { providerUserId: { startsWith: `t009${run}` } },
        select: { userId: true },
      });
      const users = await db().user.findMany({
        where: {
          OR: [
            { id: { in: ids.map((i) => i.userId) } },
            { email: { startsWith: `t009-${run}-` } },
            { email: { contains: `t009${run}` } },
          ],
        },
        select: { id: true },
      });
      // Cascades remove profile, identity and device rows.
      await db().user.deleteMany({ where: { id: { in: users.map((u) => u.id) } } });
      await db().device.deleteMany({
        where: { deviceIdentifier: { startsWith: `t009-${run}-` } },
      });
    } finally {
      await srv?.close();
      await appPrisma?.$disconnect();
      await closeTestPrisma();
    }
  });

  it('new social user without DOB: profileComplete false, existing fields kept', async () => {
    const data = await service({
      payload: payloadFor('nodob'),
      verifyIdentity: stubFor('nodob'),
    });
    assert.equal(data.profileComplete, false);
    // Snapshot of the pre-change response keys, plus the new field.
    assert.deepEqual(Object.keys(data).sort(), [
      'isUserVerified',
      'profileComplete',
      'refreshToken',
      'role',
      'token',
    ]);
    assert.equal(data.role, 'USER');
    assert.equal(data.isUserVerified, true);
    assert.equal(typeof data.token, 'string');
    assert.equal(typeof data.refreshToken, 'string');
    assert.deepEqual(await countFor('nodob'), { users: 1, identities: 1 });
  });

  it('new social user with valid DOB: profileComplete true and DOB stored', async () => {
    const dob = dobYearsAgo(25);
    const data = await service({
      payload: payloadFor('dob', { dateOfBirth: dob }),
      verifyIdentity: stubFor('dob'),
    });
    assert.equal(data.profileComplete, true);
    const profile = await db().profile.findFirst({
      where: { user: { email: emailOf('dob') } },
    });
    assert.equal(profile?.dateOfBirth?.toISOString(), dob);
  });

  it('existing user without DOB gets it set once; an existing DOB is never overwritten', async () => {
    const first = await service({
      payload: payloadFor('late'),
      verifyIdentity: stubFor('late'),
    });
    assert.equal(first.profileComplete, false);
    const dob = dobYearsAgo(30);
    const second = await service({
      payload: payloadFor('late', { dateOfBirth: dob }),
      verifyIdentity: stubFor('late'),
    });
    assert.equal(second.profileComplete, true);
    const third = await service({
      payload: payloadFor('late', { dateOfBirth: dobYearsAgo(40) }),
      verifyIdentity: stubFor('late'),
    });
    assert.equal(third.profileComplete, true);
    const profile = await db().profile.findFirst({
      where: { user: { email: emailOf('late') } },
    });
    assert.equal(profile?.dateOfBirth?.toISOString(), dob);
    assert.deepEqual(await countFor('late'), { users: 1, identities: 1 });
  });

  for (const [label, n, value] of [
    ['under-age', 'minor', () => dobYearsAgo(5)],
    ['future', 'future', () => dobYearsAgo(-1)],
    ['not ISO', 'badfmt', () => '2000-01-01'],
    ['impossible date', 'baddate', () => '2001-02-30T00:00:00.000Z'],
  ] as const) {
    it(`${label} DOB -> 422 and no user/identity created (service and HTTP)`, async () => {
      await assert.rejects(
        service({
          payload: payloadFor(n, { dateOfBirth: value() }),
          verifyIdentity: stubFor(n),
        }),
        (e: { statusCode?: number }) => e.statusCode === 422
      );
      const res = await fetch(`${srv.baseUrl}/auth/social`, {
        method: 'POST',
        headers: { 'content-type': 'application/json', 'x-case': n },
        body: JSON.stringify(payloadFor(n, { dateOfBirth: value() })),
      });
      assert.equal(res.status, 422);
      assert.deepEqual(await countFor(n), { users: 0, identities: 0 });
    });
  }

  it('HTTP: valid DOB through the route returns 200 with profileComplete true', async () => {
    const res = await fetch(`${srv.baseUrl}/auth/social`, {
      method: 'POST',
      headers: { 'content-type': 'application/json', 'x-case': 'http' },
      body: JSON.stringify(payloadFor('http', { dateOfBirth: dobYearsAgo(22) })),
    });
    assert.equal(res.status, 200);
    const body = (await res.json()) as { data: { profileComplete: boolean } };
    assert.equal(body.data.profileComplete, true);
  });

  for (const withEmail of [true, false]) {
    it(`5 parallel identical calls create exactly one user (${withEmail ? 'with' : 'without'} provider email)`, async () => {
      const n = withEmail ? 'par1' : 'par2';
      const results = await Promise.allSettled(
        Array.from({ length: 5 }, () =>
          service({
            payload: payloadFor(n, { dateOfBirth: dobYearsAgo(21) }),
            verifyIdentity: stubFor(n, withEmail),
          })
        )
      );
      const failed = results.filter((r) => r.status === 'rejected');
      assert.equal(
        failed.length,
        0,
        `rejected: ${JSON.stringify(failed.map((f) => (f as PromiseRejectedResult).reason?.code ?? (f as PromiseRejectedResult).reason?.message))}`
      );
      assert.deepEqual(await countFor(n), { users: 1, identities: 1 });
      const profiles = await db().profile.count({
        where: { user: { oauthIdentities: { some: { providerUserId: subOf(n) } } } },
      });
      assert.equal(profiles, 1);
    });
  }
});
