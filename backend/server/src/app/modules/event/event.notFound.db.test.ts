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

// T-012 (B-26, CR-17): GET/PUT /event/:id return 404 for a missing id and for
// another owner's id, with the same body (no ownership leak). Real event
// router, real auth middlewares, real global error handler. The Stripe
// Connect readiness middleware calls Stripe, so it is replaced by a pass-through.

const run = randomUUID().replace(/-/g, '').slice(0, 12);

describe('GET/PUT /event/:id not found (T-012)', { skip: dbTestSkipReason() }, () => {
  let appPrisma: PrismaClient;
  let srv: Awaited<ReturnType<typeof startTestServer>>;
  let ownerToken: string;
  let ownEventId: string;
  let foreignEventId: string;
  const db = () => getTestPrisma();
  type Body = { success: boolean; message: string; errorType?: string; traceId?: string };

  const call = (method: 'GET' | 'PUT', id: string, body?: unknown) =>
    fetch(`${srv.baseUrl}/api/v1/event/${id}`, {
      method,
      headers: { 'content-type': 'application/json', authorization: `Bearer ${ownerToken}` },
      ...(body ? { body: JSON.stringify(body) } : {}),
    });

  const mkUser = (tag: string) =>
    db().user.create({
      data: {
        name: `T012 ${tag}`,
        email: `t012-${run}-${tag}@example.test`,
        phoneNumber: `+1555${Math.floor(Math.random() * 1e7)}`,
        accountRole: 'CLUB_OWNER',
        isVerified: true,
      },
    });
  const mkEvent = (userId: string) =>
    db().event.create({
      data: {
        userId,
        eventName: `T012 Event ${run}`,
        thumbnail: 'https://example.test/t.png',
        lat: 23.78,
        lng: 90.4,
        startAt: new Date(Date.now() + 86_400_000),
        endAt: new Date(Date.now() + 2 * 86_400_000),
        dressCode: 'casual',
        eventPrice: 10,
        currency: 'USD',
      },
    });

  before(async () => {
    process.env.DATABASE_URL = assertSafeTestDatabaseUrl(process.env.TEST_DATABASE_URL);
    installFakeRedis();
    appPrisma = (await import('@/app/configs/db.configs')).default;
    const [{ current_database: name }] = await appPrisma.$queryRaw<{ current_database: string }[]>`select current_database()`;
    assert.match(name, /_test$/, 'app prisma client must target the test DB');

    const cmPath = require.resolve('@/app/modules/connect/connect.middlewares');
    require.cache[cmPath] = {
      id: cmPath,
      filename: cmPath,
      loaded: true,
      exports: { checkConnectReadinessMiddleware: (_q: unknown, _r: unknown, next: () => void) => next() },
    } as unknown as NodeJS.Module;

    const owner = await mkUser('owner');
    const other = await mkUser('other');
    ownEventId = (await mkEvent(owner.id)).id;
    foreignEventId = (await mkEvent(other.id)).id;

    const jwt = await import('@/app/utils/jwt.utils');
    ownerToken = jwt.generateAccessTokenForUser({
      sub: owner.id,
      role: owner.accountRole,
      isVerified: true,
      accountStatus: owner.accountStatus,
      rememberMe: true,
    } as never);

    const routes = (await import('@/app/modules/event/event.routes')).default;
    const { globalErrorMiddleware } = await import('@/app/middlewares/globalError.middlewares');
    const app = express();
    app.use(express.json());
    app.use('/api/v1', routes);
    app.use(globalErrorMiddleware);
    srv = await startTestServer(app);
  });

  after(async () => {
    try {
      const ids = (await db().user.findMany({ where: { email: { startsWith: `t012-${run}-` } }, select: { id: true } })).map((u) => u.id);
      await db().event.deleteMany({ where: { userId: { in: ids } } });
      await db().user.deleteMany({ where: { id: { in: ids } } });
    } finally {
      await srv?.close();
      await appPrisma?.$disconnect();
      await closeTestPrisma();
    }
  });

  const expectNotFound = async (r: Response) => {
    assert.equal(r.status, 404);
    const b = (await r.json()) as Body;
    assert.equal(b.success, false);
    assert.equal(b.message, 'Event not found');
    assert.equal(b.errorType, 'NOT_FOUND');
    assert.ok(b.traceId);
    return b;
  };

  it('GET missing id -> 404', async () => {
    await expectNotFound(await call('GET', randomUUID()));
  });

  it("GET another owner's event -> 404 with the same body as a missing id", async () => {
    const a = await expectNotFound(await call('GET', foreignEventId));
    const u = await expectNotFound(await call('GET', randomUUID()));
    assert.deepEqual({ ...a, traceId: 0 }, { ...u, traceId: 0 });
  });

  it('PUT missing id -> 404', async () => {
    await expectNotFound(await call('PUT', randomUUID(), { eventName: 'x' }));
  });

  it("PUT another owner's event -> 404 and the event is unchanged", async () => {
    await expectNotFound(await call('PUT', foreignEventId, { eventName: 'hijacked' }));
    const row = await db().event.findUniqueOrThrow({ where: { id: foreignEventId } });
    assert.equal(row.eventName, `T012 Event ${run}`);
  });

  it('success paths unchanged: own event GET 200 and PUT 200', async () => {
    const g = await call('GET', ownEventId);
    assert.equal(g.status, 200);
    assert.equal(((await g.json()) as { data: { id: string } }).data.id, ownEventId);
    const p = await call('PUT', ownEventId, { eventName: 'Renamed' });
    assert.equal(p.status, 200);
    assert.equal(((await p.json()) as { data: { eventName: string } }).data.eventName, 'Renamed');
  });
});
