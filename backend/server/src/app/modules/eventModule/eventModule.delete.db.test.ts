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

// T-013 (B-26, CR-17): DELETE /event/:eventId/modules/:id for a module that
// has purchases returns 409 (EventModulePurchase.module is onDelete: Restrict)
// and the module still exists. Real router, real auth middlewares, real global
// error handler.

const run = randomUUID().replace(/-/g, '').slice(0, 12);

describe('DELETE /event/:eventId/modules/:id (T-013)', { skip: dbTestSkipReason() }, () => {
  let appPrisma: PrismaClient;
  let srv: Awaited<ReturnType<typeof startTestServer>>;
  let ownerToken: string;
  let eventId: string;
  let ownerId: string;
  const db = () => getTestPrisma();
  type Body = { success: boolean; message: string; errorType?: string; traceId?: string };

  const del = (evId: string, moduleId: string) =>
    fetch(`${srv.baseUrl}/api/v1/event/${evId}/modules/${moduleId}`, {
      method: 'DELETE',
      headers: { authorization: `Bearer ${ownerToken}` },
    });

  const mkModule = (name: string) =>
    db().eventModule.create({
      data: {
        eventId,
        name,
        maxGuests: 4,
        startingPrice: 100,
        currency: 'USD',
        quantity: 5,
        remaining: 5,
      },
    });

  before(async () => {
    process.env.DATABASE_URL = assertSafeTestDatabaseUrl(process.env.TEST_DATABASE_URL);
    installFakeRedis();
    appPrisma = (await import('@/app/configs/db.configs')).default;
    const [{ current_database: name }] = await appPrisma.$queryRaw<{ current_database: string }[]>`select current_database()`;
    assert.match(name, /_test$/, 'app prisma client must target the test DB');

    const owner = await db().user.create({
      data: {
        name: 'T013 owner',
        email: `t013-${run}-owner@example.test`,
        phoneNumber: `+1555${Math.floor(Math.random() * 1e7)}`,
        accountRole: 'CLUB_OWNER',
        isVerified: true,
      },
    });
    ownerId = owner.id;
    const { createEvent } = await import('@/testing/fixtures');
    eventId = (await createEvent(db(), owner.id, { eventName: `T013 ${run}` })).id;

    const jwt = await import('@/app/utils/jwt.utils');
    ownerToken = jwt.generateAccessTokenForUser({
      sub: owner.id,
      role: owner.accountRole,
      isVerified: true,
      accountStatus: owner.accountStatus,
      rememberMe: true,
    } as never);

    const routes = (await import('@/app/modules/eventModule/eventModule.routes')).default;
    const { globalErrorMiddleware } = await import('@/app/middlewares/globalError.middlewares');
    const app = express();
    app.use(express.json());
    app.use('/api/v1', routes);
    app.use(globalErrorMiddleware);
    srv = await startTestServer(app);
  });

  after(async () => {
    try {
      const orders = await db().order.findMany({ where: { buyerUserId: ownerId }, select: { id: true } });
      const orderIds = orders.map((o) => o.id);
      // Deferred purchase triggers: delete purchase and order in one transaction.
      await db().$transaction([
        db().eventModulePurchase.deleteMany({ where: { eventId } }),
        db().order.deleteMany({ where: { id: { in: orderIds } } }),
      ]);
      await db().event.deleteMany({ where: { userId: ownerId } });
      await db().user.deleteMany({ where: { id: ownerId } });
    } finally {
      await srv?.close();
      await appPrisma?.$disconnect();
      await closeTestPrisma();
    }
  });

  it('module with a purchase -> 409 FOREIGN_KEY_CONFLICT and the module still exists', async () => {
    const mod = await mkModule('With purchase');
    await db().$transaction(async (tx) => {
      const { createOrder } = await import('@/testing/fixtures');
      const order = await createOrder(tx, ownerId, ownerId, { serviceType: 'EVENT' });
      await tx.eventModulePurchase.create({
        data: {
          orderId: order.id,
          eventId,
          moduleId: mod.id,
          quantity: 1,
          guestCount: 2,
          holdExpiresAt: new Date(Date.now() + 900_000),
          moduleName: mod.name,
          unitPrice: 100,
        },
      });
    });

    const r = await del(eventId, mod.id);
    assert.equal(r.status, 409);
    const b = (await r.json()) as Body;
    assert.equal(b.success, false);
    assert.equal(b.errorType, 'FOREIGN_KEY_CONFLICT');
    assert.match(b.message, /purchases/i);
    assert.ok(b.traceId);
    assert.ok(await db().eventModule.findUnique({ where: { id: mod.id } }), 'module must still exist');
  });

  it('success path unchanged: module without purchases -> 200 and is deleted', async () => {
    const mod = await mkModule('No purchase');
    const r = await del(eventId, mod.id);
    assert.equal(r.status, 200);
    assert.equal(await db().eventModule.findUnique({ where: { id: mod.id } }), null);
  });

  it('missing module -> 404 unchanged', async () => {
    const r = await del(eventId, randomUUID());
    assert.equal(r.status, 404);
    assert.equal(((await r.json()) as Body).message, 'Module not found');
  });
});
