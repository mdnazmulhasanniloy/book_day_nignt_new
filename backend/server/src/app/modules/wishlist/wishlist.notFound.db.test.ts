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

// T-013 (B-27, CR-17): POST /wishlist for a missing, deactivated or
// non-upcoming target returns 404 (was 500: the service threw `status`, not
// `statusCode`). Real wishlist router, auth middlewares and error handler.

const run = randomUUID().replace(/-/g, '').slice(0, 12);

describe('POST /wishlist target not found (T-013)', { skip: dbTestSkipReason() }, () => {
  let appPrisma: PrismaClient;
  let srv: Awaited<ReturnType<typeof startTestServer>>;
  let token: string;
  let userId: string;
  let clubId: string;
  let eventId: string;
  const db = () => getTestPrisma();
  type Body = { success: boolean; message: string; errorType?: string; traceId?: string };

  const add = (type: 'CLUB' | 'EVENT', targetId: string) =>
    fetch(`${srv.baseUrl}/api/v1/wishlist`, {
      method: 'POST',
      headers: { 'content-type': 'application/json', authorization: `Bearer ${token}` },
      body: JSON.stringify({ type, targetId }),
    });

  before(async () => {
    process.env.DATABASE_URL = assertSafeTestDatabaseUrl(process.env.TEST_DATABASE_URL);
    installFakeRedis();
    appPrisma = (await import('@/app/configs/db.configs')).default;
    const [{ current_database: name }] = await appPrisma.$queryRaw<{ current_database: string }[]>`select current_database()`;
    assert.match(name, /_test$/, 'app prisma client must target the test DB');

    const user = await db().user.create({
      data: {
        name: 'T013 user',
        email: `t013-${run}-wish@example.test`,
        phoneNumber: `+1555${Math.floor(Math.random() * 1e7)}`,
        isVerified: true,
      },
    });
    userId = user.id;
    const { createClub, createEvent } = await import('@/testing/fixtures');
    clubId = (await createClub(db(), user.id, { name: `T013 Club ${run}` })).id;
    eventId = (await createEvent(db(), user.id, { eventName: `T013 Event ${run}` })).id;

    const jwt = await import('@/app/utils/jwt.utils');
    token = jwt.generateAccessTokenForUser({
      sub: user.id,
      role: user.accountRole,
      isVerified: true,
      accountStatus: user.accountStatus,
      rememberMe: true,
    } as never);

    const routes = (await import('@/app/modules/wishlist/wishlist.routes')).default;
    const { globalErrorMiddleware } = await import('@/app/middlewares/globalError.middlewares');
    const app = express();
    app.use(express.json());
    app.use('/api/v1', routes);
    app.use(globalErrorMiddleware);
    srv = await startTestServer(app);
  });

  after(async () => {
    try {
      await db().wishlist.deleteMany({ where: { userId } });
      await db().event.deleteMany({ where: { userId } });
      await db().club.deleteMany({ where: { userId } });
      await db().user.deleteMany({ where: { id: userId } });
    } finally {
      await srv?.close();
      await appPrisma?.$disconnect();
      await closeTestPrisma();
    }
  });

  it('missing club -> 404 with the stable message', async () => {
    const r = await add('CLUB', randomUUID());
    assert.equal(r.status, 404);
    const b = (await r.json()) as Body;
    assert.equal(b.success, false);
    assert.equal(b.message, 'Club not found or unavailable');
    assert.equal(b.errorType, 'NOT_FOUND');
    assert.ok(b.traceId);
  });

  it('missing event -> 404', async () => {
    const r = await add('EVENT', randomUUID());
    assert.equal(r.status, 404);
    const b = (await r.json()) as Body;
    assert.equal(b.message, 'Event not found or unavailable');
    assert.equal(b.errorType, 'NOT_FOUND');
  });

  it('success paths unchanged: add is idempotent (200 twice, one row)', async () => {
    assert.equal((await add('CLUB', clubId)).status, 200);
    assert.equal((await add('CLUB', clubId)).status, 200);
    assert.equal((await add('EVENT', eventId)).status, 200);
    assert.equal(await db().wishlist.count({ where: { userId } }), 2);
  });
});
