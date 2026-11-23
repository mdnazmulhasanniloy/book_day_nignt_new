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

// T-030 (CR-09, BUG-B02, BUG-B25): Club.geog must follow lat/lng on create and update through
// the real routes. Connect readiness is a pass-through and nearby-user helpers are faked.

const run = randomUUID().replace(/-/g, '').slice(0, 12);
type Point = { lat: number; lng: number } | null;

describe('Club.geog stays in step with lat/lng (T-030)', { skip: dbTestSkipReason() }, () => {
  let appPrisma: PrismaClient;
  let srv: Awaited<ReturnType<typeof startTestServer>>;
  let ownerId: string;
  let ownerToken: string;
  const db = () => getTestPrisma();

  const send = (method: 'POST' | 'PUT', path: string, body: unknown) =>
    fetch(`${srv.baseUrl}/api/v1${path}`, {
      method,
      headers: { 'content-type': 'application/json', authorization: `Bearer ${ownerToken}` },
      body: JSON.stringify(body),
    });

  const clubBody = (extra: Record<string, unknown> = {}) => ({
    name: `T030 Club ${run}`,
    thumbnail: 'https://example.test/t.png',
    images: [],
    dressCode: 'casual',
    isRecurring: false,
    lat: -45.5,
    lng: 170.25,
    location: 'Remote',
    openingHours: [0, 1, 2, 3, 4, 5, 6].map((dayOfWeek) => ({
      dayOfWeek,
      isClosed: true,
      closesNextDay: false,
    })),
    packages: [],
    ...extra,
  });
  const create = async (extra: Record<string, unknown> = {}) => {
    const r = await send('POST', '/club', clubBody(extra));
    const json = (await r.json()) as { data: { id: string } };
    return { status: r.status, id: json.data?.id };
  };
  const geogOf = async (id: string): Promise<Point> => {
    const rows = await db().$queryRaw<{ lat: number | null; lng: number | null }[]>`
      SELECT ST_Y(geog::geometry) AS lat, ST_X(geog::geometry) AS lng FROM "Club" WHERE id = ${id}`;
    const row = rows[0];
    return row && row.lat !== null && row.lng !== null ? { lat: row.lat, lng: row.lng } : null;
  };
  const near = (p: Point, lat: number, lng: number) => {
    assert.ok(p, 'geog is not null');
    assert.ok(Math.abs(p.lat - lat) < 1e-9, `geog lat ${p.lat} vs ${lat}`);
    assert.ok(Math.abs(p.lng - lng) < 1e-9, `geog lng ${p.lng} vs ${lng}`);
  };

  before(async () => {
    process.env.DATABASE_URL = assertSafeTestDatabaseUrl(process.env.TEST_DATABASE_URL);
    installFakeRedis();
    appPrisma = (await import('@/app/configs/db.configs')).default;

    const swap = (id: string, exports: unknown) => {
      const p = require.resolve(id);
      require.cache[p] = { id: p, filename: p, loaded: true, exports } as unknown as NodeJS.Module;
    };
    swap('@/app/modules/connect/connect.middlewares', {
      checkConnectReadinessMiddleware: (_q: unknown, _r: unknown, next: () => void) => next(),
    });
    swap('@/app/modules/notification/notification.helpers', {
      getUsersNearby: async () => [],
      sendPushNotification: async () => undefined,
    });

    const owner = await db().user.create({
      data: {
        name: 'T030 club owner',
        email: `t030c-${run}-owner@example.test`,
        phoneNumber: `+1555${Math.floor(Math.random() * 1e7)}`,
        accountRole: 'CLUB_OWNER',
        isVerified: true,
      },
    });
    ownerId = owner.id;
    const jwt = await import('@/app/utils/jwt.utils');
    ownerToken = jwt.generateAccessTokenForUser({
      sub: owner.id,
      role: owner.accountRole,
      isVerified: true,
      accountStatus: owner.accountStatus,
      rememberMe: true,
    } as never);

    const routes = (await import('@/app/modules/club/club.routes')).default;
    const { globalErrorMiddleware } = await import('@/app/middlewares/globalError.middlewares');
    const app = express();
    app.use(express.json());
    app.use('/api/v1', routes);
    app.use(globalErrorMiddleware);
    srv = await startTestServer(app);
  });

  after(async () => {
    try {
      await db().club.deleteMany({ where: { userId: ownerId } });
      await db().user.deleteMany({ where: { id: ownerId } });
    } finally {
      await srv?.close();
      await appPrisma?.$disconnect();
      await closeTestPrisma();
    }
  });

  it('create sets geog from lat/lng', async () => {
    const c = await create();
    assert.equal(c.status, 201);
    near(await geogOf(c.id), -45.5, 170.25);
  });

  it('update with new lat and lng moves geog', async () => {
    const c = await create();
    assert.equal((await send('PUT', `/club/${c.id}`, { lat: -44.1, lng: 169.5 })).status, 200);
    near(await geogOf(c.id), -44.1, 169.5);
  });

  it('update with only lat or only lng recomputes geog from the stored pair', async () => {
    const c = await create();
    assert.equal((await send('PUT', `/club/${c.id}`, { lat: -40 })).status, 200);
    near(await geogOf(c.id), -40, 170.25);
    assert.equal((await send('PUT', `/club/${c.id}`, { lng: 171 })).status, 200);
    near(await geogOf(c.id), -40, 171);
  });

  it('update that does not touch lat/lng leaves geog as it is', async () => {
    const c = await create();
    await db().$executeRaw`UPDATE "Club" SET geog = ST_SetSRID(ST_MakePoint(10, 20), 4326)::geography WHERE id = ${c.id}`;
    assert.equal((await send('PUT', `/club/${c.id}`, { name: `T030 renamed ${run}` })).status, 200);
    near(await geogOf(c.id), 20, 10);
  });

  it('invalid coordinates are rejected (422) and geog stays as it was', async () => {
    const c = await create();
    for (const body of [{ lat: 91, lng: 0 }, { lat: 0, lng: -181 }]) {
      assert.equal((await send('PUT', `/club/${c.id}`, body)).status, 422);
    }
    assert.equal((await send('POST', '/club', clubBody({ lng: 200 }))).status, 422);
    near(await geogOf(c.id), -45.5, 170.25);
  });

  it('no club of this run has lat set and geog NULL', async () => {
    const rows = await db().$queryRaw<{ n: bigint }[]>`
      SELECT COUNT(*) AS n FROM "Club" WHERE "userId" = ${ownerId} AND geog IS NULL AND lat IS NOT NULL`;
    assert.equal(Number(rows[0].n), 0);
  });
});
