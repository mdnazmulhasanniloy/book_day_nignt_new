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

// T-006: the chosen tier is stored on EventPurchase (CR-04, BUG-B24).
// The service uses the app's own Prisma client, which reads DATABASE_URL, so
// it is pointed at the validated test database BEFORE the service is imported.
// The service commits for real, so rows are removed in `after`.

type PurchaseService = typeof import('@/app/modules/purchase/purchase.services');
type EventPurchaseMapper = typeof import('@/app/modules/bookings/bookings.helpers');

// Every key the live app already receives on `data.eventPurchase` (T-005 schema
// minus the two additive columns). None may be removed or renamed.
const LEGACY_EVENT_PURCHASE_KEYS = [
  'id',
  'orderId',
  'eventId',
  'personCount',
  'eventName',
  'eventLocation',
  'eventStartAt',
  'eventEndAt',
  'pricePerPerson',
  'transferEligibleAt',
  'createdAt',
  'updatedAt',
];

describe('POST /purchase/event stores the tier (T-006)', { skip: dbTestSkipReason() }, () => {
  let svc: PurchaseService;
  let mapper: EventPurchaseMapper;
  const created = {
    userIds: [] as string[],
    eventIds: [] as string[],
    orderIds: [] as string[],
    purchaseIds: [] as string[],
    chargeServices: false,
    serviceCharge: false,
  };

  before(async () => {
    process.env.DATABASE_URL = assertSafeTestDatabaseUrl(process.env.TEST_DATABASE_URL);
    svc = await import('@/app/modules/purchase/purchase.services');
    mapper = await import('@/app/modules/bookings/bookings.helpers');
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
      // The attendee-count trigger fires per row; delete attendees, purchases and orders in one transaction.
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

  const setup = async (tierOpts: { capacity?: number; tierName?: string } = {}) => {
    const db = getTestPrisma();
    const seller = await createUser(db, { accountRole: 'CLUB_OWNER' });
    const buyer = await createUser(db);
    await db.profile.create({
      data: { userId: buyer.id, dateOfBirth: new Date('1990-01-01'), gender: 'MALE' },
    });
    const event = await createEvent(db, seller.id);
    const tier = await createTier(db, event.id, {
      tierName: tierOpts.tierName ?? 'VIP',
      price: 25,
      capacity: tierOpts.capacity ?? 10,
    });
    created.userIds.push(seller.id, buyer.id);
    created.eventIds.push(event.id);
    return { buyer, event, tier };
  };

  const buy = async (
    buyerId: string,
    payload: { eventId: string; ticketTierId?: string; friends?: never[] }
  ) => {
    const key = `key-${Math.random().toString(36).slice(2)}-${Date.now()}`;
    const result = await svc.createEventPurchaseService({
      userId: buyerId,
      payload: { friends: [], ...payload },
      idempotencyKey: key,
      buyerAge: 30,
      queue: new FakeQueue(), // T-008: no real Redis in tests
    });
    created.orderIds.push(result.order.id);
    created.purchaseIds.push(result.eventPurchase.id);
    return result;
  };

  it('talks to the test database, not the one in .env', async () => {
    const { default: appPrisma } = await import('@/app/configs/db.configs');
    const rows = await appPrisma.$queryRaw<Array<{ db: string }>>`SELECT current_database() AS db`;
    assert.match(rows[0].db, /_(test|rehearsal)$/);
  });

  it('buying a tier stores ticketTierId and ticketTierName in the same transaction as soldCount', async () => {
    const { buyer, event, tier } = await setup();
    const result = await buy(buyer.id, {
      eventId: event.id,
      ticketTierId: tier.id,
      friends: [{ name: 'F', phoneNumber: '1', gender: 'MALE', age: 20 }] as never[],
    });
    const db = getTestPrisma();
    const row = await db.eventPurchase.findUniqueOrThrow({ where: { id: result.eventPurchase.id } });
    assert.equal(row.ticketTierId, tier.id);
    assert.equal(row.ticketTierName, 'VIP');
    assert.equal(result.eventPurchase.ticketTierId, tier.id);
    assert.equal(result.eventPurchase.ticketTierName, 'VIP');
    assert.equal((await db.eventTicketTier.findUniqueOrThrow({ where: { id: tier.id } })).soldCount, 2);
  });

  it('a purchase without a tier leaves both columns NULL and does not guess one', async () => {
    const { buyer, event } = await setup();
    const result = await buy(buyer.id, { eventId: event.id });
    assert.equal(result.eventPurchase.ticketTierId, null);
    assert.equal(result.eventPurchase.ticketTierName, null);
    const row = await getTestPrisma().eventPurchase.findUniqueOrThrow({ where: { id: result.eventPurchase.id } });
    assert.equal(row.ticketTierId, null);
    assert.equal(row.ticketTierName, null);
  });

  it('the purchase response keeps every legacy field and only adds the two tier fields', async () => {
    const { buyer, event, tier } = await setup();
    const result = await buy(buyer.id, { eventId: event.id, ticketTierId: tier.id });
    const keys = Object.keys(result.eventPurchase).sort();
    assert.deepEqual(keys, [...LEGACY_EVENT_PURCHASE_KEYS, 'ticketTierId', 'ticketTierName'].sort());
    assert.equal(typeof result.eventPurchase.personCount, 'number');
    assert.equal(String(result.eventPurchase.pricePerPerson), '25');
  });

  it('a tier at capacity still returns 409 "Ticket tier is sold out" and stores nothing', async () => {
    const { buyer, event, tier } = await setup({ capacity: 1 });
    await buy(buyer.id, { eventId: event.id, ticketTierId: tier.id });
    await assert.rejects(
      buy(buyer.id, { eventId: event.id, ticketTierId: tier.id }),
      (e: unknown) => {
        const err = e as { statusCode?: number; message?: string };
        assert.equal(err.statusCode, 409);
        assert.equal(err.message, 'Ticket tier is sold out');
        return true;
      }
    );
    const db = getTestPrisma();
    assert.equal(await db.eventPurchase.count({ where: { eventId: event.id } }), 1);
    assert.equal((await db.eventTicketTier.findUniqueOrThrow({ where: { id: tier.id } })).soldCount, 1);
  });

  it('booking detail snapshot returns the tier, or null for no-tier and old purchases', async () => {
    const { buyer, event, tier } = await setup();
    const withTier = await buy(buyer.id, { eventId: event.id, ticketTierId: tier.id });
    const noTier = await buy(buyer.id, { eventId: event.id });
    const db = getTestPrisma();
    const load = (id: string) =>
      db.eventPurchase.findUniqueOrThrow({ where: { id }, include: { attendees: true } });

    const a = mapper.mapEventPurchaseBookingSnapshot(await load(withTier.eventPurchase.id));
    assert.equal(a.ticketTierId, tier.id);
    assert.equal(a.ticketTierName, 'VIP');
    const b = mapper.mapEventPurchaseBookingSnapshot(await load(noTier.eventPurchase.id));
    assert.equal(b.ticketTierId, null);
    assert.equal(b.ticketTierName, null);
    // existing keys unchanged
    for (const key of [
      'eventName', 'eventLocation', 'personCount', 'pricePerPerson',
      'eventStartAt', 'eventEndAt', 'attendees',
    ]) {
      assert.ok(key in b, `missing ${key}`);
    }
    assert.equal(typeof b.pricePerPerson, 'number');
  });
});
