export interface IExpireClubBookingHold {
  bookingId: string;
}

export interface IExpireEventModuleHold {
  bookingId: string;
}

export interface IExpireEventTicketHold {
  orderId: string;
}

export interface IProcessSellerTransfer {
  orderId: string;
}

/** Cron-enqueued flush of the Redis view counters (T-041). No payload. */
export type IFlushEventViews = Record<string, never>;

export interface IMakeEventOngoing {
  eventId: string;
}

export interface IMakeEventCompleted {
  eventId: string;
}
