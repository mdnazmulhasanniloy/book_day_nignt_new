import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  deriveGuestListBookingStatus,
  deriveOrderBookingStatus,
} from '@/app/modules/bookings/bookings.bucket';

// T-046 (CR-14): the status mapping table. Pure functions, a fixed `now`, no
// database and no real clock. Every OrderStatus and GuestListEntryStatus value
// is covered once.

const now = new Date('2030-06-01T12:00:00.000Z');
const future = new Date('2030-06-02T12:00:00.000Z');
const past = new Date('2030-05-31T12:00:00.000Z');

const order = (
  over: Partial<Parameters<typeof deriveOrderBookingStatus>[0]> = {}
) =>
  deriveOrderBookingStatus({
    orderStatus: 'PAID',
    hasRefund: false,
    eventCanceled: false,
    holdExpired: false,
    endAt: future,
    now,
    ...over,
  });

describe('deriveOrderBookingStatus (T-046)', () => {
  it('PAID, not ended -> CONFIRMED / FUTURE', () => {
    assert.deepEqual(order(), { bookingStatus: 'CONFIRMED', bucket: 'FUTURE' });
  });
  it('PAID, ended -> CONFIRMED / PAST', () => {
    assert.deepEqual(order({ endAt: past }), { bookingStatus: 'CONFIRMED', bucket: 'PAST' });
  });
  it('PAID, ends exactly now -> ended (same rule as tab COMPLETED: endAt <= now)', () => {
    assert.deepEqual(order({ endAt: now }), { bookingStatus: 'CONFIRMED', bucket: 'PAST' });
  });
  it('PAID, event canceled -> CANCELED / PAST', () => {
    assert.deepEqual(order({ eventCanceled: true }), { bookingStatus: 'CANCELED', bucket: 'PAST' });
  });
  it('PAID with a Refund row -> REFUNDED / PAST (also when the event is canceled)', () => {
    assert.deepEqual(order({ hasRefund: true }), { bookingStatus: 'REFUNDED', bucket: 'PAST' });
    assert.deepEqual(order({ hasRefund: true, eventCanceled: true }), {
      bookingStatus: 'REFUNDED',
      bucket: 'PAST',
    });
  });
  it('PENDING_PAYMENT -> PAYMENT_PROCESSING / PENDING', () => {
    assert.deepEqual(order({ orderStatus: 'PENDING_PAYMENT' }), {
      bookingStatus: 'PAYMENT_PROCESSING',
      bucket: 'PENDING',
    });
  });
  it('PENDING_PAYMENT with an expired hold -> CANCELED / PAST', () => {
    assert.deepEqual(order({ orderStatus: 'PENDING_PAYMENT', holdExpired: true }), {
      bookingStatus: 'CANCELED',
      bucket: 'PAST',
    });
  });
  it('PAYMENT_FAILED -> CANCELED / PAST', () => {
    assert.deepEqual(order({ orderStatus: 'PAYMENT_FAILED' }), {
      bookingStatus: 'CANCELED',
      bucket: 'PAST',
    });
  });
  it('any Refund row wins over the order status', () => {
    assert.equal(order({ orderStatus: 'PENDING_PAYMENT', hasRefund: true }).bookingStatus, 'REFUNDED');
    assert.equal(order({ orderStatus: 'PAYMENT_FAILED', hasRefund: true }).bookingStatus, 'REFUNDED');
  });
});

describe('deriveGuestListBookingStatus (T-046)', () => {
  it('PENDING -> GUEST_LIST_PENDING / PENDING', () => {
    assert.deepEqual(deriveGuestListBookingStatus({ status: 'PENDING', endAt: future, eventCanceled: false, now }), {
      bookingStatus: 'GUEST_LIST_PENDING',
      bucket: 'PENDING',
    });
  });
  it('CONFIRMED, not ended -> CONFIRMED / FUTURE; ended -> CONFIRMED / PAST', () => {
    assert.deepEqual(deriveGuestListBookingStatus({ status: 'CONFIRMED', endAt: future, eventCanceled: false, now }), {
      bookingStatus: 'CONFIRMED',
      bucket: 'FUTURE',
    });
    assert.deepEqual(deriveGuestListBookingStatus({ status: 'CONFIRMED', endAt: past, eventCanceled: false, now }), {
      bookingStatus: 'CONFIRMED',
      bucket: 'PAST',
    });
  });
  it('CONFIRMED on a canceled event -> CANCELED / PAST', () => {
    assert.deepEqual(deriveGuestListBookingStatus({ status: 'CONFIRMED', endAt: future, eventCanceled: true, now }), {
      bookingStatus: 'CANCELED',
      bucket: 'PAST',
    });
  });
  it('REJECTED -> CANCELED / PAST', () => {
    assert.deepEqual(deriveGuestListBookingStatus({ status: 'REJECTED', endAt: future, eventCanceled: false, now }), {
      bookingStatus: 'CANCELED',
      bucket: 'PAST',
    });
  });
});
