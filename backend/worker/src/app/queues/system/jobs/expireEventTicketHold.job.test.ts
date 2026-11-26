import { after, before, describe, it } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { randomUUID } from 'node:crypto';
import type { Job } from 'bullmq';

// T-008: the worker job that releases the tier stock of an unpaid Event order.
// DB-backed: it only runs against a database named *_test or *_rehearsal.
// Real commits are used (the job opens its own transaction); rows are removed
// in `after`. No Redis is opened.

const testUrl = process.env.TEST_DATABASE_URL;
const safeName = (url: string): string => {
  const name = decodeURIComponent(new URL(url).pathname.replace(/^\//, ''));
  if (!/_(test|rehearsal)$/.test(name)) {
    throw new Error(`Refusing to run: database "${name}" must end in _test or _rehearsal`);
  }
  return url;
};
const skip = testUrl
  ? false
  : 'TEST_DATABASE_URL not set (needs a *_test or *_rehearsal database)';

type JobModule = typeof import('@/app/queues/system/jobs/expireEventTicketHold.job');
type Db = typeof import('@/app/configs/db.configs');

describe('expire-event-ticket-hold job (T-008)', { skip }, () => {
  let job: JobModule['default'];
  let db: Db['default'];
  const created = {
    userIds: [] as string[],
    eventIds: [] as string[],
    orderIds: [] as string[],
  };

  before(async () => {
    process.env.DATABASE_URL = safeName(testUrl as string);
    job = (await import('@/app/queues/system/jobs/expireEventTicketHold.job')).default;
    db = (await import('@/app/configs/db.configs')).default;
  });

  after(async () => {
    try {
      await db.$transaction([
        db.eventPurchaseAttendee.deleteMany({
          where: { eventPurchase: { eventId: { in: created.eventIds } } },
        }),
        db.eventPurchase.deleteMany({ where: { eventId: { in: created.eventIds } } }),
        db.order.deleteMany({ where: { id: { in: created.orderIds } } }),
        db.eventTicketTier.deleteMany({ where: { eventId: { in: created.eventIds } } }),
        db.event.deleteMany({ where: { id: { in: created.eventIds } } }),
        db.user.deleteMany({ where: { id: { in: created.userIds } } }),
      ]);
    } finally {
      await db.$disconnect();
    }
  });

  const run = (orderId: string) => job.handler({ orderId }, {} as Job);

  /** An Event order holding `personCount` seats of a tier whose soldCount is `soldCount`. */
  const seed = async (
    opts: {
      withTier?: boolean;
      status?: 'PENDING_PAYMENT' | 'PAID' | 'PAYMENT_FAILED';
      personCount?: number;
      soldCount?: number;
    } = {}
  ) => {
    const { withTier = true, status = 'PENDING_PAYMENT', personCount = 3, soldCount = 5 } = opts;
    const tag = randomUUID();
    const seller = await db.user.create({
      data: {
        name: 'S',
        email: `s-${tag}@example.test`,
        phoneNumber: `+1555${tag.slice(0, 7)}`,
        accountRole: 'CLUB_OWNER',
      },
    });
    const buyer = await db.user.create({
      data: { name: 'B', email: `b-${tag}@example.test`, phoneNumber: `+1556${tag.slice(0, 7)}` },
    });
    const event = await db.event.create({
      data: {
        userId: seller.id,
        eventName: 'E',
        thumbnail: 'https://example.test/t.png',
        lat: 1,
        lng: 1,
        startAt: new Date(Date.now() + 86_400_000),
        endAt: new Date(Date.now() + 2 * 86_400_000),
        dressCode: 'casual',
        eventPrice: 10,
        currency: 'USD',
      },
    });
    const tier = await db.eventTicketTier.create({
      data: { eventId: event.id, tierName: 'General', price: 10, capacity: 100, soldCount },
    });
    // The Order/EventPurchase pairing is checked at commit: create both together.
    const order = await db.$transaction(async (tx) => {
      const o = await tx.order.create({
      data: {
        buyerUserId: buyer.id,
        sellerUserId: seller.id,
        serviceType: 'EVENT',
        buyerName: 'B',
        buyerPhoneNumber: '+15550000000',
        grossAmount: 30,
        serviceChargeAmount: 1,
        buyerTotal: 31,
        commissionRate: 10,
        commissionAmount: 3,
        sellerEarnings: 27,
        currency: 'USD',
        idempotencyKey: tag,
        status,
      },
    });
    await tx.eventPurchase.create({
      data: {
        orderId: o.id,
        eventId: event.id,
        personCount,
        eventName: 'E',
        eventLocation: 'L',
        eventStartAt: event.startAt,
        eventEndAt: event.endAt,
        pricePerPerson: 10,
        transferEligibleAt: new Date(event.startAt.getTime() - 6 * 60 * 60 * 1000),
        ...(withTier ? { ticketTierId: tier.id, ticketTierName: tier.tierName } : {}),
      },
    });
    // The attendee trigger wants one buyer plus personCount - 1 friends.
    const purchase = await tx.eventPurchase.findUniqueOrThrow({ where: { orderId: o.id } });
    await tx.eventPurchaseAttendee.createMany({
      data: Array.from({ length: personCount }, (_, i) => ({
        eventPurchaseId: purchase.id,
        attendeeType: i === 0 ? ('BUYER' as const) : ('FRIEND' as const),
        position: i + 1,
        name: 'A',
        phoneNumber: '1',
        ...(i === 0 ? {} : { gender: 'MALE' as const, age: 20 }),
      })),
    });
    return o;
    });
    created.userIds.push(seller.id, buyer.id);
    created.eventIds.push(event.id);
    created.orderIds.push(order.id);
    return { orderId: order.id, tierId: tier.id };
  };

  const state = async (orderId: string, tierId: string) => ({
    status: (await db.order.findUniqueOrThrow({ where: { id: orderId } })).status,
    soldCount: (await db.eventTicketTier.findUniqueOrThrow({ where: { id: tierId } })).soldCount,
  });

  it('is registered under QUEUE_JOBS.EXPIRE_EVENT_TICKET_HOLD and sits where the system worker loader scans', async () => {
    const { QUEUE_JOBS } = await import('@/const');
    assert.equal(QUEUE_JOBS.EXPIRE_EVENT_TICKET_HOLD, 'expire-event-ticket-hold');
    assert.equal(job.name, QUEUE_JOBS.EXPIRE_EVENT_TICKET_HOLD);
    assert.equal(typeof job.handler, 'function');
    // system.workers.ts registers every *.job.ts / *.job.js file in this folder.
    assert.ok(fs.existsSync(path.join(__dirname, 'expireEventTicketHold.job.ts')));
  });

  it('PENDING order: marks it PAYMENT_FAILED and releases its seats; running twice releases once', async () => {
    const { orderId, tierId } = await seed({ personCount: 3, soldCount: 5 });
    await run(orderId);
    assert.deepEqual(await state(orderId, tierId), { status: 'PAYMENT_FAILED', soldCount: 2 });
    await run(orderId);
    assert.deepEqual(await state(orderId, tierId), { status: 'PAYMENT_FAILED', soldCount: 2 });
  });

  it('PAID order: changes nothing', async () => {
    const { orderId, tierId } = await seed({ status: 'PAID', soldCount: 5 });
    await run(orderId);
    assert.deepEqual(await state(orderId, tierId), { status: 'PAID', soldCount: 5 });
  });

  it('already PAYMENT_FAILED order: releases nothing (it was released when it failed)', async () => {
    const { orderId, tierId } = await seed({ status: 'PAYMENT_FAILED', soldCount: 5 });
    await run(orderId);
    assert.deepEqual(await state(orderId, tierId), { status: 'PAYMENT_FAILED', soldCount: 5 });
  });

  it('old NULL-tier order: releases nothing but still marks the order', async () => {
    const { orderId, tierId } = await seed({ withTier: false, soldCount: 5 });
    await run(orderId);
    assert.deepEqual(await state(orderId, tierId), { status: 'PAYMENT_FAILED', soldCount: 5 });
  });

  it('never takes soldCount below zero', async () => {
    const { orderId, tierId } = await seed({ personCount: 3, soldCount: 1 });
    await run(orderId);
    assert.deepEqual(await state(orderId, tierId), { status: 'PAYMENT_FAILED', soldCount: 0 });
  });

  it('unknown order id: does nothing and does not throw', async () => {
    await run(randomUUID());
  });
});
