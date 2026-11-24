import { after, before, describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  assertSafeTestDatabaseUrl,
  closeTestPrisma,
  dbTestSkipReason,
  getTestPrisma,
} from '@/testing/testDb';
import { createEvent, createTier, createUser } from '@/testing/fixtures';
import { FakeQueue } from '@/testing/fakes';

// T-008: POST /purchase/event schedules one delayed job that releases the tier
// stock if the order is never paid. The queue is injected (FakeQueue); no Redis.

type PurchaseService = typeof import('@/app/modules/purchase/purchase.services');
type Consts = typeof import('@/const');

describe('event purchase enqueues the ticket hold expiry (T-008)', { skip: dbTestSkipReason() }, () => {
  let svc: PurchaseService;
  let consts: Consts;
  const created = {
    userIds: [] as string[],
    eventIds: [] as string[],
    orderIds: [] as string[],
    chargeServices: false,
    serviceCharge: false,
  };

  before(async () => {
    process.env.DATABASE_URL = assertSafeTestDatabaseUrl(process.env.TEST_DATABASE_URL);
    svc = await import('@/app/modules/purchase/purchase.services');
    consts = await import('@/const');
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

  after(async () => {
    const db = getTestPrisma();
    try {
      await db.$transaction([
        db.eventPurchaseAttendee.deleteMany({ where: { eventPurchase: { eventId: { in: created.eventIds } } } }),
        db.eventPurchase.deleteMany({ where: { eventId: { in: created.eventIds } } }),
        db.order.deleteMany({ where: { id: { in: created.orderIds } } }),
      ]);
      await db.event.deleteMany({ where: { id: { in: created.eventIds } } });
      await db.profile.deleteMany({ where: { userId: { in: created.userIds } } });
      await db.user.deleteMany({ where: { id: { in: created.userIds } } });
      if (created.chargeServices) await db.applicationCharge.deleteMany({ where: { serviceType: 'EVENT' } });
      if (created.serviceCharge) await db.serviceCharge.deleteMany({ where: { id: 'GLOBAL' } });
    } finally {
      const { default: appPrisma } = await import('@/app/configs/db.configs');
      await appPrisma.$disconnect();
      await closeTestPrisma();
    }
  });

  const setup = async () => {
    const db = getTestPrisma();
    const seller = await createUser(db, { accountRole: 'CLUB_OWNER' });
    const buyer = await createUser(db);
    await db.profile.create({
      data: { userId: buyer.id, dateOfBirth: new Date('1990-01-01'), gender: 'MALE' },
    });
    const event = await createEvent(db, seller.id);
    const tier = await createTier(db, event.id, { tierName: 'VIP', price: 25, capacity: 10 });
    created.userIds.push(seller.id, buyer.id);
    created.eventIds.push(event.id);
    return { buyer, event, tier };
  };

  it('enqueues exactly one expire job with the hold delay and the order id; a replay enqueues none', async () => {
    const { buyer, event, tier } = await setup();
    const queue = new FakeQueue();
    const args = {
      userId: buyer.id,
      payload: { eventId: event.id, ticketTierId: tier.id, friends: [] } as never,
      idempotencyKey: `hold-${Date.now()}`,
      buyerAge: 30,
      queue,
    };
    const first = await svc.createEventPurchaseService(args);
    created.orderIds.push(first.order.id);

    const jobs = queue.find(consts.QUEUE_JOBS.EXPIRE_EVENT_TICKET_HOLD);
    assert.equal(queue.jobs.length, 1);
    assert.equal(jobs.length, 1);
    assert.deepEqual(jobs[0].data, { orderId: first.order.id });
    assert.equal((jobs[0].opts as { delay: number }).delay, consts.EVENT_TICKET_HOLD_MS);
    assert.equal(consts.EVENT_TICKET_HOLD_MS, 15 * 60 * 1000);

    const replay = await svc.createEventPurchaseService(args);
    assert.equal(replay.replayed, true);
    assert.equal(queue.jobs.length, 1, 'replay must not enqueue a second job');
  });
});
