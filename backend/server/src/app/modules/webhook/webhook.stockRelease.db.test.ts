import { after, afterEach, before, beforeEach, describe, it, mock } from 'node:test';
import assert from 'node:assert/strict';
import { Queue } from 'bullmq';
import {
  assertSafeTestDatabaseUrl,
  closeTestPrisma,
  dbTestSkipReason,
  getTestPrisma,
} from '@/testing/testDb';
import { createEvent, createTier, createUser } from '@/testing/fixtures';
import { FakeQueue, installFakeRedis, signStripePayload } from '@/testing/fakes';

// T-007: release EventTicketTier.soldCount when a payment fails or is canceled (CR-04, BUG-B24).
// The webhook service uses the app's own Prisma client (DATABASE_URL), pointed at the
// validated test database BEFORE the service is imported. Stripe is never called: the
// signature is generated locally and BullMQ `Queue.add` is replaced by a recorder.
// The service commits for real, so every row is removed in `after`.

type WebhookService = typeof import('@/app/modules/webhook/webhook.services');
type PurchaseService = typeof import('@/app/modules/purchase/purchase.services');

describe('webhook releases tier stock (T-007)', { skip: dbTestSkipReason() }, () => {
  let webhook: WebhookService;
  let purchase: PurchaseService;
  let secret: string;
  let logger: typeof import('@/app/configs/logger.configs').default;
  let queued: { name: string; data: unknown }[] = [];
  let errorLogs: string[] = [];
  const created = {
    userIds: [] as string[],
    eventIds: [] as string[],
    orderIds: [] as string[],
    eventKeys: [] as string[],
    chargeServices: false,
    serviceCharge: false,
  };

  before(async () => {
    installFakeRedis(); // Queue.add is replaced below; this only gives BullMQ a lazy client
    process.env.DATABASE_URL = assertSafeTestDatabaseUrl(process.env.TEST_DATABASE_URL);
    webhook = await import('@/app/modules/webhook/webhook.services');
    purchase = await import('@/app/modules/purchase/purchase.services');
    secret = (await import('@/env')).env.STRIPE_PAYMENT_WEBHOOK_SECRET_KEY;
    logger = (await import('@/app/configs/logger.configs')).default;
    const db = getTestPrisma();
    if (!(await db.applicationCharge.findUnique({ where: { serviceType: 'EVENT' } }))) {
      await db.applicationCharge.create({ data: { serviceType: 'EVENT', chargePercentage: 10 } });
      created.chargeServices = true;
    }
    if (!(await db.serviceCharge.findUnique({ where: { id: 'GLOBAL' } }))) {
      await db.serviceCharge.create({ data: { id: 'GLOBAL', amount: 1 } });
      created.serviceCharge = true;
    }
  });

  beforeEach(() => {
    queued = [];
    errorLogs = [];
    mock.method(Queue.prototype, 'add', async (name: string, data: unknown) => {
      queued.push({ name, data });
      return { id: String(queued.length) };
    });
    mock.method(logger, 'error', (msg: unknown) => {
      errorLogs.push(String(msg));
      return logger;
    });
  });

  afterEach(() => mock.restoreAll());

  after(async () => {
    const db = getTestPrisma();
    try {
      await db.$transaction([
        db.ticketPdf.deleteMany({ where: { orderId: { in: created.orderIds } } }),
        db.paymentTransaction.deleteMany({ where: { orderId: { in: created.orderIds } } }),
        db.eventPurchaseAttendee.deleteMany({ where: { eventPurchase: { eventId: { in: created.eventIds } } } }),
        db.eventPurchase.deleteMany({ where: { eventId: { in: created.eventIds } } }),
        db.order.deleteMany({ where: { id: { in: created.orderIds } } }),
        db.webhookEvent.deleteMany({ where: { stripeEventId: { in: created.eventKeys } } }),
      ]);
      await db.event.deleteMany({ where: { id: { in: created.eventIds } } });
      await db.profile.deleteMany({ where: { userId: { in: created.userIds } } });
      await db.user.deleteMany({ where: { id: { in: created.userIds } } });
      if (created.chargeServices) await db.applicationCharge.deleteMany({ where: { serviceType: 'EVENT' } });
      if (created.serviceCharge) await db.serviceCharge.deleteMany({ where: { id: 'GLOBAL' } });
    } finally {
      // The service created BullMQ queues lazily on the fake Redis client; stop its reconnect loop so the process can exit.
      (await import('@/app/configs/redis.configs')).getRedisClient().disconnect();
      const { default: appPrisma } = await import('@/app/configs/db.configs');
      await appPrisma.$disconnect();
      await closeTestPrisma();
    }
  });

  const rand = () => Math.random().toString(36).slice(2);

  const setup = async (capacity = 10) => {
    const db = getTestPrisma();
    const seller = await createUser(db, { accountRole: 'CLUB_OWNER' });
    const buyer = await createUser(db);
    await db.profile.create({
      data: { userId: buyer.id, dateOfBirth: new Date('1990-01-01'), gender: 'MALE' },
    });
    const event = await createEvent(db, seller.id);
    const tier = await createTier(db, event.id, { tierName: 'VIP', price: 25, capacity });
    created.userIds.push(seller.id, buyer.id);
    created.eventIds.push(event.id);
    return { buyer, event, tier };
  };

  /** Real checkout (T-006 path) plus the PaymentTransaction the payment flow creates. */
  const buy = async (
    buyerId: string,
    payload: { eventId: string; ticketTierId?: string },
    extraFriends = 1
  ) => {
    const friends = Array.from({ length: extraFriends }, () => ({
      name: 'F',
      phoneNumber: '1',
      gender: 'MALE' as const,
      age: 20,
    }));
    const result = await purchase.createEventPurchaseService({
      userId: buyerId,
      payload: { friends, ...payload } as never,
      idempotencyKey: `key-${rand()}-${Date.now()}`,
      buyerAge: 30,
      queue: new FakeQueue(), // T-008: no real Redis in tests
    });
    created.orderIds.push(result.order.id);
    const piId = `pi_${rand()}`;
    await getTestPrisma().paymentTransaction.create({
      data: {
        orderId: result.order.id,
        stripePaymentIntentId: piId,
        idempotencyKey: `pay-${rand()}`,
        amount: 50,
        currency: 'USD',
      },
    });
    return { orderId: result.order.id, piId };
  };

  const send = async (type: string, piId: string, eventId = `evt_${rand()}`) => {
    created.eventKeys.push(eventId);
    const payload = JSON.stringify({
      id: eventId,
      object: 'event',
      type,
      data: { object: { id: piId, object: 'payment_intent', latest_charge: null } },
    });
    await webhook.processPaymentWebhookService({
      payload,
      signature: signStripePayload(payload, secret),
    });
  };

  const sold = async (tierId: string) =>
    (await getTestPrisma().eventTicketTier.findUniqueOrThrow({ where: { id: tierId } })).soldCount;
  const orderStatus = async (orderId: string) =>
    (await getTestPrisma().order.findUniqueOrThrow({ where: { id: orderId } })).status;

  it('talks to the test database, not the one in .env', async () => {
    const { default: appPrisma } = await import('@/app/configs/db.configs');
    const rows = await appPrisma.$queryRaw<Array<{ db: string }>>`SELECT current_database() AS db`;
    assert.match(rows[0].db, /_(test|rehearsal)$/);
  });

  it('payment_failed after purchase returns soldCount to its previous value', async () => {
    const { buyer, event, tier } = await setup();
    const before = await sold(tier.id);
    const { orderId, piId } = await buy(buyer.id, { eventId: event.id, ticketTierId: tier.id });
    assert.equal(await sold(tier.id), before + 2);
    await send('payment_intent.payment_failed', piId);
    assert.equal(await orderStatus(orderId), 'PAYMENT_FAILED');
    assert.equal(await sold(tier.id), before);
  });

  it('payment_intent.canceled also releases the tier stock', async () => {
    const { buyer, event, tier } = await setup();
    const { orderId, piId } = await buy(buyer.id, { eventId: event.id, ticketTierId: tier.id });
    await send('payment_intent.canceled', piId);
    assert.equal(await orderStatus(orderId), 'PAYMENT_FAILED');
    assert.equal(await sold(tier.id), 0);
  });

  it('the same failed webhook delivered twice releases once', async () => {
    const { buyer, event, tier } = await setup();
    const first = await buy(buyer.id, { eventId: event.id, ticketTierId: tier.id });
    await buy(buyer.id, { eventId: event.id, ticketTierId: tier.id }); // other buyer order keeps 2 sold
    assert.equal(await sold(tier.id), 4);
    const evt = `evt_${rand()}`;
    await send('payment_intent.payment_failed', first.piId, evt);
    await send('payment_intent.payment_failed', first.piId, evt);
    assert.equal(await sold(tier.id), 2);
  });

  it('failed then canceled (two distinct events) for the same order releases once', async () => {
    const { buyer, event, tier } = await setup();
    const first = await buy(buyer.id, { eventId: event.id, ticketTierId: tier.id });
    await buy(buyer.id, { eventId: event.id, ticketTierId: tier.id });
    await send('payment_intent.payment_failed', first.piId);
    await send('payment_intent.canceled', first.piId);
    assert.equal(await sold(tier.id), 2);
  });

  it('release guard is the order state: a PAID order is never released, a failed one only once', async () => {
    const { buyer, event, tier } = await setup();
    const { orderId } = await buy(buyer.id, { eventId: event.id, ticketTierId: tier.id });
    const db = getTestPrisma();
    const { releaseEventTierStock } = await import('@/app/modules/webhook/webhook.helpers');

    await db.order.update({ where: { id: orderId }, data: { status: 'PAID' } });
    assert.equal(await db.$transaction((tx) => releaseEventTierStock({ tx, orderId })), 0);
    assert.equal(await sold(tier.id), 2);

    await db.order.update({ where: { id: orderId }, data: { status: 'PENDING_PAYMENT' } });
    assert.equal(await db.$transaction((tx) => releaseEventTierStock({ tx, orderId })), 2);
    assert.equal(await db.$transaction((tx) => releaseEventTierStock({ tx, orderId })), 0);
    assert.equal(await sold(tier.id), 0);
  });

  it('failed webhook for an order without a tier link changes no tier', async () => {
    const { buyer, event, tier } = await setup();
    await getTestPrisma().eventTicketTier.update({ where: { id: tier.id }, data: { soldCount: 5 } });
    const { orderId, piId } = await buy(buyer.id, { eventId: event.id }); // no ticketTierId: NULL link
    const row = await getTestPrisma().eventPurchase.findUniqueOrThrow({ where: { orderId } });
    assert.equal(row.ticketTierId, null);
    await send('payment_intent.payment_failed', piId);
    assert.equal(await orderStatus(orderId), 'PAYMENT_FAILED');
    assert.equal(await sold(tier.id), 5);
  });

  it('soldCount never goes below 0', async () => {
    const { buyer, event, tier } = await setup();
    const { orderId, piId } = await buy(buyer.id, { eventId: event.id, ticketTierId: tier.id });
    // Simulate leaked/edited stock: fewer sold than this order holds.
    await getTestPrisma().eventTicketTier.update({ where: { id: tier.id }, data: { soldCount: 1 } });
    await send('payment_intent.payment_failed', piId);
    assert.equal(await orderStatus(orderId), 'PAYMENT_FAILED');
    assert.equal(await sold(tier.id), 0);
  });

  it('succeeded does not release anything', async () => {
    const { buyer, event, tier } = await setup();
    const { orderId, piId } = await buy(buyer.id, { eventId: event.id, ticketTierId: tier.id });
    await send('payment_intent.succeeded', piId);
    assert.equal(await orderStatus(orderId), 'PAID');
    assert.equal(await sold(tier.id), 2);
  });

  it('succeeded after failed re-takes the stock when the tier still has room (no silent double count)', async () => {
    const { buyer, event, tier } = await setup(10);
    const { orderId, piId } = await buy(buyer.id, { eventId: event.id, ticketTierId: tier.id });
    await send('payment_intent.payment_failed', piId);
    assert.equal(await sold(tier.id), 0);
    await send('payment_intent.succeeded', piId);
    assert.equal(await orderStatus(orderId), 'PAID');
    assert.equal(await sold(tier.id), 2);
    // A repeat of the succeeded event (new id) must not count again.
    await send('payment_intent.succeeded', piId);
    assert.equal(await sold(tier.id), 2);
  });

  it('succeeded after failed when the tier is now full flags manual review and keeps the stock untouched', async () => {
    const { buyer, event, tier } = await setup(3);
    const { orderId, piId } = await buy(buyer.id, { eventId: event.id, ticketTierId: tier.id });
    await send('payment_intent.payment_failed', piId);
    // Someone else takes the released seats.
    await getTestPrisma().eventTicketTier.update({ where: { id: tier.id }, data: { soldCount: 3 } });
    queued.length = 0;
    await send('payment_intent.succeeded', piId);
    assert.equal(await sold(tier.id), 3, 'no oversell');
    assert.equal(await orderStatus(orderId), 'PAYMENT_FAILED', 'not marked PAID without stock');
    assert.equal(queued.length, 0, 'no ticket PDF, transfer or notification is queued');
    const flagged = errorLogs.filter((m) => m.includes('MANUAL_REVIEW') && m.includes(orderId));
    assert.equal(flagged.length, 1);
    assert.match(flagged[0], /traceId/);
  });
});
