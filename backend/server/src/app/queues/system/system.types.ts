export interface IExpireClubBookingHold {
  bookingId: string;
}

export interface IExpireEventModuleHold {
  bookingId: string;
}

export interface IExpireEventTicketHold {
  orderId: string;
}

export interface IMakeEventOngoing {
  eventId: string;
}

export interface IMakeEventCompleted {
  eventId: string;
}
