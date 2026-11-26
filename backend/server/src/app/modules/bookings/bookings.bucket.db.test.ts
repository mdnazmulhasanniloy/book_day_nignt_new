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

// T-046 (CR-14): GET /bookings `bucket` filter and `bookingStatus`.
// Real bookings router, real auth middlewares and error handler, fake Redis.
// No test depends on the real clock: events are in year 2001 (ended) or 2099
// (not ended). Committed rows use a per-run email prefix and are deleted in after().

const run = randomUUID().replace(/-/g, '').slice(0, 12);
const FAR_PAST = new Date('2001-01-01T20:00:00.000Z');
const FAR_PAST_END = new Date('2001-01-02T02:00:00.000Z');
const FAR_FUTURE = new Date('2099-01-01T20:00:00.000Z');
const FAR_FUTURE_END = new Date('2099-01-02T02:00:00.000Z');

type Item = Record<string, unknown> & { id: string; bookingStatus?: string; orderId: string | null };
type ListBody = {
  success: boolean;
  data: Item[];
  meta: { total: number; totalPages: number };
  errorType?: string;
};

describe('GET /bookings bucket and bookingStatus (T-046)', { skip: dbTestSkipReason() }, () => {
  let appPrisma: PrismaClient;
  let srv: Awaited<ReturnType<typeof startTestServer>>;
  const db = () => getTestPrisma();
  let ownerId: string;
  let buyerId: string;
  let otherId: string;
  let buyerToken: string;
  let otherToken: string;
  let futureEventId: string;
  let pastEventId: string;
  let canceledEventId: string;
  let clubId: string;
  let packageId: string;
  let clock = Date.UTC(2030, 0, 1);
  // label -> booking id (EventPurchase / ClubBooking / guest-list entry id)
  const ids: Record<string, string> = {};
  const orderIds: Record<string, string> = {};
  const otherIds = new Set<string>();

  const user = (tag: string, accountRole: 'CLUB_OWNER' | 'USER') =>
    db().user.create({
      data: {
        name: `T046 ${tag}`,
        email: `t046-${run}-${tag}@example.test`,
        phoneNumber: `+1555${Math.floor(Math.random() * 1e7)}`,
        accountRole,
        isVerified: true,
      },
    });

  const orderData = (buyer: string, status: 'PAID' | 'PENDING_PAYMENT' | 'PAYMENT_FAILED', service: 'EVENT' | 'CLUB') => {
    clock += 60_000;
    return {
      buyerUserId: buyer,
      sellerUserId: ownerId,
      serviceType: service,
      status,
      buyerName: 'T046 Buyer',
      buyerPhoneNumber: '+15550000000',
      grossAmount: 10,
      serviceChargeAmount: 1,
      buyerTotal: 11,
      commissionRate: 10,
      commissionAmount: 1,
      sellerEarnings: 9,
      currency: 'USD',
      idempotencyKey: randomUUID(),
      createdAt: new Date(clock),
    };
  };

  const makeEventOrder = async (
    label: string,
    buyer: string,
    eventId: string,
    start: Date,
    end: Date,
    status: 'PAID' | 'PENDING_PAYMENT' | 'PAYMENT_FAILED' = 'PAID',
    refund = false,
    own = true
  ) => {
    // The deferred purchase trigger needs order and purchase in one transaction.
    const purchase = await db().$transaction(async (tx) => {
      const order = await tx.order.create({ data: orderData(buyer, status, 'EVENT') });
      const created = await tx.eventPurchase.create({
        data: {
          orderId: order.id,
          eventId,
          personCount: 1,
          eventName: `T046 ${label}`,
          eventLocation: 'Somewhere',
          eventStartAt: start,
          eventEndAt: end,
          pricePerPerson: 10,
          transferEligibleAt: new Date(start.getTime() - 6 * 3_600_000),
          attendees: {
            create: [{ attendeeType: 'BUYER', position: 1, name: 'T046 Buyer', phoneNumber: '+15550000000' }],
          },
        },
      });
      if (refund) {
        await tx.refund.create({
          data: {
            orderId: order.id,
            idempotencyKey: randomUUID(),
            amount: 10,
            currency: 'USD',
            scheduledFor: new Date(),
          },
        });
      }
      return created;
    });
    if (own) {
      ids[label] = purchase.id;
      orderIds[label] = purchase.orderId;
    } else {
      otherIds.add(purchase.id);
    }
  };

  const makeClubBooking = async (
    label: string,
    status: 'PAID' | 'PENDING_PAYMENT',
    bookingStatus: 'BOOKED' | 'EXPIRED',
    start: Date,
    end: Date
  ) => {
    const booking = await db().$transaction(async (tx) => {
      const order = await tx.order.create({ data: orderData(buyerId, status, 'CLUB') });
      return tx.clubBooking.create({
        data: {
          orderId: order.id,
          clubId,
          clubPackageId: packageId,
          status: bookingStatus,
          startAt: start,
          endAt: end,
          holdExpiresAt: new Date(start.getTime() - 3_600_000),
          guestCount: 2,
          clubName: 'T046 Club',
          clubLocation: 'Somewhere',
          packageName: 'T046 Pkg',
          packageCapacity: 4,
        },
      });
    });
    ids[label] = booking.id;
    orderIds[label] = booking.orderId;
  };

  const makeEntry = async (
    label: string,
    guestListId: string,
    userId: string | null,
    status: 'PENDING' | 'CONFIRMED' | 'REJECTED',
    own = true
  ) => {
    clock += 60_000;
    const entry = await db().eventGuestListEntry.create({
      data: {
        guestListId,
        userId,
        name: 'T046 Guest',
        email: `t046-${run}-buyer@example.test`,
        phone: '+15550000000',
        arrivalTime: '22:00',
        acceptedTerms: true,
        status,
        createdAt: new Date(clock),
      },
    });
    if (own) ids[label] = entry.id;
    else otherIds.add(entry.id);
  };

  const get = (query: string, token?: string) =>
    fetch(`${srv.baseUrl}/api/v1/bookings${query}`, {
      headers: token ? { authorization: `Bearer ${token}` } : {},
    });
  const list = async (query: string, token = buyerToken) => {
    const r = await get(query, token);
    assert.equal(r.status, 200, query);
    return (await r.json()) as ListBody;
  };
  const labelsOf = (items: Item[]) => {
    const byId = new Map(Object.entries(ids).map(([label, id]) => [id, label]));
    return items.map((i) => byId.get(i.id) ?? `UNKNOWN:${i.id}`);
  };

  before(async () => {
    process.env.DATABASE_URL = assertSafeTestDatabaseUrl(process.env.TEST_DATABASE_URL);
    installFakeRedis();
    appPrisma = (await import('@/app/configs/db.configs')).default;
    const [{ current_database: name }] = await appPrisma.$queryRaw<{ current_database: string }[]>`select current_database()`;
    assert.match(name, /_test$/, 'app prisma client must target the test DB');

    const owner = await user('owner', 'CLUB_OWNER');
    const buyer = await user('buyer', 'USER');
    const other = await user('other', 'USER');
    ownerId = owner.id;
    buyerId = buyer.id;
    otherId = other.id;

    const mkEvent = (tag: string, start: Date, end: Date, eventStatus: 'UPCOMING' | 'CANCELED' = 'UPCOMING') =>
      db().event.create({
        data: {
          userId: ownerId,
          eventName: `T046 ${tag}`,
          thumbnail: 'https://example.test/t.png',
          lat: 23.78,
          lng: 90.4,
          startAt: start,
          endAt: end,
          dressCode: 'casual',
          eventPrice: 10,
          currency: 'USD',
          eventStatus,
        },
      });
    futureEventId = (await mkEvent('future', FAR_FUTURE, FAR_FUTURE_END)).id;
    pastEventId = (await mkEvent('past', FAR_PAST, FAR_PAST_END)).id;
    canceledEventId = (await mkEvent('canceled', FAR_FUTURE, FAR_FUTURE_END, 'CANCELED')).id;

    const club = await db().club.create({
      data: {
        userId: ownerId,
        name: 'T046 Club',
        thumbnail: 'https://example.test/t.png',
        dressCode: 'casual',
        lat: 23.78,
        lng: 90.4,
      },
    });
    clubId = club.id;
    packageId = (
      await db().clubPackage.create({
        data: { clubId, name: 'T046 Pkg', capacity: 4, price: 10, currency: 'USD', features: [] },
      })
    ).id;

    // The buyer's bookings, one per status (createdAt strictly increasing in this order).
    await makeEventOrder('paidFuture', buyerId, futureEventId, FAR_FUTURE, FAR_FUTURE_END);
    await makeEventOrder('paidEnded', buyerId, pastEventId, FAR_PAST, FAR_PAST_END);
    await makeEventOrder('paidCanceledEvent', buyerId, canceledEventId, FAR_FUTURE, FAR_FUTURE_END);
    await makeEventOrder('refunded', buyerId, futureEventId, FAR_FUTURE, FAR_FUTURE_END, 'PAID', true);
    await makeEventOrder('refundedCanceledEvent', buyerId, canceledEventId, FAR_FUTURE, FAR_FUTURE_END, 'PAID', true);
    await makeEventOrder('paymentPending', buyerId, futureEventId, FAR_FUTURE, FAR_FUTURE_END, 'PENDING_PAYMENT');
    await makeEventOrder('paymentFailed', buyerId, futureEventId, FAR_FUTURE, FAR_FUTURE_END, 'PAYMENT_FAILED');
    await makeClubBooking('clubPaidFuture', 'PAID', 'BOOKED', FAR_FUTURE, FAR_FUTURE_END);
    await makeClubBooking('clubExpiredHold', 'PENDING_PAYMENT', 'EXPIRED', FAR_FUTURE, FAR_FUTURE_END);

    const futureList = await db().eventGuestList.create({ data: { eventId: futureEventId, isEnabled: true } });
    const pastList = await db().eventGuestList.create({ data: { eventId: pastEventId, isEnabled: true } });
    await makeEntry('guestPending', futureList.id, buyerId, 'PENDING');
    await makeEntry('guestConfirmedFuture', futureList.id, buyerId, 'CONFIRMED');
    await makeEntry('guestRejected', futureList.id, buyerId, 'REJECTED');
    await makeEntry('guestConfirmedEnded', pastList.id, buyerId, 'CONFIRMED');

    // Another user, plus an entry with the buyer's EMAIL but no user id: none may leak.
    await makeEventOrder('x', otherId, futureEventId, FAR_FUTURE, FAR_FUTURE_END, 'PAID', false, false);
    await makeEventOrder('x', otherId, futureEventId, FAR_FUTURE, FAR_FUTURE_END, 'PENDING_PAYMENT', false, false);
    await makeEventOrder('x', otherId, pastEventId, FAR_PAST, FAR_PAST_END, 'PAID', false, false);
    await makeEventOrder('x', otherId, canceledEventId, FAR_FUTURE, FAR_FUTURE_END, 'PAID', true, false);
    await makeEntry('x', futureList.id, otherId, 'PENDING', false);
    await makeEntry('x', futureList.id, otherId, 'CONFIRMED', false);
    await makeEntry('x', futureList.id, otherId, 'REJECTED', false);
    await makeEntry('x', futureList.id, null, 'PENDING', false);

    const jwt = await import('@/app/utils/jwt.utils');
    const tok = (u: { id: string; accountRole: string; accountStatus: string }) =>
      jwt.generateAccessTokenForUser({
        sub: u.id,
        role: u.accountRole,
        isVerified: true,
        accountStatus: u.accountStatus,
        rememberMe: true,
      } as never);
    buyerToken = tok(buyer);
    otherToken = tok(other);

    const routes = (await import('@/app/modules/bookings/bookings.routes')).default;
    const { globalErrorMiddleware } = await import('@/app/middlewares/globalError.middlewares');
    const app = express();
    app.use(express.json());
    app.use('/api/v1', routes);
    app.use(globalErrorMiddleware);
    srv = await startTestServer(app);
  });

  after(async () => {
    try {
      const users = (
        await db().user.findMany({ where: { email: { startsWith: `t046-${run}-` } }, select: { id: true } })
      ).map((u) => u.id);
      const orders = (await db().order.findMany({ where: { buyerUserId: { in: users } }, select: { id: true } })).map(
        (o) => o.id
      );
      const byOrder = { orderId: { in: orders } };
      // Deferred purchase triggers: delete attendees, purchases and orders in one transaction.
      await db().$transaction(async (tx) => {
        await tx.eventPurchaseAttendee.deleteMany({ where: { eventPurchase: byOrder } });
        await tx.eventPurchase.deleteMany({ where: byOrder });
        await tx.clubBooking.deleteMany({ where: byOrder });
        await tx.refund.deleteMany({ where: byOrder });
        await tx.order.deleteMany({ where: { id: { in: orders } } });
      });
      await db().eventGuestList.deleteMany({ where: { event: { userId: { in: users } } } });
      await db().event.deleteMany({ where: { userId: { in: users } } });
      await db().club.deleteMany({ where: { userId: { in: users } } });
      await db().user.deleteMany({ where: { id: { in: users } } });
    } finally {
      await srv?.close();
      await appPrisma?.$disconnect();
      await closeTestPrisma();
    }
  });

  // ---- Old behaviour (no `bucket`): identical to before, plus bookingStatus ----

  describe('without bucket (backward compatible)', () => {
    const eventItem = async (label: string, name: string, start: Date, end: Date) => ({
      id: ids[label],
      orderId: orderIds[label],
      purchaseDate: (await db().order.findUniqueOrThrow({ where: { id: orderIds[label] } })).createdAt.toISOString(),
      eventStartAt: start.toISOString(),
      eventEndAt: end.toISOString(),
      name,
      lat: 23.78,
      lng: 90.4,
      location: (await db().event.findUniqueOrThrow({ where: { id: futureEventId } })).location,
      type: 'EVENT',
      thumbnail: 'https://example.test/t.png',
      currency: 'USD',
      price: 10,
    });
    const stripNew = (items: Item[]) =>
      items.map((i) => {
        const { bookingStatus: _b, ...rest } = i;
        return rest;
      });

    it('default tab UPCOMING: same keys and values as the old response (guest-list entries never appear)', async () => {
      const body = await list('');
      assert.equal(body.meta.total, 2);
      assert.deepEqual(labelsOf(body.data), ['clubPaidFuture', 'paidFuture']);
      const [club, paid] = stripNew(body.data);
      assert.deepEqual(paid, await eventItem('paidFuture', 'T046 future', FAR_FUTURE, FAR_FUTURE_END));
      const cb = await db().clubBooking.findUniqueOrThrow({ where: { id: ids.clubPaidFuture } });
      assert.deepEqual(club, {
        id: ids.clubPaidFuture,
        orderId: orderIds.clubPaidFuture,
        purchaseDate: (await db().order.findUniqueOrThrow({ where: { id: orderIds.clubPaidFuture } })).createdAt.toISOString(),
        startAt: cb.startAt.toISOString(),
        endAt: cb.endAt.toISOString(),
        name: 'T046 Club',
        lat: 23.78,
        lng: 90.4,
        location: (await db().club.findUniqueOrThrow({ where: { id: clubId } })).location,
        type: 'CLUB',
        thumbnail: 'https://example.test/t.png',
        currency: 'USD',
        review: 0,
        isVip: false,
        priceRange: { minPrice: 10, maxPrice: 10 },
      });
    });

    it('tab COMPLETED and tab CANCELED keep their old membership', async () => {
      const completed = await list('?tab=COMPLETED');
      assert.deepEqual(labelsOf(completed.data), ['paidEnded']);
      assert.deepEqual(
        stripNew(completed.data)[0],
        await eventItem('paidEnded', 'T046 past', FAR_PAST, FAR_PAST_END)
      );
      const canceled = await list('?tab=CANCELED');
      assert.deepEqual(labelsOf(canceled.data).sort(), ['paidCanceledEvent', 'refundedCanceledEvent']);
      assert.equal(canceled.meta.total, 2);
    });

    it('every item carries bookingStatus (additive field)', async () => {
      assert.deepEqual((await list('')).data.map((i) => i.bookingStatus), ['CONFIRMED', 'CONFIRMED']);
      assert.deepEqual((await list('?tab=COMPLETED')).data.map((i) => i.bookingStatus), ['CONFIRMED']);
      const canceled = await list('?tab=CANCELED');
      const byLabel = Object.fromEntries(labelsOf(canceled.data).map((l, i) => [l, canceled.data[i].bookingStatus]));
      assert.deepEqual(byLabel, { paidCanceledEvent: 'CANCELED', refundedCanceledEvent: 'REFUNDED' });
    });

    it('paging without bucket is unchanged', async () => {
      const p2 = await list('?limit=1&page=2');
      assert.deepEqual(labelsOf(p2.data), ['paidFuture']);
      assert.equal(p2.meta.total, 2);
      assert.equal(p2.meta.totalPages, 2);
    });
  });

  // ---- bucket ----

  describe('bucket', () => {
    it('FUTURE = confirmed and not ended', async () => {
      const body = await list('?bucket=FUTURE');
      assert.deepEqual(labelsOf(body.data).sort(), ['clubPaidFuture', 'guestConfirmedFuture', 'paidFuture']);
      assert.ok(body.data.every((i) => i.bookingStatus === 'CONFIRMED'));
      assert.equal(body.meta.total, 3);
    });

    it('PENDING = payment in progress or guest-list request pending', async () => {
      const body = await list('?bucket=PENDING');
      const status = Object.fromEntries(labelsOf(body.data).map((l, i) => [l, body.data[i].bookingStatus]));
      assert.deepEqual(status, { paymentPending: 'PAYMENT_PROCESSING', guestPending: 'GUEST_LIST_PENDING' });
      assert.equal(body.meta.total, 2);
    });

    it('PAST = ended, canceled, refunded (and failed or expired payments)', async () => {
      const body = await list('?bucket=PAST');
      const status = Object.fromEntries(labelsOf(body.data).map((l, i) => [l, body.data[i].bookingStatus]));
      assert.deepEqual(status, {
        paidEnded: 'CONFIRMED',
        paidCanceledEvent: 'CANCELED',
        refunded: 'REFUNDED',
        refundedCanceledEvent: 'REFUNDED',
        paymentFailed: 'CANCELED',
        clubExpiredHold: 'CANCELED',
        guestRejected: 'CANCELED',
        guestConfirmedEnded: 'CONFIRMED',
      });
      assert.equal(body.meta.total, 8);
    });

    it('every booking lands in exactly one bucket and nothing is lost or duplicated', async () => {
      const all = [
        ...labelsOf((await list('?bucket=FUTURE&limit=100')).data),
        ...labelsOf((await list('?bucket=PENDING&limit=100')).data),
        ...labelsOf((await list('?bucket=PAST&limit=100')).data),
      ];
      assert.equal(new Set(all).size, all.length);
      assert.deepEqual(all.sort(), Object.keys(ids).sort());
    });

    it('items are newest first and paging works with a bucket', async () => {
      const all = await list('?bucket=PAST&limit=100');
      const dates = all.data.map((i) => new Date(i.purchaseDate as string).getTime());
      assert.deepEqual([...dates].sort((a, b) => b - a), dates);
      const p1 = await list('?bucket=PAST&limit=3&page=1');
      const p3 = await list('?bucket=PAST&limit=3&page=3');
      assert.equal(p1.data.length, 3);
      assert.equal(p3.data.length, 2);
      assert.equal(p1.meta.total, 8);
      assert.equal(p1.meta.totalPages, 3);
      assert.deepEqual(p1.data.map((i) => i.id), all.data.slice(0, 3).map((i) => i.id));
    });

    it('guest-list items: id is the entry id, no order, type EVENT, event times, no price', async () => {
      const body = await list('?bucket=PENDING');
      const entry = body.data.find((i) => i.id === ids.guestPending);
      assert.ok(entry);
      assert.equal(entry.orderId, null);
      assert.equal(entry.type, 'EVENT');
      assert.equal(entry.name, 'T046 future');
      assert.equal(entry.eventStartAt, FAR_FUTURE.toISOString());
      assert.equal(entry.eventEndAt, FAR_FUTURE_END.toISOString());
      assert.equal('price' in entry, false);
    });

    it('bucket wins over tab', async () => {
      const body = await list('?bucket=PENDING&tab=COMPLETED');
      assert.equal(body.meta.total, 2);
    });

    it('invalid bucket -> 422', async () => {
      for (const bad of ['?bucket=NOPE', '?bucket=future', '?bucket=']) {
        const r = await get(bad, buyerToken);
        assert.equal(r.status, 422, bad);
      }
    });

    it('no token -> 401', async () => {
      assert.equal((await get('?bucket=FUTURE')).status, 401);
      assert.equal((await get('')).status, 401);
    });
  });

  // ---- ownership ----

  describe('a user only sees their own bookings', () => {
    it('another user never sees the buyer rows, in any bucket or tab', async () => {
      const own = new Set(Object.values(ids));
      for (const q of ['', '?tab=COMPLETED', '?tab=CANCELED', '?bucket=FUTURE', '?bucket=PENDING', '?bucket=PAST']) {
        const body = await list(`${q}${q ? '&' : '?'}limit=100`, otherToken);
        for (const item of body.data) {
          assert.ok(!own.has(item.id), `${q}: buyer row ${item.id} leaked to another user`);
        }
      }
    });

    it('the buyer never sees the other user rows, nor an entry with their email and no user id', async () => {
      for (const q of ['', '?tab=COMPLETED', '?tab=CANCELED', '?bucket=FUTURE', '?bucket=PENDING', '?bucket=PAST']) {
        const body = await list(`${q}${q ? '&' : '?'}limit=100`);
        for (const item of body.data) {
          assert.ok(!otherIds.has(item.id), `${q}: other user row ${item.id} leaked`);
        }
      }
    });

    it("the other user's own list has exactly their rows", async () => {
      const mine = new Set([...otherIds]);
      const all = [
        ...(await list('?bucket=FUTURE&limit=100', otherToken)).data,
        ...(await list('?bucket=PENDING&limit=100', otherToken)).data,
        ...(await list('?bucket=PAST&limit=100', otherToken)).data,
      ];
      // 4 orders + 3 entries with their user id; the user-less entry is nobody's.
      assert.equal(all.length, 7);
      assert.ok(all.every((i) => mine.has(i.id)));
    });

    it('the service throws on an empty user id instead of dropping the filter', async () => {
      const { retrieveLoggedInUserBookingsService } = await import('@/app/modules/bookings/bookings.services');
      for (const userId of ['', undefined as unknown as string]) {
        await assert.rejects(
          retrieveLoggedInUserBookingsService({
            query: { tab: 'UPCOMING', bucket: 'FUTURE', page: 1, limit: 10 },
            userId,
          })
        );
        await assert.rejects(
          retrieveLoggedInUserBookingsService({ query: { tab: 'UPCOMING', page: 1, limit: 10 }, userId })
        );
      }
    });
  });
});
