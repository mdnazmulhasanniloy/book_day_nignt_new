import prisma from '@/app/configs/db.configs';
import {
  IRetrieveLoggedInUserBookingsService,
  IRetrieveLoggedInUserSingleBookingsService,
  IBookingDetailResponse,
  IRetrieveLoggedInUserTicketService,
  TTicketRetrievalResult,
  TExploreData,
  TExplorePresentation,
  TBookingListItem,
} from '@/app/modules/bookings/bookings.types';
import { resolveBuyerBookingByIdOrOrderId } from '@/app/modules/bookings/bookings.helpers';
import { exploreDetailService } from '@/app/modules/explore/explore.services';
import { Prisma } from '@prisma/client';
import { currentFixedCstWallClock } from '@/app/modules/purchase/purchase.helpers';
import { syncSucceededPaymentsForBuyer } from '@/app/modules/webhook/webhook.services';

/**
 * This service is used to retrieve all bookings of logged in user
 * @returns Promise<{ data: TBookingListItem[]; total: number; totalPages: number }>
 */
export const retrieveLoggedInUserBookingsService = async ({
  query,
  userId,
}: IRetrieveLoggedInUserBookingsService): Promise<{
  data: TBookingListItem[];
  total: number;
  totalPages: number;
}> => {
  const { tab, page, limit } = query;
  const skip = (page - 1) * limit;
  await syncSucceededPaymentsForBuyer(userId);
  const now = currentFixedCstWallClock();

  const baseWhere: Prisma.OrderWhereInput = {
    buyerUserId: userId,
    status: 'PAID',
    refund: tab === 'CANCELED' ? undefined : null,
  };

  const orConditions: Prisma.OrderWhereInput[] = [];

  if (tab === 'UPCOMING') {
    orConditions.push({
      serviceType: 'CLUB',
      clubBooking: { status: 'BOOKED', endAt: { gt: now } },
    });
    orConditions.push({
      serviceType: 'EVENT',
      eventPurchase: {
        eventStartAt: { gt: now },
        event: { eventStatus: { not: 'CANCELED' } },
      },
    });
    orConditions.push({
      serviceType: 'EVENT',
      eventModulePurchase: {
        status: 'BOOKED',
        event: {
          startAt: { gt: now },
          eventStatus: { not: 'CANCELED' },
        },
      },
    });
  } else if (tab === 'COMPLETED') {
    orConditions.push({
      serviceType: 'CLUB',
      clubBooking: { status: 'BOOKED', endAt: { lte: now } },
    });
    orConditions.push({
      serviceType: 'EVENT',
      eventPurchase: {
        eventEndAt: { lte: now },
        event: { eventStatus: { not: 'CANCELED' } },
      },
    });
    orConditions.push({
      serviceType: 'EVENT',
      eventModulePurchase: {
        status: 'BOOKED',
        event: {
          endAt: { lte: now },
          eventStatus: { not: 'CANCELED' },
        },
      },
    });
  } else if (tab === 'CANCELED') {
    orConditions.push({
      serviceType: 'EVENT',
      eventPurchase: {
        event: { eventStatus: 'CANCELED' },
      },
    });
    orConditions.push({
      serviceType: 'EVENT',
      eventModulePurchase: {
        event: { eventStatus: 'CANCELED' },
      },
    });
  }

  const where: Prisma.OrderWhereInput = {
    ...baseWhere,
    OR: orConditions,
  };

  const total = await prisma.order.count({ where });

  const orders = await prisma.order.findMany({
    where,
    orderBy: { createdAt: 'desc' },
    skip,
    take: limit,
    include: {
      clubBooking: {
        include: {
          club: {
            include: {
              clubPackages: true,
              reviews: true,
            },
          },
        },
      },
      eventPurchase: {
        include: {
          event: true,
        },
      },
      eventModulePurchase: {
        include: {
          event: true,
          module: true,
        },
      },
    },
  });

  const formattedData: TBookingListItem[] = orders.map((order) => {
    if (
      order.serviceType === 'CLUB' &&
      order.clubBooking &&
      order.clubBooking.club
    ) {
      const { clubBooking } = order;
      const { club } = clubBooking;

      const prices = club.clubPackages.map((p) => Number(p.price));
      const minPrice = prices.length > 0 ? Math.min(...prices) : 0;
      const maxPrice = prices.length > 0 ? Math.max(...prices) : 0;

      const reviewAvg =
        club.reviews.length > 0
          ? club.reviews.reduce((acc, curr) => acc + curr.rating, 0) /
            club.reviews.length
          : 0;

      return {
        id: clubBooking.id, // Booking id takes precedence as per requirements
        orderId: order.id,
        purchaseDate: order.createdAt,
        startAt: clubBooking.startAt,
        endAt: clubBooking.endAt,
        name: club.name,
        lat: Number(club.lat),
        lng: Number(club.lng),
        location: club.location,
        type: 'CLUB',
        thumbnail: club.thumbnail,
        currency: order.currency,

        review: Number(reviewAvg.toFixed(1)),
        isVip: Boolean(club.isVip),
        priceRange: {
          minPrice,
          maxPrice,
        },
      };
    } else if (
      order.serviceType === 'EVENT' &&
      order.eventPurchase &&
      order.eventPurchase.event
    ) {
      const { eventPurchase } = order;
      const { event } = eventPurchase;

      return {
        id: eventPurchase.id, // Booking id takes precedence as per requirements
        orderId: order.id,
        purchaseDate: order.createdAt,
        eventStartAt: eventPurchase.eventStartAt,
        eventEndAt: eventPurchase.eventEndAt,
        name: event.eventName,
        lat: Number(event.lat),
        lng: Number(event.lng),
        location: event.location,
        type: 'EVENT',
        thumbnail: event.thumbnail,
        currency: order.currency,
        price: Number(eventPurchase.pricePerPerson),
      };
    } else if (
      order.serviceType === 'EVENT' &&
      order.eventModulePurchase &&
      order.eventModulePurchase.event
    ) {
      const { eventModulePurchase } = order;
      const { event } = eventModulePurchase;

      return {
        id: eventModulePurchase.id,
        orderId: order.id,
        purchaseDate: order.createdAt,
        eventStartAt: event.startAt,
        eventEndAt: event.endAt,
        name: `${event.eventName} — ${eventModulePurchase.moduleName}`,
        lat: Number(event.lat),
        lng: Number(event.lng),
        location: event.location,
        type: 'EVENT',
        thumbnail: event.thumbnail,
        currency: order.currency,
        price: Number(eventModulePurchase.unitPrice),
      };
    }

    throw new Error('Invalid booking state or missing relation');
  });

  const totalPages = Math.ceil(total / limit) || 1;

  return {
    data: formattedData,
    total,
    totalPages,
  };
};

/**
 * This service is used to retrieve single booking of logged in user
 * @returns Promise<IBookingDetailResponse>
 */
const ticketStateFromPdf = (
  ticketPdf: { status: string } | null | undefined
): 'NOT_AVAILABLE' | 'PROCESSING' | 'READY' | 'FAILED' => {
  if (!ticketPdf) return 'NOT_AVAILABLE';
  if (ticketPdf.status === 'PENDING') return 'PROCESSING';
  if (ticketPdf.status === 'GENERATED') return 'READY';
  if (ticketPdf.status === 'FAILED') return 'FAILED';
  return 'NOT_AVAILABLE';
};

export const retrieveLoggedInUserSingleBookingsService = async ({
  id,
  query,
  userId,
}: IRetrieveLoggedInUserSingleBookingsService): Promise<IBookingDetailResponse> => {
  const { type } = query;
  await syncSucceededPaymentsForBuyer(userId);
  const now = currentFixedCstWallClock();

  const resolved = await resolveBuyerBookingByIdOrOrderId({
    id,
    userId,
    preferredType: type,
  });

  if (!resolved) {
    throw { statusCode: 404, message: 'Booking not found' };
  }

  if (type === 'CLUB') {
    if (resolved.kind !== 'CLUB') {
      throw { statusCode: 404, message: 'Booking not found' };
    }
    const clubBooking = resolved.clubBooking;

    const exploreData = await exploreDetailService({
      id: clubBooking.clubId,
      query: { type },
      userId,
    });
    if (!exploreData) throw new Error('Explore data not found');

    // Explicitly destructure to omit conflicting identity fields
    // eslint-disable-next-line @typescript-eslint/no-unused-vars
    const {
      id: _exploreId,
      type: _exploreType,
      ...explorePresentation
    } = exploreData as TExploreData & { id?: string; type?: string };

    let reviewState: 'NOT_ELIGIBLE' | 'CAN_REVIEW' | 'ALREADY_REVIEWED' =
      'NOT_ELIGIBLE';
    if (clubBooking.order.status === 'PAID' && clubBooking.endAt <= now) {
      const existingReview = await prisma.clubReview.findFirst({
        where: { userId, clubId: clubBooking.clubId },
      });
      reviewState = existingReview ? 'ALREADY_REVIEWED' : 'CAN_REVIEW';
    }

    const ticketState = ticketStateFromPdf(clubBooking.order.ticketPdf);
    let status: 'UPCOMING' | 'COMPLETED' | 'CANCELED' = 'UPCOMING';
    if (clubBooking.endAt <= now) {
      status = 'COMPLETED';
    }

    return {
      id: clubBooking.id,
      orderId: clubBooking.order.id,
      clubId: clubBooking.clubId,
      type: 'CLUB',
      ...(explorePresentation as TExplorePresentation),
      booking: {
        serviceType: 'CLUB',
        purchaseDate: clubBooking.order.createdAt,
        status,
        clubBooking: {
          startAt: clubBooking.startAt,
          endAt: clubBooking.endAt,
          guestCount: clubBooking.guestCount,
          clubName: clubBooking.clubName,
          clubLocation: clubBooking.clubLocation,
          packageName: clubBooking.packageName,
          packageCapacity: clubBooking.packageCapacity,
        },
        payment: {
          status: clubBooking.order.status,
          grossAmount: Number(clubBooking.order.grossAmount),
          serviceChargeAmount: Number(clubBooking.order.serviceChargeAmount),
          buyerTotal: Number(clubBooking.order.buyerTotal),
          currency: clubBooking.order.currency,
        },
        ticketState,
        reviewState,
        refund: null,
      },
    };
  }

  // EVENT ticket or VIP module
  if (resolved.kind === 'EVENT_TICKET') {
    const eventPurchase = resolved.eventPurchase as typeof resolved.eventPurchase & {
      attendees: Array<{
        id: string;
        name: string;
        gender: import('@prisma/client').Gender | null;
        age: number | null;
        phoneNumber: string;
      }>;
      event: { eventStatus: string };
      order: {
        id: string;
        createdAt: Date;
        status: string;
        grossAmount: unknown;
        serviceChargeAmount: unknown;
        buyerTotal: unknown;
        currency: string;
        ticketPdf: { status: string } | null;
        refund: { status: string; scheduledFor: Date | null } | null;
      };
    };

    const exploreData = await exploreDetailService({
      id: eventPurchase.eventId,
      query: { type },
      userId,
    });
    if (!exploreData) throw new Error('Explore data not found');

    // eslint-disable-next-line @typescript-eslint/no-unused-vars
    const {
      id: _exploreId,
      type: _exploreType,
      ...explorePresentation
    } = exploreData as TExploreData & { id?: string; type?: string };

    const ticketState = ticketStateFromPdf(eventPurchase.order.ticketPdf);

    let status: 'UPCOMING' | 'COMPLETED' | 'CANCELED' = 'UPCOMING';
    if (eventPurchase.event.eventStatus === 'CANCELED') {
      status = 'CANCELED';
    } else if (eventPurchase.eventEndAt <= now) {
      status = 'COMPLETED';
    }

    let refundData = null;
    if (
      eventPurchase.event.eventStatus === 'CANCELED' &&
      eventPurchase.order.refund
    ) {
      refundData = {
        status: eventPurchase.order.refund.status,
        amount: Number(eventPurchase.order.grossAmount),
        scheduledFor: eventPurchase.order.refund.scheduledFor,
      };
    }

    return {
      id: eventPurchase.id,
      orderId: eventPurchase.order.id,
      eventId: eventPurchase.eventId,
      type: 'EVENT',
      ...(explorePresentation as TExplorePresentation),
      booking: {
        serviceType: 'EVENT',
        purchaseDate: eventPurchase.order.createdAt,
        status,
        eventPurchase: {
          eventName: eventPurchase.eventName,
          eventLocation: eventPurchase.eventLocation,
          personCount: eventPurchase.personCount,
          pricePerPerson: Number(eventPurchase.pricePerPerson),
          eventStartAt: eventPurchase.eventStartAt,
          eventEndAt: eventPurchase.eventEndAt,
          attendees: eventPurchase.attendees.map((a) => ({
            id: a.id,
            name: a.name,
            gender: a.gender,
            age: a.age ? String(a.age) : '',
            phoneNumber: a.phoneNumber,
          })),
        },
        payment: {
          status: eventPurchase.order.status,
          grossAmount: Number(eventPurchase.order.grossAmount),
          serviceChargeAmount: Number(eventPurchase.order.serviceChargeAmount),
          buyerTotal: Number(eventPurchase.order.buyerTotal),
          currency: eventPurchase.order.currency,
        },
        ticketState,
        reviewState: 'NOT_ELIGIBLE',
        refund: refundData,
      },
    };
  }

  if (resolved.kind === 'EVENT_MODULE') {
    const modulePurchase = resolved.eventModulePurchase;

    const exploreData = await exploreDetailService({
      id: modulePurchase.eventId,
      query: { type },
      userId,
    });
    if (!exploreData) throw new Error('Explore data not found');

    // eslint-disable-next-line @typescript-eslint/no-unused-vars
    const {
      id: _exploreId,
      type: _exploreType,
      ...explorePresentation
    } = exploreData as TExploreData & { id?: string; type?: string };

    const ticketState = ticketStateFromPdf(modulePurchase.order.ticketPdf);

    let status: 'UPCOMING' | 'COMPLETED' | 'CANCELED' = 'UPCOMING';
    if (modulePurchase.event.eventStatus === 'CANCELED') {
      status = 'CANCELED';
    } else if (modulePurchase.event.endAt <= now) {
      status = 'COMPLETED';
    }

    let refundData = null;
    if (
      modulePurchase.event.eventStatus === 'CANCELED' &&
      modulePurchase.order.refund
    ) {
      refundData = {
        status: modulePurchase.order.refund.status,
        amount: Number(modulePurchase.order.grossAmount),
        scheduledFor: modulePurchase.order.refund.scheduledFor,
      };
    }

    return {
      id: modulePurchase.id,
      orderId: modulePurchase.order.id,
      eventId: modulePurchase.eventId,
      type: 'EVENT',
      ...(explorePresentation as TExplorePresentation),
      booking: {
        serviceType: 'EVENT',
        purchaseDate: modulePurchase.order.createdAt,
        status,
        eventModulePurchase: {
          moduleId: modulePurchase.moduleId,
          moduleName: modulePurchase.moduleName,
          venueArea: modulePurchase.venueArea,
          quantity: modulePurchase.quantity,
          guestCount: modulePurchase.guestCount,
          unitPrice: Number(modulePurchase.unitPrice),
          dateTime: modulePurchase.dateTime,
          eventName: modulePurchase.event.eventName,
          eventLocation: modulePurchase.event.location,
          eventStartAt: modulePurchase.event.startAt,
          eventEndAt: modulePurchase.event.endAt,
        },
        payment: {
          status: modulePurchase.order.status,
          grossAmount: Number(modulePurchase.order.grossAmount),
          serviceChargeAmount: Number(modulePurchase.order.serviceChargeAmount),
          buyerTotal: Number(modulePurchase.order.buyerTotal),
          currency: modulePurchase.order.currency,
        },
        ticketState,
        reviewState: 'NOT_ELIGIBLE',
        refund: refundData,
      },
    };
  }

  throw { statusCode: 404, message: 'Booking not found' };
};

/** Resolves an available ticket for club/event/module by booking id OR order id. */
export const retrieveLoggedInUserTicketService = async ({
  id,
  userId,
}: IRetrieveLoggedInUserTicketService): Promise<
  TTicketRetrievalResult<{ storageKey: string }>
> => {
  try {
    const resolved = await resolveBuyerBookingByIdOrOrderId({ id, userId });
    if (!resolved) return { status: 'NOT_FOUND' };

    const order =
      resolved.kind === 'CLUB'
        ? resolved.clubBooking.order
        : resolved.kind === 'EVENT_TICKET'
          ? resolved.eventPurchase.order
          : resolved.eventModulePurchase.order;

    if (order.buyerUserId !== userId || order.status !== 'PAID') {
      return { status: 'NOT_FOUND' };
    }

    const ticketPdf = order.ticketPdf;
    if (!ticketPdf) return { status: 'NOT_FOUND' };
    if (ticketPdf.status === 'PENDING') return { status: 'PENDING' };
    if (ticketPdf.status === 'FAILED') return { status: 'FAILED' };
    if (ticketPdf.status === 'GENERATED' && ticketPdf.storageKey) {
      return { status: 'GENERATED', data: { storageKey: ticketPdf.storageKey } };
    }
    return { status: 'NOT_FOUND' };
  } catch (error) {
    throw error;
  }
};

