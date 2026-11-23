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
import { FakeQueue, installFakeRedis, startTestServer } from '@/testing/fakes';

// T-011: POST /owner/verify-ticket business failures return real status codes
// (B-15, CR-17). Real owner router, real auth middlewares, real global error
// handler. The Connect readiness check is not on this route. Redis is the
// in-memory fake and the buyer push goes to a FakeQueue (no real Redis).
// Committed rows use a per-run email prefix and are deleted in after().

const run = randomUUID().replace(/-/g, '').slice(0, 12);

describe('POST /owner/verify-ticket status codes (T-011)', { skip: dbTestSkipReason() }, () => {
  let appPrisma: PrismaClient;
  let srv: Awaited<ReturnType<typeof startTestServer>>;
  let ownerId: string;
  let otherOwnerId: string;
  let buyerId: string;
  let ownerToken: string;
  let buyerToken: string;
  let eventId: string;
  const queue = new FakeQueue();
  const db = () => getTestPrisma();

  const user = (tag: string, accountRole: 'CLUB_OWNER' | 'USER') =>
    db().user.create({
      data: {
        name: `T011 ${tag}`,
        email: `t011-${run}-${tag}@example.test`,
        phoneNumber: `+1555${Math.floor(Math.random() * 1e7)}`,
        accountRole,
        isVerified: true,
      },
    });

  const makeOrder = async (
    sellerUserId: string,
    data: { status?: 'PAID' | 'PENDING_PAYMENT'; checkedInAt?: Date; refund?: boolean } = {}
  ) => {
    // The deferred purchase trigger needs order and purchase in one transaction.
    const start = new Date(Date.now() + 86_400_000);
    const order = await db().$transaction(async (tx) => {
      const created = await tx.order.create({
        data: {
          buyerUserId: buyerId,
          sellerUserId,
          serviceType: 'EVENT',
          status: data.status ?? 'PAID',
          checkedInAt: data.checkedInAt ?? null,
          buyerName: 'T011 Buyer',
          buyerPhoneNumber: '+15550000000',
          grossAmount: 10,
          serviceChargeAmount: 1,
          buyerTotal: 11,
          commissionRate: 10,
          commissionAmount: 1,
          sellerEarnings: 9,
          currency: 'USD',
          idempotencyKey: randomUUID(),
        },
      });
      await tx.eventPurchase.create({
        data: {
          orderId: created.id,
          eventId,
          personCount: 1,
          eventName: 'T011 Event',
          eventLocation: 'Somewhere',
          eventStartAt: start,
          eventEndAt: new Date(Date.now() + 2 * 86_400_000),
          pricePerPerson: 10,
          transferEligibleAt: new Date(start.getTime() - 6 * 3_600_000),
          attendees: {
            create: [{ attendeeType: 'BUYER', position: 1, name: 'T011 Buyer', phoneNumber: '+15550000000' }],
          },
        },
      });
      if (data.refund) {
        await tx.refund.create({
          data: {
            orderId: created.id,
            idempotencyKey: randomUUID(),
            amount: 10,
            currency: 'USD',
            scheduledFor: new Date(),
          },
        });
      }
      return created;
    });
    return order;
  };

  const verify = (token: string, body: unknown) =>
    fetch(`${srv.baseUrl}/api/v1/owner/verify-ticket`, {
      method: 'POST',
      headers: { 'content-type': 'application/json', authorization: `Bearer ${token}` },
      body: JSON.stringify(body),
    });
  type Body = { success: boolean; message: string; errorType?: string; usedAt?: string; traceId?: string };

  before(async () => {
    process.env.DATABASE_URL = assertSafeTestDatabaseUrl(process.env.TEST_DATABASE_URL);
    installFakeRedis();
    appPrisma = (await import('@/app/configs/db.configs')).default;
    const [{ current_database: name }] = await appPrisma.$queryRaw<{ current_database: string }[]>`select current_database()`;
    assert.match(name, /_test$/, 'app prisma client must target the test DB');

    // The buyer push goes through bullmq; record it instead of using Redis.
    // getNotificationQueue is a non-configurable export, so swap the cached
    // module (before anything imports it) for one that returns the FakeQueue.
    const nqPath = require.resolve('@/app/queues/notification/notification.queue');
    require.cache[nqPath] = {
      id: nqPath,
      filename: nqPath,
      loaded: true,
      exports: { getNotificationQueue: () => queue },
    } as unknown as NodeJS.Module;

    const owner = await user('owner', 'CLUB_OWNER');
    const other = await user('other', 'CLUB_OWNER');
    const buyer = await user('buyer', 'USER');
    ownerId = owner.id;
    otherOwnerId = other.id;
    buyerId = buyer.id;
    const event = await db().event.create({
      data: {
        userId: ownerId,
        eventName: 'T011 Event',
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
    eventId = event.id;

    const jwt = await import('@/app/utils/jwt.utils');
    const tok = (u: { id: string; accountRole: string; accountStatus: string }) =>
      jwt.generateAccessTokenForUser({
        sub: u.id,
        role: u.accountRole,
        isVerified: true,
        accountStatus: u.accountStatus,
        rememberMe: true,
      } as never);
    ownerToken = tok(owner);
    buyerToken = tok(buyer);

    const ownerRoutes = (await import('@/app/modules/owner/owner.routes')).default;
    const { globalErrorMiddleware } = await import('@/app/middlewares/globalError.middlewares');
    const app = express();
    app.use(express.json());
    app.use('/api/v1', ownerRoutes);
    app.use(globalErrorMiddleware);
    srv = await startTestServer(app);
  });

  after(async () => {
    try {
      const ids = (
        await db().user.findMany({
          where: { email: { startsWith: `t011-${run}-` } },
          select: { id: true },
        })
      ).map((u) => u.id);
      const orders = { orderId: { in: (await db().order.findMany({ where: { sellerUserId: { in: ids } }, select: { id: true } })).map((o) => o.id) } };
      // Deferred purchase triggers: delete attendees, purchases and orders in one transaction.
      await db().$transaction(async (tx) => {
        await tx.eventPurchaseAttendee.deleteMany({ where: { eventPurchase: orders } });
        await tx.eventPurchase.deleteMany({ where: orders });
        await tx.refund.deleteMany({ where: orders });
        await tx.order.deleteMany({ where: { sellerUserId: { in: ids } } });
      });
      await db().event.deleteMany({ where: { userId: { in: ids } } });
      await db().user.deleteMany({ where: { id: { in: ids } } });
    } finally {
      await srv?.close();
      await appPrisma?.$disconnect();
      await closeTestPrisma();
    }
  });

  it('unknown order -> 404 TICKET_NOT_FOUND', async () => {
    const r = await verify(ownerToken, { orderId: randomUUID() });
    assert.equal(r.status, 404);
    const b = (await r.json()) as Body;
    assert.equal(b.success, false);
    assert.equal(b.message, 'Ticket not found');
    assert.equal(b.errorType, 'TICKET_NOT_FOUND');
  });

  it("another seller's order -> 404 with the same body as an unknown order (no leak)", async () => {
    const foreign = await makeOrder(otherOwnerId);
    const a = await verify(ownerToken, { orderId: foreign.id });
    const u = await verify(ownerToken, { orderId: randomUUID() });
    assert.equal(a.status, 404);
    const { traceId: _t1, ...ab } = (await a.json()) as Body;
    const { traceId: _t2, ...ub } = (await u.json()) as Body;
    assert.deepEqual(ab, ub);
    const after = await db().order.findUniqueOrThrow({ where: { id: foreign.id } });
    assert.equal(after.checkedInAt, null, 'foreign order must not be checked in');
  });

  it('unpaid order -> 422 TICKET_NOT_VALID', async () => {
    const o = await makeOrder(ownerId, { status: 'PENDING_PAYMENT' });
    const r = await verify(ownerToken, { orderId: o.id });
    assert.equal(r.status, 422);
    const b = (await r.json()) as Body;
    assert.equal(b.errorType, 'TICKET_NOT_VALID');
    assert.match(b.message, /^Ticket is not valid for entry \(status: PENDING_PAYMENT\)$/);
  });

  it('refunded order -> 422 TICKET_NOT_VALID (existing any-refund rule kept, T-064 is separate)', async () => {
    const o = await makeOrder(ownerId, { refund: true });
    const r = await verify(ownerToken, { orderId: o.id });
    assert.equal(r.status, 422);
    const b = (await r.json()) as Body;
    assert.equal(b.errorType, 'TICKET_NOT_VALID');
    assert.match(b.message, /status: REFUNDED/);
  });

  it('first scan -> 200, second scan -> 409 TICKET_ALREADY_USED with usedAt', async () => {
    const o = await makeOrder(ownerId);
    const first = await verify(ownerToken, { orderId: o.id });
    assert.equal(first.status, 200);
    const fb = (await first.json()) as { success: boolean; message: string; data: { orderId: string; status: string; checkedInAt: string } };
    assert.equal(fb.success, true);
    assert.equal(fb.message, 'Ticket successfully verified.');
    assert.equal(fb.data.orderId, o.id);
    assert.equal(fb.data.status, 'VERIFIED');

    const second = await verify(ownerToken, { orderId: o.id });
    assert.equal(second.status, 409);
    const sb = (await second.json()) as Body;
    assert.equal(sb.success, false);
    assert.equal(sb.errorType, 'TICKET_ALREADY_USED');
    assert.match(sb.message, /^Ticket has already been used on /);
    assert.equal(sb.usedAt, fb.data.checkedInAt);
  });

  it('never 401 or 403 for a logged-in owner across all business failures', async () => {
    const used = await makeOrder(ownerId, { checkedInAt: new Date() });
    const unpaid = await makeOrder(ownerId, { status: 'PENDING_PAYMENT' });
    const foreign = await makeOrder(otherOwnerId);
    const statuses = [];
    for (const id of [used.id, unpaid.id, foreign.id, randomUUID()]) {
      statuses.push((await verify(ownerToken, { orderId: id })).status);
    }
    assert.deepEqual(statuses, [409, 422, 404, 404]);
    for (const s of statuses) assert.ok(s !== 401 && s !== 403);
  });

  it('role/auth behaviour is unchanged: customer token still gets 403 from the role middleware', async () => {
    const r = await verify(buyerToken, { orderId: randomUUID() });
    assert.equal(r.status, 403);
    assert.equal(((await r.json()) as Body).errorType, 'ACCESS_DENIED');
  });
});
