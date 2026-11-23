// T-046 (CR-14): bookingStatus and bucket derivation for GET /bookings.
// Pure functions: no database, no clock (the caller passes `now`).
//
// Mapping table (also in api-spec.yaml and the T-046 task file). Rules are
// applied top to bottom, the first match wins.
//
// Order (any Order.status):
//   1. a Refund row exists (any status)         -> REFUNDED            / PAST
//   2. PENDING_PAYMENT, hold expired            -> CANCELED            / PAST
//   3. PENDING_PAYMENT                          -> PAYMENT_PROCESSING  / PENDING
//   4. PAYMENT_FAILED                           -> CANCELED            / PAST
//   5. PAID, event canceled                     -> CANCELED            / PAST
//   6. PAID, endAt <= now                       -> CONFIRMED           / PAST
//   7. PAID, endAt > now                        -> CONFIRMED           / FUTURE
// Guest-list entry (EventGuestListEntry.status):
//   PENDING                                     -> GUEST_LIST_PENDING  / PENDING
//   REJECTED                                    -> CANCELED            / PAST
//   CONFIRMED, event canceled                   -> CANCELED            / PAST
//   CONFIRMED, endAt <= now                     -> CONFIRMED           / PAST
//   CONFIRMED, endAt > now                      -> CONFIRMED           / FUTURE

export type TBookingBucket = 'FUTURE' | 'PENDING' | 'PAST';
export type TBookingStatus =
  | 'CONFIRMED'
  | 'GUEST_LIST_PENDING'
  | 'PAYMENT_PROCESSING'
  | 'CANCELED'
  | 'REFUNDED';

export interface IBookingClassification {
  bookingStatus: TBookingStatus;
  bucket: TBookingBucket;
}

export const deriveOrderBookingStatus = ({
  orderStatus,
  hasRefund,
  eventCanceled,
  holdExpired,
  endAt,
  now,
}: {
  orderStatus: 'PENDING_PAYMENT' | 'PAID' | 'PAYMENT_FAILED';
  hasRefund: boolean;
  eventCanceled: boolean;
  holdExpired: boolean;
  endAt: Date;
  now: Date;
}): IBookingClassification => {
  if (hasRefund) return { bookingStatus: 'REFUNDED', bucket: 'PAST' };
  if (orderStatus === 'PENDING_PAYMENT') {
    return holdExpired
      ? { bookingStatus: 'CANCELED', bucket: 'PAST' }
      : { bookingStatus: 'PAYMENT_PROCESSING', bucket: 'PENDING' };
  }
  if (orderStatus === 'PAYMENT_FAILED') {
    return { bookingStatus: 'CANCELED', bucket: 'PAST' };
  }
  if (eventCanceled) return { bookingStatus: 'CANCELED', bucket: 'PAST' };
  return {
    bookingStatus: 'CONFIRMED',
    bucket: endAt.getTime() <= now.getTime() ? 'PAST' : 'FUTURE',
  };
};

export const deriveGuestListBookingStatus = ({
  status,
  endAt,
  eventCanceled,
  now,
}: {
  status: 'PENDING' | 'CONFIRMED' | 'REJECTED';
  endAt: Date;
  eventCanceled: boolean;
  now: Date;
}): IBookingClassification => {
  if (status === 'PENDING') {
    return { bookingStatus: 'GUEST_LIST_PENDING', bucket: 'PENDING' };
  }
  if (status === 'REJECTED' || eventCanceled) {
    return { bookingStatus: 'CANCELED', bucket: 'PAST' };
  }
  return {
    bookingStatus: 'CONFIRMED',
    bucket: endAt.getTime() <= now.getTime() ? 'PAST' : 'FUTURE',
  };
};
