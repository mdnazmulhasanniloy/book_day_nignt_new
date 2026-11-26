import prisma from '@/app/configs/db.configs';
import {
  ClubBooking,
  Event,
  EventModule,
  EventModulePurchase,
  EventPurchase,
  EventPurchaseAttendee,
  Order,
  Refund,
  TicketPdf,
} from '@prisma/client';

type OrderWithTicket = Order & {
  ticketPdf: TicketPdf | null;
  refund?: Refund | null;
};

export type ResolvedBuyerBooking =
  | {
      kind: 'CLUB';
      bookingId: string;
      orderId: string;
      clubBooking: ClubBooking & { order: OrderWithTicket };
    }
  | {
      kind: 'EVENT_TICKET';
      bookingId: string;
      orderId: string;
      eventPurchase: EventPurchase & {
        order: OrderWithTicket;
        attendees: EventPurchaseAttendee[];
        event: Event;
      };
    }
  | {
      kind: 'EVENT_MODULE';
      bookingId: string;
      orderId: string;
      eventModulePurchase: EventModulePurchase & {
        order: OrderWithTicket;
        event: Event;
        module: EventModule;
      };
    };

const orderInclude = {
  ticketPdf: true,
  refund: true,
} as const;

/**
 * Resolve a buyer booking by ClubBooking/EventPurchase/EventModulePurchase id
 * OR by Order id. Used by GET /bookings/:id and ticket download routes.
 */
export const resolveBuyerBookingByIdOrOrderId = async ({
  id,
  userId,
  preferredType,
}: {
  id: string;
  userId: string;
  preferredType?: 'CLUB' | 'EVENT';
}): Promise<ResolvedBuyerBooking | null> => {
  if (!preferredType || preferredType === 'CLUB') {
    const clubBooking = await prisma.clubBooking.findUnique({
      where: { id },
      include: { order: { include: orderInclude } },
    });
    if (clubBooking && clubBooking.order.buyerUserId === userId) {
      return {
        kind: 'CLUB',
        bookingId: clubBooking.id,
        orderId: clubBooking.orderId,
        clubBooking,
      };
    }
  }

  if (!preferredType || preferredType === 'EVENT') {
    const eventPurchase = await prisma.eventPurchase.findUnique({
      where: { id },
      include: {
        attendees: true,
        event: true,
        order: { include: orderInclude },
      },
    });
    if (eventPurchase && eventPurchase.order.buyerUserId === userId) {
      return {
        kind: 'EVENT_TICKET',
        bookingId: eventPurchase.id,
        orderId: eventPurchase.orderId,
        eventPurchase,
      };
    }

    const eventModulePurchase = await prisma.eventModulePurchase.findUnique({
      where: { id },
      include: {
        event: true,
        module: true,
        order: { include: orderInclude },
      },
    });
    if (
      eventModulePurchase &&
      eventModulePurchase.order.buyerUserId === userId
    ) {
      return {
        kind: 'EVENT_MODULE',
        bookingId: eventModulePurchase.id,
        orderId: eventModulePurchase.orderId,
        eventModulePurchase,
      };
    }
  }

  const order = await prisma.order.findUnique({
    where: { id },
    include: {
      ticketPdf: true,
      refund: true,
      clubBooking: true,
      eventPurchase: {
        include: { attendees: true, event: true },
      },
      eventModulePurchase: {
        include: { event: true, module: true },
      },
    },
  });

  if (!order || order.buyerUserId !== userId) {
    return null;
  }

  if (
    (!preferredType || preferredType === 'CLUB') &&
    order.clubBooking
  ) {
    return {
      kind: 'CLUB',
      bookingId: order.clubBooking.id,
      orderId: order.id,
      clubBooking: { ...order.clubBooking, order },
    };
  }

  if (!preferredType || preferredType === 'EVENT') {
    if (order.eventPurchase) {
      return {
        kind: 'EVENT_TICKET',
        bookingId: order.eventPurchase.id,
        orderId: order.id,
        eventPurchase: {
          ...order.eventPurchase,
          order,
        },
      };
    }
    if (order.eventModulePurchase) {
      return {
        kind: 'EVENT_MODULE',
        bookingId: order.eventModulePurchase.id,
        orderId: order.id,
        eventModulePurchase: {
          ...order.eventModulePurchase,
          order,
        },
      };
    }
  }

  return null;
};

export const bookingIdFromOrderRelations = (order: {
  id: string;
  clubBooking?: { id: string } | null;
  eventPurchase?: { id: string } | null;
  eventModulePurchase?: { id: string } | null;
}) =>
  order.clubBooking?.id ??
  order.eventPurchase?.id ??
  order.eventModulePurchase?.id ??
  null;

/**
 * `booking.eventPurchase` block of GET /bookings/{id} for an event ticket.
 * Existing keys are unchanged; `ticketTierId` and `ticketTierName` are
 * additive (T-006, CR-04) and null for no-tier and pre-release purchases.
 */
export const mapEventPurchaseBookingSnapshot = (
  eventPurchase: EventPurchase & {
    attendees: Array<
      Pick<EventPurchaseAttendee, 'id' | 'name' | 'gender' | 'age' | 'phoneNumber'>
    >;
  }
) => ({
  eventName: eventPurchase.eventName,
  eventLocation: eventPurchase.eventLocation,
  personCount: eventPurchase.personCount,
  pricePerPerson: Number(eventPurchase.pricePerPerson),
  eventStartAt: eventPurchase.eventStartAt,
  eventEndAt: eventPurchase.eventEndAt,
  ticketTierId: eventPurchase.ticketTierId,
  ticketTierName: eventPurchase.ticketTierName,
  attendees: eventPurchase.attendees.map((a) => ({
    id: a.id,
    name: a.name,
    gender: a.gender,
    age: a.age ? String(a.age) : '',
    phoneNumber: a.phoneNumber,
  })),
});
