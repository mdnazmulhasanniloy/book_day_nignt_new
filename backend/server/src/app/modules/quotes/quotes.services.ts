import prisma from '@/app/configs/db.configs';
import {
  ICreateQuoteService,
  IListQuotesService,
  IUpdateQuoteService,
} from '@/app/modules/quotes/quotes.types';

export const createQuoteService = async ({ payload }: ICreateQuoteService) => {
  const event = await prisma.event.findUnique({
    where: { id: payload.eventId },
    select: { id: true, deactivatedAt: true },
  });

  if (!event || event.deactivatedAt !== null) {
    throw { statusCode: 404, message: 'Event not found' };
  }

  const module = await prisma.eventModule.findFirst({
    where: {
      id: payload.moduleId,
      eventId: payload.eventId,
      isActive: true,
    },
    select: { id: true, status: true },
  });

  if (!module || module.status === 'UNAVAILABLE') {
    throw { statusCode: 404, message: 'Module not found' };
  }

  const quote = await prisma.quote.create({
    data: {
      eventId: payload.eventId,
      moduleId: payload.moduleId,
      name: payload.name,
      email: payload.email,
      phone: payload.phone,
      guestCount: payload.guestCount,
      message: payload.message,
      date: payload.date ? new Date(payload.date) : null,
      status: 'NEW',
    },
  });

  return {
    id: quote.id,
    status: quote.status,
  };
};

export const listQuotesService = async ({
  ownerUserId,
  query,
}: IListQuotesService) => {
  const { page, limit } = query;
  const skip = (page - 1) * limit;

  const where = {
    event: {
      userId: ownerUserId,
      deactivatedAt: null,
    },
  };

  const [rows, total] = await Promise.all([
    prisma.quote.findMany({
      where,
      include: {
        module: {
          select: {
            id: true,
            name: true,
            venueArea: true,
          },
        },
        event: {
          select: {
            id: true,
            eventName: true,
          },
        },
      },
      orderBy: { createdAt: 'desc' },
      skip,
      take: limit,
    }),
    prisma.quote.count({ where }),
  ]);

  const data = rows.map((quote) => ({
    id: quote.id,
    eventId: quote.eventId,
    moduleId: quote.moduleId,
    eventName: quote.event.eventName,
    moduleName: quote.module.name,
    tableName: quote.module.name,
    name: quote.name,
    email: quote.email,
    phone: quote.phone,
    guestCount: quote.guestCount,
    message: quote.message,
    date: quote.date,
    status: quote.status,
    createdAt: quote.createdAt,
    updatedAt: quote.updatedAt,
    event: {
      id: quote.event.id,
      name: quote.event.eventName,
    },
    module: {
      id: quote.module.id,
      name: quote.module.name,
      venueArea: quote.module.venueArea,
    },
  }));

  return {
    meta: {
      page,
      limit,
      total,
      totalPages: Math.ceil(total / limit) || 1,
    },
    data,
  };
};

export const updateQuoteService = async ({
  ownerUserId,
  quoteId,
  payload,
}: IUpdateQuoteService) => {
  const existing = await prisma.quote.findUnique({
    where: { id: quoteId },
    include: {
      event: {
        select: { userId: true, deactivatedAt: true },
      },
    },
  });

  if (!existing || existing.event.deactivatedAt !== null) {
    throw { statusCode: 404, message: 'Quote not found' };
  }

  if (existing.event.userId !== ownerUserId) {
    throw { statusCode: 403, message: 'You do not own this quote' };
  }

  const quote = await prisma.quote.update({
    where: { id: quoteId },
    data: { status: payload.status },
    include: {
      module: {
        select: {
          id: true,
          name: true,
          venueArea: true,
        },
      },
      event: {
        select: {
          id: true,
          eventName: true,
        },
      },
    },
  });

  return {
    id: quote.id,
    eventId: quote.eventId,
    moduleId: quote.moduleId,
    eventName: quote.event.eventName,
    moduleName: quote.module.name,
    tableName: quote.module.name,
    name: quote.name,
    email: quote.email,
    phone: quote.phone,
    guestCount: quote.guestCount,
    message: quote.message,
    date: quote.date,
    status: quote.status,
    createdAt: quote.createdAt,
    updatedAt: quote.updatedAt,
    event: {
      id: quote.event.id,
      name: quote.event.eventName,
    },
    module: {
      id: quote.module.id,
      name: quote.module.name,
      venueArea: quote.module.venueArea,
    },
  };
};
