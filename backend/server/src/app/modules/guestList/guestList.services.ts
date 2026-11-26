import prisma from '@/app/configs/db.configs';
import { sendPushNotification } from '@/app/modules/notification/notification.helpers';
import {
  computeIsOpen,
  countActiveGuests,
  getRemainingCapacity,
  mapGuestListEntry,
  mapOwnerGuestList,
} from '@/app/modules/guestList/guestList.helpers';
import {
  IGetGuestListService,
  IJoinGuestListService,
  IListGuestListEntriesService,
  IUpdateGuestListEntryService,
  IUpsertGuestListService,
} from '@/app/modules/guestList/guestList.types';

const assertOwnedEvent = async ({
  eventId,
  ownerUserId,
}: {
  eventId: string;
  ownerUserId: string;
}) => {
  const event = await prisma.event.findUnique({
    where: { id: eventId },
    select: {
      id: true,
      userId: true,
      deactivatedAt: true,
      startAt: true,
      clubId: true,
    },
  });

  if (!event || event.deactivatedAt !== null) {
    throw { statusCode: 404, message: 'Event not found' };
  }

  if (event.userId !== ownerUserId) {
    throw { statusCode: 403, message: 'You do not own this event' };
  }

  return event;
};

export const upsertGuestListService = async ({
  ownerUserId,
  eventId,
  payload,
}: IUpsertGuestListService) => {
  await assertOwnedEvent({ eventId, ownerUserId });

  for (const [index, fallback] of payload.fallbacks.entries()) {
    if (fallback.type === 'TICKET_TIER') {
      const tier = await prisma.eventTicketTier.findFirst({
        where: { id: fallback.id, eventId },
        select: { id: true },
      });
      if (!tier) {
        throw {
          statusCode: 422,
          message: `fallbacks[${index}]: ticket tier not found on this event`,
        };
      }
    } else if (fallback.type === 'MODULE') {
      const module = await prisma.eventModule.findFirst({
        where: { id: fallback.id, eventId },
        select: { id: true },
      });
      if (!module) {
        throw {
          statusCode: 422,
          message: `fallbacks[${index}]: module not found on this event`,
        };
      }
    } else if (fallback.type === 'CLUB_PACKAGE') {
      const pkg = await prisma.clubPackage.findUnique({
        where: { id: fallback.id },
        select: { id: true },
      });
      if (!pkg) {
        throw {
          statusCode: 422,
          message: `fallbacks[${index}]: club package not found`,
        };
      }
    } else if (fallback.type === 'WAITING_LIST') {
      const club = await prisma.club.findUnique({
        where: { id: fallback.id },
        select: { id: true, deactivatedAt: true },
      });
      if (!club || club.deactivatedAt !== null) {
        throw {
          statusCode: 422,
          message: `fallbacks[${index}]: club not found for waiting list`,
        };
      }
    }
  }

  const guestList = await prisma.$transaction(async (tx) => {
    const existing = await tx.eventGuestList.findUnique({
      where: { eventId },
      select: { id: true },
    });

    const data = {
      isEnabled: payload.isEnabled,
      daysBefore: payload.daysBefore ?? null,
      cutoffAt: payload.cutoffAt ? new Date(payload.cutoffAt) : null,
      arrivalTimes: payload.arrivalTimes,
      maleCap: payload.maleCap ?? null,
      femaleCap: payload.femaleCap ?? null,
      freeSpots: payload.freeSpots ?? null,
      dressCode: payload.dressCode ?? null,
      idRequired: payload.idRequired ?? false,
      notes: payload.notes ?? null,
    };

    const saved = existing
      ? await tx.eventGuestList.update({
          where: { eventId },
          data,
        })
      : await tx.eventGuestList.create({
          data: { eventId, ...data },
        });

    await tx.eventGuestListFallback.deleteMany({
      where: { guestListId: saved.id },
    });

    if (payload.fallbacks.length > 0) {
      await tx.eventGuestListFallback.createMany({
        data: payload.fallbacks.map((fallback, index) => ({
          guestListId: saved.id,
          type: fallback.type,
          targetId: fallback.id,
          sortOrder: index + 1,
        })),
      });
    }

    return tx.eventGuestList.findUniqueOrThrow({
      where: { id: saved.id },
      include: { fallbacks: { orderBy: { sortOrder: 'asc' } } },
    });
  });

  return mapOwnerGuestList(guestList);
};

export const getGuestListService = async ({
  ownerUserId,
  eventId,
}: IGetGuestListService) => {
  await assertOwnedEvent({ eventId, ownerUserId });

  const guestList = await prisma.eventGuestList.findUnique({
    where: { eventId },
    include: { fallbacks: { orderBy: { sortOrder: 'asc' } } },
  });

  if (!guestList) {
    throw { statusCode: 404, message: 'Guest list not configured' };
  }

  return mapOwnerGuestList(guestList);
};

export const joinGuestListService = async ({
  eventId,
  payload,
  userId,
}: IJoinGuestListService) => {
  const event = await prisma.event.findUnique({
    where: { id: eventId },
    select: {
      id: true,
      deactivatedAt: true,
      startAt: true,
      guestList: {
        include: { fallbacks: { orderBy: { sortOrder: 'asc' } } },
      },
    },
  });

  if (!event || event.deactivatedAt !== null) {
    throw { statusCode: 404, message: 'Event not found' };
  }

  const guestList = event.guestList;
  if (!guestList || !guestList.isEnabled) {
    throw { statusCode: 409, message: 'Guest list is closed' };
  }

  const used = await countActiveGuests(guestList.id);
  if (!computeIsOpen({ guestList, event, used })) {
    throw { statusCode: 409, message: 'Guest list is closed or full' };
  }

  const arrivalTime = payload.arrivalTime?.trim() || 'Anytime';

  // Only enforce slot membership when the owner configured specific times.
  // Empty arrivalTimes[] means any time / "Anytime" is allowed.
  if (
    guestList.arrivalTimes.length > 0 &&
    !guestList.arrivalTimes.includes(arrivalTime)
  ) {
    throw {
      statusCode: 422,
      message: 'arrivalTime is not available for this guest list',
    };
  }

  const remaining = getRemainingCapacity({ guestList, used });
  const partySize =
    payload.menCount + payload.womenCount + payload.otherCount;

  if (
    remaining.remainingTotal != null &&
    partySize > remaining.remainingTotal
  ) {
    throw { statusCode: 409, message: 'Guest list does not have enough spots' };
  }

  if (
    remaining.remainingMale != null &&
    payload.menCount > remaining.remainingMale
  ) {
    throw { statusCode: 409, message: 'Male guest list capacity reached' };
  }

  if (
    remaining.remainingFemale != null &&
    payload.womenCount > remaining.remainingFemale
  ) {
    throw { statusCode: 409, message: 'Female guest list capacity reached' };
  }

  // T-020 (B-29): one active (PENDING or CONFIRMED) request per user and
  // event. Check and insert run in one transaction under a per-user-and-event
  // advisory lock, so parallel identical joins cannot both pass the check.
  // No unique index: userId is nullable, has no relation, and a partial index
  // would be a migration (see known-issues B-29).
  const entry = await prisma.$transaction(async (tx) => {
    if (userId) {
      await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtextextended(${`guest-list-join:${userId}:${eventId}`}, 0))`;

      const existing = await tx.eventGuestListEntry.findFirst({
        where: {
          guestListId: guestList.id,
          userId,
          status: { in: ['PENDING', 'CONFIRMED'] },
        },
        select: { id: true },
      });

      if (existing) {
        throw {
          statusCode: 409,
          message: 'You already have an active request for this guest list',
          errorType: 'GUEST_LIST_DUPLICATE',
        };
      }
    }

    return tx.eventGuestListEntry.create({
      data: {
        guestListId: guestList.id,
        userId: userId ?? null,
        name: payload.name,
        email: payload.email,
        phone: payload.phone,
        menCount: payload.menCount,
        womenCount: payload.womenCount,
        otherCount: payload.otherCount,
        arrivalTime,
        acceptedTerms: true,
        status: 'PENDING',
      },
    });
  });

  return {
    id: entry.id,
    status: entry.status,
    menCount: entry.menCount,
    womenCount: entry.womenCount,
    otherCount: entry.otherCount,
  };
};

export const listGuestListEntriesService = async ({
  ownerUserId,
  eventId,
  query,
}: IListGuestListEntriesService) => {
  await assertOwnedEvent({ eventId, ownerUserId });

  const guestList = await prisma.eventGuestList.findUnique({
    where: { eventId },
    select: { id: true },
  });

  if (!guestList) {
    return {
      meta: {
        page: query.page,
        limit: query.limit,
        total: 0,
        totalPages: 1,
      },
      data: [],
    };
  }

  const { page, limit } = query;
  const skip = (page - 1) * limit;

  const [rows, total] = await Promise.all([
    prisma.eventGuestListEntry.findMany({
      where: { guestListId: guestList.id },
      orderBy: { createdAt: 'asc' },
      skip,
      take: limit,
    }),
    prisma.eventGuestListEntry.count({ where: { guestListId: guestList.id } }),
  ]);

  return {
    meta: {
      page,
      limit,
      total,
      totalPages: Math.ceil(total / limit) || 1,
    },
    data: rows.map(mapGuestListEntry),
  };
};

export const updateGuestListEntryService = async ({
  ownerUserId,
  eventId,
  entryId,
  payload,
}: IUpdateGuestListEntryService) => {
  await assertOwnedEvent({ eventId, ownerUserId });

  const entry = await prisma.eventGuestListEntry.findFirst({
    where: {
      id: entryId,
      guestList: { eventId },
    },
    include: {
      guestList: {
        select: {
          event: {
            select: { id: true, eventName: true },
          },
        },
      },
    },
  });

  if (!entry) {
    throw { statusCode: 404, message: 'Guest list entry not found' };
  }

  const updated = await prisma.eventGuestListEntry.update({
    where: { id: entryId },
    data: { status: payload.status },
  });

  // Notify the guest when an owner confirms or rejects their request.
  // Guest-list join can be anonymous (userId null) — skip push in that case.
  if (
    updated.userId &&
    (payload.status === 'CONFIRMED' || payload.status === 'REJECTED')
  ) {
    const eventName = entry.guestList.event.eventName;
    const arrivalTime = updated.arrivalTime?.trim()
      ? updated.arrivalTime
      : 'Anytime';

    if (payload.status === 'CONFIRMED') {
      await sendPushNotification({
        userIds: [updated.userId],
        notificationType: 'GUEST_LIST_CONFIRMED',
        title: "You're on the Guest List! 🎉",
        description: `Your guest list entry for ${eventName} has been confirmed. Arrival time: ${arrivalTime}.`,
        metaData: {
          eventId: entry.guestList.event.id,
          entryId: updated.id,
          status: 'CONFIRMED',
          arrivalTime,
          serviceType: 'EVENT',
        },
      });
    } else {
      await sendPushNotification({
        userIds: [updated.userId],
        notificationType: 'GUEST_LIST_REJECTED',
        title: 'Guest List Update',
        description: `Sorry, your guest list request for ${eventName} could not be accommodated.`,
        metaData: {
          eventId: entry.guestList.event.id,
          entryId: updated.id,
          status: 'REJECTED',
          serviceType: 'EVENT',
        },
      });
    }
  }

  return mapGuestListEntry(updated);
};
