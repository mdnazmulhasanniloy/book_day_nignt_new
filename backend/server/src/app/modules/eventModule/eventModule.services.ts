import prisma from '@/app/configs/db.configs';
import { mapEventModule } from '@/app/modules/eventModule/eventModule.helpers';
import {
  IAssertOwnedEvent,
  ICreateEventModuleService,
  IDeleteEventModuleService,
  IDuplicateEventModuleService,
  IListEventModulesService,
  IReorderEventModulesService,
  IUpdateEventModuleService,
} from '@/app/modules/eventModule/eventModule.types';

const assertOwnedEvent = async ({
  eventId,
  ownerUserId,
}: IAssertOwnedEvent) => {
  const event = await prisma.event.findUnique({
    where: { id: eventId },
    select: { id: true, userId: true, deactivatedAt: true, currency: true },
  });

  if (!event || event.deactivatedAt !== null) {
    throw { statusCode: 404, message: 'Event not found' };
  }

  if (event.userId !== ownerUserId) {
    throw { statusCode: 403, message: 'You do not own this event' };
  }

  return event;
};

export const createEventModuleService = async ({
  ownerUserId,
  eventId,
  payload,
}: ICreateEventModuleService) => {
  const event = await assertOwnedEvent({ eventId, ownerUserId });

  const maxSort = await prisma.eventModule.aggregate({
    where: { eventId },
    _max: { sortOrder: true },
  });

  const module = await prisma.eventModule.create({
    data: {
      eventId,
      name: payload.name,
      image: payload.image ?? null,
      description: payload.description ?? null,
      maxGuests: payload.maxGuests,
      startingPrice: payload.startingPrice,
      minSpend: payload.minSpend,
      deposit: payload.deposit,
      currency: payload.currency || event.currency,
      quantity: payload.quantity,
      remaining: payload.quantity,
      venueArea: payload.venueArea ?? null,
      includedExtras: payload.includedExtras,
      optionalExtras: payload.optionalExtras,
      status: payload.status,
      sortOrder: payload.sortOrder ?? (maxSort._max.sortOrder ?? 0) + 1,
      isActive: payload.isActive,
    },
  });

  return mapEventModule(module);
};

export const listEventModulesService = async ({
  ownerUserId,
  eventId,
}: IListEventModulesService) => {
  await assertOwnedEvent({ eventId, ownerUserId });

  const modules = await prisma.eventModule.findMany({
    where: { eventId },
    orderBy: { sortOrder: 'asc' },
  });

  return modules.map(mapEventModule);
};

export const updateEventModuleService = async ({
  ownerUserId,
  eventId,
  moduleId,
  payload,
}: IUpdateEventModuleService) => {
  await assertOwnedEvent({ eventId, ownerUserId });

  const existing = await prisma.eventModule.findFirst({
    where: { id: moduleId, eventId },
  });

  if (!existing) {
    throw { statusCode: 404, message: 'Module not found' };
  }

  const nextQuantity = payload.quantity ?? existing.quantity;
  let nextRemaining = payload.remaining ?? existing.remaining;

  if (payload.quantity !== undefined && payload.remaining === undefined) {
    const sold = existing.quantity - existing.remaining;
    nextRemaining = Math.max(0, nextQuantity - sold);
  }

  if (nextRemaining > nextQuantity) {
    throw {
      statusCode: 422,
      message: 'remaining cannot exceed quantity',
      errors: [{ field: 'remaining', message: 'remaining cannot exceed quantity' }],
    };
  }

  const module = await prisma.eventModule.update({
    where: { id: moduleId },
    data: {
      ...(payload.name !== undefined ? { name: payload.name } : {}),
      ...(payload.image !== undefined ? { image: payload.image } : {}),
      ...(payload.description !== undefined
        ? { description: payload.description }
        : {}),
      ...(payload.maxGuests !== undefined ? { maxGuests: payload.maxGuests } : {}),
      ...(payload.startingPrice !== undefined
        ? { startingPrice: payload.startingPrice }
        : {}),
      ...(payload.minSpend !== undefined ? { minSpend: payload.minSpend } : {}),
      ...(payload.deposit !== undefined ? { deposit: payload.deposit } : {}),
      ...(payload.currency !== undefined ? { currency: payload.currency } : {}),
      ...(payload.quantity !== undefined ? { quantity: nextQuantity } : {}),
      remaining: nextRemaining,
      ...(payload.venueArea !== undefined ? { venueArea: payload.venueArea } : {}),
      ...(payload.includedExtras !== undefined
        ? { includedExtras: payload.includedExtras }
        : {}),
      ...(payload.optionalExtras !== undefined
        ? { optionalExtras: payload.optionalExtras }
        : {}),
      ...(payload.status !== undefined ? { status: payload.status } : {}),
      ...(payload.sortOrder !== undefined ? { sortOrder: payload.sortOrder } : {}),
      ...(payload.isActive !== undefined ? { isActive: payload.isActive } : {}),
    },
  });

  return mapEventModule(module);
};

export const deleteEventModuleService = async ({
  ownerUserId,
  eventId,
  moduleId,
}: IDeleteEventModuleService) => {
  await assertOwnedEvent({ eventId, ownerUserId });

  const existing = await prisma.eventModule.findFirst({
    where: { id: moduleId, eventId },
    select: { id: true },
  });

  if (!existing) {
    throw { statusCode: 404, message: 'Module not found' };
  }

  await prisma.eventModule.delete({ where: { id: moduleId } });

  return { message: 'Module deleted successfully' };
};

export const duplicateEventModuleService = async ({
  ownerUserId,
  eventId,
  moduleId,
}: IDuplicateEventModuleService) => {
  await assertOwnedEvent({ eventId, ownerUserId });

  const existing = await prisma.eventModule.findFirst({
    where: { id: moduleId, eventId },
  });

  if (!existing) {
    throw { statusCode: 404, message: 'Module not found' };
  }

  const maxSort = await prisma.eventModule.aggregate({
    where: { eventId },
    _max: { sortOrder: true },
  });

  const module = await prisma.eventModule.create({
    data: {
      eventId,
      name: `${existing.name} (Copy)`,
      image: existing.image,
      description: existing.description,
      maxGuests: existing.maxGuests,
      startingPrice: existing.startingPrice,
      minSpend: existing.minSpend,
      deposit: existing.deposit,
      currency: existing.currency,
      quantity: existing.quantity,
      remaining: existing.quantity,
      venueArea: existing.venueArea,
      includedExtras: existing.includedExtras,
      optionalExtras: existing.optionalExtras,
      status: 'AVAILABLE',
      sortOrder: (maxSort._max.sortOrder ?? 0) + 1,
      isActive: true,
    },
  });

  return mapEventModule(module);
};

export const reorderEventModulesService = async ({
  ownerUserId,
  eventId,
  payload,
}: IReorderEventModulesService) => {
  await assertOwnedEvent({ eventId, ownerUserId });

  const existing = await prisma.eventModule.findMany({
    where: { eventId },
    select: { id: true },
  });

  const existingIds = new Set(existing.map((m) => m.id));
  if (
    payload.ids.length !== existingIds.size ||
    payload.ids.some((id) => !existingIds.has(id))
  ) {
    throw {
      statusCode: 422,
      message: 'ids must include every module for this event exactly once',
      errors: [
        {
          field: 'ids',
          message: 'ids must include every module for this event exactly once',
        },
      ],
    };
  }

  await prisma.$transaction(
    payload.ids.map((id, index) =>
      prisma.eventModule.update({
        where: { id },
        data: { sortOrder: index + 1 },
      })
    )
  );

  const modules = await prisma.eventModule.findMany({
    where: { eventId },
    orderBy: { sortOrder: 'asc' },
  });

  return modules.map(mapEventModule);
};
