import prisma from '@/app/configs/db.configs';
import { IGetOwnerDashboardService, IOwnerDashboardResult } from '@/app/modules/owner/owner.types';
import { Prisma } from '@prisma/client';
import { currentFixedCstWallClock, decimalNumber } from '@/app/modules/purchase/purchase.helpers';
import { ILightweightExploreItem } from '@/app/modules/explore/explore.types';
import {
  parseOwnerExportBound,
  TOwnerBookingsExportQuery,
} from '@/app/modules/owner/owner.schema';

export const getOwnerDashboardService = async ({
  userId,
}: IGetOwnerDashboardService): Promise<IOwnerDashboardResult> => {
  const activeOwnerOrdersWhere: Prisma.OrderWhereInput = {
    sellerUserId: userId,
    status: 'PAID',
    refund: null,
    OR: [
      { clubBooking: { club: { deactivatedAt: null } } },
      {
        eventPurchase: {
          event: { deactivatedAt: null, eventStatus: { not: 'CANCELED' } },
        },
      },
      {
        eventModulePurchase: {
          event: { deactivatedAt: null, eventStatus: { not: 'CANCELED' } },
        },
      },
    ],
  };

  // 1. Total Club Bookings
  const totalClubBookings = await prisma.order.count({
    where: {
      ...activeOwnerOrdersWhere,
      serviceType: 'CLUB',
    },
  });

  // 2. Total Event Tickets Sold
  const totalEventTicketsSold = await prisma.eventPurchaseAttendee.count({
    where: {
      eventPurchase: {
        order: {
          ...activeOwnerOrdersWhere,
          serviceType: 'EVENT',
        },
      },
    },
  });

  // 3. Total Earnings
  const totalEarningsAgg = await prisma.order.aggregate({
    where: activeOwnerOrdersWhere,
    _sum: { sellerEarnings: true },
  });
  const totalEarnings = decimalNumber(totalEarningsAgg._sum.sellerEarnings || new Prisma.Decimal(0));

  // 4. This Month Earnings
  const now = currentFixedCstWallClock();
  const firstDayOfMonth = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1, 6, 0, 0, 0));

  const thisMonthEarningsAgg = await prisma.order.aggregate({
    where: {
      ...activeOwnerOrdersWhere,
      createdAt: { gte: firstDayOfMonth },
    },
    _sum: { sellerEarnings: true },
  });
  const thisMonthEarnings = decimalNumber(thisMonthEarningsAgg._sum.sellerEarnings || new Prisma.Decimal(0));

  // 5. Recent Bookings (Latest 2)
  const recentOrders = await prisma.order.findMany({
    where: activeOwnerOrdersWhere,
    orderBy: { createdAt: 'desc' },
    take: 2,
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
        },
      },
    },
  });

  const recentBookings: ILightweightExploreItem[] = recentOrders.map((order) => {
    if (order.serviceType === 'CLUB' && order.clubBooking && order.clubBooking.club) {
      const { clubBooking } = order;
      const { club } = clubBooking;

      const prices = club.clubPackages.map((p) => Number(p.price));
      const minPrice = prices.length > 0 ? Math.min(...prices) : 0;
      const maxPrice = prices.length > 0 ? Math.max(...prices) : 0;

      const reviewAvg =
        club.reviews.length > 0
          ? club.reviews.reduce((acc, curr) => acc + curr.rating, 0) / club.reviews.length
          : 0;

      return {
        id: clubBooking.id,
        name: club.name,
        lat: Number(club.lat),
        lng: Number(club.lng),
        location: club.location,
        type: 'CLUB',
        thumbnail: club.thumbnail,
        currency: order.currency,
        review: Number(reviewAvg.toFixed(1)),
        isVip: Boolean(club.isVip),
        priceRange: { minPrice, maxPrice },
      };
    } else if (order.serviceType === 'EVENT' && order.eventPurchase && order.eventPurchase.event) {
      const { eventPurchase } = order;
      const { event } = eventPurchase;

      return {
        id: eventPurchase.id,
        name: event.eventName,
        lat: Number(event.lat),
        lng: Number(event.lng),
        location: event.location,
        type: 'EVENT',
        thumbnail: event.thumbnail,
        currency: order.currency,
        price: Number(event.eventPrice),
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
    throw new Error('Incomplete order payload encountered');
  });

  return {
    totalClubBookings,
    totalEventTicketsSold,
    totalEarnings,
    thisMonthEarnings,
    recentBookings,
  };
};

export const getOwnerEarningsService = async ({
  userId,
  year,
}: import('@/app/modules/owner/owner.types').IGetOwnerEarningsService): Promise<import('@/app/modules/owner/owner.types').IOwnerEarningsResult> => {
  const activeOwnerOrdersWhere: Prisma.OrderWhereInput = {
    sellerUserId: userId,
    status: 'PAID',
    refund: null,
    OR: [
      { clubBooking: { club: { deactivatedAt: null } } },
      { eventPurchase: { event: { deactivatedAt: null, eventStatus: { not: 'CANCELED' } } } },
    ],
  };

  const now = currentFixedCstWallClock();
  const cstYear = now.getUTCFullYear();
  const cstMonth = now.getUTCMonth();
  const cstDate = now.getUTCDate();

  // 1. Time Boundaries
  const todayStart = new Date(Date.UTC(cstYear, cstMonth, cstDate, 6, 0, 0, 0));
  const tomorrowStart = new Date(Date.UTC(cstYear, cstMonth, cstDate + 1, 6, 0, 0, 0));
  const sevenDaysAgoStart = new Date(Date.UTC(cstYear, cstMonth, cstDate - 6, 6, 0, 0, 0));

  const selectedYear = year ?? cstYear;
  const selectedYearStart = new Date(Date.UTC(selectedYear, 0, 1, 6, 0, 0, 0));
  const nextYearStart = new Date(Date.UTC(selectedYear + 1, 0, 1, 6, 0, 0, 0));

  // 2. Today Overview
  const last7DaysRevenueAgg = await prisma.order.aggregate({
    where: { ...activeOwnerOrdersWhere, createdAt: { gte: sevenDaysAgoStart, lt: tomorrowStart } },
    _sum: { sellerEarnings: true },
  });
  const last7DaysRevenue = decimalNumber(last7DaysRevenueAgg._sum.sellerEarnings || new Prisma.Decimal(0));

  const todayRevenueAgg = await prisma.order.aggregate({
    where: { ...activeOwnerOrdersWhere, createdAt: { gte: todayStart, lt: tomorrowStart } },
    _sum: { sellerEarnings: true },
  });
  const todayRevenue = decimalNumber(todayRevenueAgg._sum.sellerEarnings || new Prisma.Decimal(0));

  const todayTotalClubBookings = await prisma.order.count({
    where: { ...activeOwnerOrdersWhere, serviceType: 'CLUB', createdAt: { gte: todayStart, lt: tomorrowStart } },
  });

  const todayTotalEventTicketsSold = await prisma.eventPurchaseAttendee.count({
    where: {
      eventPurchase: {
        order: { ...activeOwnerOrdersWhere, serviceType: 'EVENT', createdAt: { gte: todayStart, lt: tomorrowStart } },
      },
    },
  });

  // 3. Monthly Earning
  const ordersThisYear = await prisma.order.findMany({
    where: { ...activeOwnerOrdersWhere, createdAt: { gte: selectedYearStart, lt: nextYearStart } },
    select: { createdAt: true, sellerEarnings: true },
  });

  const monthlyData = Array.from({ length: 12 }, (_, i) => ({ month: i + 1, amount: 0 }));
  for (const order of ordersThisYear) {
    const fixedCstDate = new Date(order.createdAt.getTime() - 21600000);
    const monthIndex = fixedCstDate.getUTCMonth();
    monthlyData[monthIndex].amount += Number(order.sellerEarnings);
  }
  monthlyData.forEach((m) => {
    m.amount = Number(m.amount.toFixed(2));
  });

  // 4. Available Years
  const bounds = await prisma.order.aggregate({
    where: activeOwnerOrdersWhere,
    _min: { createdAt: true },
    _max: { createdAt: true },
  });

  const availableYears: number[] = [];
  if (bounds._min.createdAt && bounds._max.createdAt) {
    const minYear = new Date(bounds._min.createdAt.getTime() - 21600000).getUTCFullYear();
    const maxYear = new Date(bounds._max.createdAt.getTime() - 21600000).getUTCFullYear();
    
    const yearPromises = [];
    for (let y = maxYear; y >= minYear; y--) {
      const yearStart = new Date(Date.UTC(y, 0, 1, 6, 0, 0, 0));
      const nextYearBoundary = new Date(Date.UTC(y + 1, 0, 1, 6, 0, 0, 0));

      yearPromises.push(
        prisma.order.findFirst({
          where: {
            ...activeOwnerOrdersWhere,
            createdAt: { gte: yearStart, lt: nextYearBoundary },
          },
          select: { id: true },
        }).then((order) => ({ year: y, hasData: !!order }))
      );
    }

    const yearResults = await Promise.all(yearPromises);
    for (const res of yearResults) {
      if (res.hasData) {
        availableYears.push(res.year);
      }
    }
  }

  return {
    todayOverview: {
      last7DaysRevenue,
      todayRevenue,
      todayTotalClubBookings,
      todayTotalEventTicketsSold,
    },
    monthlyEarning: {
      selectedYear,
      data: monthlyData,
      availableYears,
    },
  };
};

export const getOwnerPaymentsService = async ({
  userId,
  query,
}: import('@/app/modules/owner/owner.types').IGetOwnerPaymentsService): Promise<import('@/app/modules/owner/owner.types').IOwnerPaymentsResult> => {
  const { type, clubId, eventId, page = 1, limit = 10 } = query;

  const whereCondition: Prisma.OrderWhereInput = {
    sellerUserId: userId,
    status: 'PAID',
    refund: null,
  };

  const orConditions: Prisma.OrderWhereInput[] = [];

  if (!type || type === 'CLUB') {
    if (clubId) {
      orConditions.push({ clubBooking: { clubId } });
    } else {
      orConditions.push({ serviceType: 'CLUB' });
    }
  }

  if (!type || type === 'EVENT') {
    if (eventId) {
      orConditions.push({ eventPurchase: { eventId } });
      orConditions.push({ eventModulePurchase: { eventId } });
    } else {
      orConditions.push({ serviceType: 'EVENT' });
    }
  }

  whereCondition.OR = orConditions;

  const total = await prisma.order.count({ where: whereCondition });
  const totalPages = Math.ceil(total / limit);

  const orders = await prisma.order.findMany({
    where: whereCondition,
    orderBy: { createdAt: 'desc' },
    skip: (page - 1) * limit,
    take: limit,
    include: {
      clubBooking: { select: { clubId: true, clubName: true } },
      eventPurchase: { select: { eventId: true, eventName: true } },
      eventModulePurchase: {
        select: {
          eventId: true,
          moduleName: true,
          event: { select: { id: true, eventName: true } },
        },
      },
    },
  });

  const data: import('@/app/modules/owner/owner.types').TOwnerPaymentItem[] = orders.map((order) => {
    if (order.serviceType === 'CLUB' && order.clubBooking) {
      const clubName = order.clubBooking.clubName;
      return {
        id: order.id,
        type: 'CLUB',
        clubId: order.clubBooking.clubId,
        clubName,
        club: { id: order.clubBooking.clubId, name: clubName },
        title: clubName,
        customerName: order.buyerName,
        createdAt: order.createdAt,
        amount: Number(order.sellerEarnings),
      };
    } else if (order.serviceType === 'EVENT' && order.eventPurchase) {
      const eventName = order.eventPurchase.eventName;
      return {
        id: order.id,
        type: 'EVENT',
        eventId: order.eventPurchase.eventId,
        eventName,
        event: { id: order.eventPurchase.eventId, name: eventName },
        title: eventName,
        customerName: order.buyerName,
        createdAt: order.createdAt,
        amount: Number(order.sellerEarnings),
      };
    } else if (order.serviceType === 'EVENT' && order.eventModulePurchase) {
      const emp = order.eventModulePurchase;
      const eventName = emp.event.eventName;
      return {
        id: order.id,
        type: 'EVENT',
        eventId: emp.eventId,
        eventName,
        event: { id: emp.eventId, name: eventName },
        title: emp.moduleName,
        customerName: order.buyerName,
        createdAt: order.createdAt,
        amount: Number(order.sellerEarnings),
      };
    }
    throw new Error(`Unexpected order state for order ${order.id}`);
  });

  return {
    meta: {
      page,
      limit,
      total,
      totalPages,
    },
    data,
  };
};
import { sendPushNotification } from '@/app/modules/notification/notification.helpers';

export const verifyTicketService = async ({
  userId,
  orderId,
}: import('@/app/modules/owner/owner.types').IVerifyTicketService): Promise<import('@/app/modules/owner/owner.types').IVerifyTicketResult> => {
  const order = await prisma.order.findUnique({
    where: { id: orderId },
    include: {
      clubBooking: true,
      eventPurchase: {
        include: {
          attendees: true,
        },
      },
      eventModulePurchase: true,
      refund: true,
    },
  });

  if (!order) {
    throw new Error('Ticket not found');
  }

  if (order.sellerUserId !== userId) {
    throw new Error('Unauthorized to verify this ticket');
  }

  if (order.status !== 'PAID' || order.refund) {
    throw new Error('Ticket is not valid for entry (status: ' + (order.refund ? 'REFUNDED' : order.status) + ')');
  }

  if (order.checkedInAt) {
    throw new Error('Ticket has already been used on ' + order.checkedInAt.toISOString());
  }

  if (
    !order.clubBooking &&
    !order.eventPurchase &&
    !order.eventModulePurchase
  ) {
    throw new Error('Ticket is missing a valid purchase relationship');
  }

  const updatedOrder = await prisma.order.update({
    where: { id: orderId },
    data: { checkedInAt: new Date() },
    include: {
      clubBooking: true,
      eventPurchase: {
        include: { attendees: true },
      },
      eventModulePurchase: true,
    },
  });

  const bookingId =
    updatedOrder.clubBooking?.id ??
    updatedOrder.eventPurchase?.id ??
    updatedOrder.eventModulePurchase?.id ??
    null;

  // Send push notification to the buyer that their ticket was verified
  await sendPushNotification({
    userIds: [updatedOrder.buyerUserId],
    notificationType: 'EVENT_REMINDER', // Note: Ideally TICKET_VERIFIED should be added to NotificationType
    title: 'Ticket Verified',
    description: `Your ${updatedOrder.serviceType.toLowerCase()} ticket has been successfully checked in! Enjoy!`,
    metaData: {
      bookingId,
      orderId: updatedOrder.id,
      serviceType: updatedOrder.serviceType,
    },
  });

  return {
    orderId: updatedOrder.id,
    checkedInAt: updatedOrder.checkedInAt!,
    status: 'VERIFIED',
    buyerName: updatedOrder.buyerName,
    serviceType: updatedOrder.serviceType,
    details:
      updatedOrder.clubBooking ??
      updatedOrder.eventPurchase ??
      updatedOrder.eventModulePurchase,
  };
};

const csvEscape = (value: unknown) => {
  const raw = value == null ? '' : String(value);
  if (/[",\n]/.test(raw)) {
    return `"${raw.replace(/"/g, '""')}"`;
  }
  return raw;
};

export const exportOwnerBookingsService = async ({
  userId,
  query,
}: {
  userId: string;
  query: TOwnerBookingsExportQuery;
}) => {
  const from = parseOwnerExportBound(query.from, 'start');
  const to = parseOwnerExportBound(query.to, 'end');

  if (query.clubId) {
    const club = await prisma.club.findFirst({
      where: { id: query.clubId, userId },
      select: { id: true },
    });
    if (!club) {
      throw { statusCode: 404, message: 'Club not found' };
    }
  }

  if (query.eventId) {
    const event = await prisma.event.findFirst({
      where: { id: query.eventId, userId },
      select: { id: true },
    });
    if (!event) {
      throw { statusCode: 404, message: 'Event not found' };
    }
  }

  const where: Prisma.OrderWhereInput = {
    sellerUserId: userId,
    status: 'PAID',
    createdAt: { gte: from, lte: to },
    serviceType: query.type,
  };

  if (query.type === 'CLUB' && query.clubId) {
    where.clubBooking = { clubId: query.clubId };
  }

  if (query.type === 'EVENT' && query.eventId) {
    where.OR = [
      { eventPurchase: { eventId: query.eventId } },
      { eventModulePurchase: { eventId: query.eventId } },
    ];
  }

  const orders = await prisma.order.findMany({
    where,
    include: {
      buyer: { select: { email: true } },
      clubBooking: true,
      eventPurchase: true,
      eventModulePurchase: {
        include: {
          event: { select: { eventName: true } },
        },
      },
    },
    orderBy: { createdAt: 'asc' },
  });

  const bookingRefFromOrderId = (orderId: string) =>
    `#BDN-${orderId.replace(/-/g, '').slice(0, 8).toUpperCase()}`;

  const header = [
    'referenceId',
    'bookingType',
    'buyerName',
    'buyerEmail',
    'buyerPhone',
    'venueName',
    'tierOrModuleName',
    'guestsCount',
    'amountPaid',
    'currency',
    'paymentStatus',
    'purchasedAt',
    'checkInStatus',
    'orderId',
    'checkedInAt',
  ];

  const rows = orders.map((order) => {
    let bookingType = 'TICKET';
    let venueName = '';
    let tierOrModuleName = '';
    let guestsCount = 0;

    if (order.clubBooking) {
      bookingType = 'TABLE';
      venueName = order.clubBooking.clubName;
      tierOrModuleName = order.clubBooking.packageName;
      guestsCount = order.clubBooking.guestCount;
    } else if (order.eventModulePurchase) {
      bookingType = 'VIP_MODULE';
      venueName = order.eventModulePurchase.event.eventName;
      tierOrModuleName = order.eventModulePurchase.moduleName;
      guestsCount = order.eventModulePurchase.guestCount;
    } else if (order.eventPurchase) {
      bookingType = 'TICKET';
      venueName = order.eventPurchase.eventName;
      tierOrModuleName = 'General Admission';
      guestsCount = order.eventPurchase.personCount;
    }

    return [
      bookingRefFromOrderId(order.id),
      bookingType,
      order.buyerName,
      order.buyer.email,
      order.buyerPhoneNumber,
      venueName,
      tierOrModuleName,
      guestsCount,
      order.buyerTotal.toFixed(2),
      order.currency,
      order.status,
      order.createdAt.toISOString(),
      order.checkedInAt ? 'Checked-in' : 'Pending',
      order.id,
      order.checkedInAt ? order.checkedInAt.toISOString() : '',
    ]
      .map(csvEscape)
      .join(',');
  });

  const csv = [header.join(','), ...rows].join('\n');

  const { PutObjectCommand } = await import('@aws-sdk/client-s3');
  const s3Client = (await import('@/app/configs/s3Client.configs')).default;
  const { env } = await import('@/env');
  const { randomUUID } = await import('crypto');

  const key = `exports/bookings-${userId}-${randomUUID()}.csv`;
  await s3Client.send(
    new PutObjectCommand({
      Bucket: env.S3_BUCKET_NAME,
      Key: key,
      Body: Buffer.from(csv, 'utf8'),
      ContentType: 'text/csv',
      ACL: 'public-read',
    })
  );

  return {
    downloadUrl: `${env.S3_PUBLIC_URL}/${key}`,
    count: orders.length,
  };
};
