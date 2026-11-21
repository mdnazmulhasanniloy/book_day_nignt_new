import { Prisma } from '@prisma/client';
import prisma from '@/app/configs/db.configs';
import { sendPushNotification } from '@/app/modules/notification/notification.helpers';
import {
  IJoinWaitingListService,
  ILeaveWaitingListService,
  IGetMyWaitingListService,
  IGetClubWaitingListStatusService,
  IGetClubWaitingListMembersService,
  INotifyWaitingListEntryService,
  IDeleteWaitingListEntryService,
} from '@/app/modules/waitingList/waitingList.types';

const assertClubOwnedBy = async ({
  clubId,
  ownerUserId,
}: {
  clubId: string;
  ownerUserId: string;
}) => {
  const club = await prisma.club.findUnique({
    where: { id: clubId },
    select: { id: true, userId: true, name: true, deactivatedAt: true },
  });

  if (!club || club.deactivatedAt !== null) {
    throw { statusCode: 404, message: 'Club not found' };
  }

  if (club.userId !== ownerUserId) {
    throw { statusCode: 403, message: 'You do not own this club' };
  }

  return club;
};

const mapOwnerWaitingListEntry = async ({
  row,
}: {
  row: {
    id: string;
    userId: string;
    clubId: string;
    status: 'PENDING' | 'NOTIFIED' | 'CANCELLED';
    startAt: Date | null;
    guestCount: number | null;
    createdAt: Date;
    user: {
      id: string;
      name: string;
      email: string;
      phoneNumber: string;
      profile: { profileAvatar: string | null } | null;
    };
  };
}) => {
  const position = await prisma.clubWaitingList.count({
    where: {
      clubId: row.clubId,
      status: { in: ['PENDING', 'NOTIFIED'] },
      createdAt: { lte: row.createdAt },
    },
  });

  return {
    id: row.id,
    userId: row.userId,
    clubId: row.clubId,
    position,
    status: row.status,
    startAt: row.startAt,
    guestCount: row.guestCount,
    createdAt: row.createdAt,
    user: {
      id: row.user.id,
      name: row.user.name,
      email: row.user.email,
      phoneNumber: row.user.phoneNumber,
      profileAvatar: row.user.profile?.profileAvatar ?? null,
    },
  };
};

export const joinWaitingListService = async ({
  userId,
  payload,
}: IJoinWaitingListService) => {
  const { clubId, startAt, guestCount } = payload;

  const club = await prisma.club.findUnique({
    where: { id: clubId },
    select: { id: true, name: true, deactivatedAt: true },
  });

  if (!club || club.deactivatedAt !== null) {
    throw { statusCode: 404, message: 'Club not found or inactive' };
  }

  const clubInclude = {
    club: {
      select: {
        id: true,
        name: true,
        location: true,
        thumbnail: true,
      },
    },
  } as const;

  // Check if user is already on the waiting list for this club as PENDING
  const existing = await prisma.clubWaitingList.findUnique({
    where: {
      userId_clubId_status: {
        userId,
        clubId,
        status: 'PENDING',
      },
    },
    include: clubInclude,
  });

  if (existing) {
    // Refresh preferred slot/party size when client re-joins with context.
    const updated =
      startAt !== undefined || guestCount !== undefined
        ? await prisma.clubWaitingList.update({
            where: { id: existing.id },
            data: {
              ...(startAt !== undefined ? { startAt } : {}),
              ...(guestCount !== undefined ? { guestCount } : {}),
            },
            include: clubInclude,
          })
        : existing;

    const position = await prisma.clubWaitingList.count({
      where: {
        clubId,
        status: 'PENDING',
        createdAt: { lte: updated.createdAt },
      },
    });

    return {
      ...updated,
      position,
    };
  }

  const entry = await prisma.clubWaitingList.create({
    data: {
      clubId,
      userId,
      status: 'PENDING',
      startAt: startAt ?? null,
      guestCount: guestCount ?? null,
    },
    include: clubInclude,
  });

  // Calculate current waiting position
  const position = await prisma.clubWaitingList.count({
    where: {
      clubId,
      status: 'PENDING',
      createdAt: { lte: entry.createdAt },
    },
  });

  return {
    ...entry,
    position,
  };
};

export const leaveWaitingListService = async ({
  userId,
  payload,
}: ILeaveWaitingListService) => {
  const { clubId } = payload;

  await prisma.clubWaitingList.deleteMany({
    where: {
      clubId,
      userId,
      status: 'PENDING',
    },
  });

  return {
    message: 'Successfully left waiting list',
  };
};

export const getMyWaitingListService = async ({
  userId,
  query,
}: IGetMyWaitingListService) => {
  const { page, limit } = query;
  const skip = (page - 1) * limit;

  const where = {
    userId,
    status: 'PENDING' as const,
  };

  const [data, total] = await Promise.all([
    prisma.clubWaitingList.findMany({
      where,
      include: {
        club: {
          select: {
            id: true,
            name: true,
            location: true,
            thumbnail: true,
            lat: true,
            lng: true,
          },
        },
      },
      orderBy: { createdAt: 'desc' },
      skip,
      take: limit,
    }),
    prisma.clubWaitingList.count({ where }),
  ]);

  return {
    meta: {
      page,
      limit,
      total,
      totalPages: Math.ceil(total / limit),
    },
    data,
  };
};

export const getClubWaitingListStatusService = async ({
  userId,
  clubId,
}: IGetClubWaitingListStatusService) => {
  const entry = await prisma.clubWaitingList.findUnique({
    where: {
      userId_clubId_status: {
        userId,
        clubId,
        status: 'PENDING',
      },
    },
    include: {
      club: {
        select: {
          id: true,
          name: true,
        },
      },
    },
  });

  if (!entry) {
    return {
      isWaiting: false,
      position: null,
      entry: null,
    };
  }

  const position = await prisma.clubWaitingList.count({
    where: {
      clubId,
      status: 'PENDING',
      createdAt: { lte: entry.createdAt },
    },
  });

  return {
    isWaiting: true,
    position,
    entry,
  };
};

/**
 * Owner-only paginated waiting-list members for a club they own.
 */
export const getClubWaitingListMembersService = async ({
  ownerUserId,
  clubId,
  query,
}: IGetClubWaitingListMembersService) => {
  await assertClubOwnedBy({ clubId, ownerUserId });

  const { page, limit } = query;
  const skip = (page - 1) * limit;

  const where: Prisma.ClubWaitingListWhereInput = {
    clubId,
    status: { in: ['PENDING', 'NOTIFIED'] },
  };

  const [rows, total] = await Promise.all([
    prisma.clubWaitingList.findMany({
      where,
      include: {
        user: {
          select: {
            id: true,
            name: true,
            email: true,
            phoneNumber: true,
            profile: {
              select: {
                profileAvatar: true,
              },
            },
          },
        },
      },
      orderBy: { createdAt: 'asc' },
      skip,
      take: limit,
    }),
    prisma.clubWaitingList.count({ where }),
  ]);

  const data = await Promise.all(
    rows.map((row) => mapOwnerWaitingListEntry({ row }))
  );

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

/**
 * Owner notifies a single waiting-list entry → status NOTIFIED + CLUB_SEAT_AVAILABLE push.
 */
export const notifyWaitingListEntryService = async ({
  ownerUserId,
  entryId,
}: INotifyWaitingListEntryService) => {
  const entry = await prisma.clubWaitingList.findUnique({
    where: { id: entryId },
    include: {
      club: {
        select: {
          id: true,
          name: true,
          userId: true,
          deactivatedAt: true,
        },
      },
      user: {
        select: {
          id: true,
          name: true,
          email: true,
          phoneNumber: true,
          profile: {
            select: { profileAvatar: true },
          },
        },
      },
    },
  });

  if (!entry || entry.club.deactivatedAt !== null) {
    throw { statusCode: 404, message: 'Waiting list entry not found' };
  }

  if (entry.club.userId !== ownerUserId) {
    throw { statusCode: 403, message: 'You do not own this club' };
  }

  if (entry.status === 'CANCELLED') {
    throw { statusCode: 404, message: 'Waiting list entry not found' };
  }

  let updated = entry;

  if (entry.status === 'PENDING') {
    updated = await prisma.$transaction(async (tx) => {
      // Unique is (userId, clubId, status) — clear any prior NOTIFIED row first.
      await tx.clubWaitingList.deleteMany({
        where: {
          userId: entry.userId,
          clubId: entry.clubId,
          status: 'NOTIFIED',
          NOT: { id: entry.id },
        },
      });

      return tx.clubWaitingList.update({
        where: { id: entry.id },
        data: {
          status: 'NOTIFIED',
          notifiedAt: new Date(),
        },
        include: {
          club: {
            select: {
              id: true,
              name: true,
              userId: true,
              deactivatedAt: true,
            },
          },
          user: {
            select: {
              id: true,
              name: true,
              email: true,
              phoneNumber: true,
              profile: {
                select: { profileAvatar: true },
              },
            },
          },
        },
      });
    });

    await sendPushNotification({
      userIds: [entry.userId],
      notificationType: 'CLUB_SEAT_AVAILABLE',
      title: 'Table Available!',
      description: `A table just opened up at ${entry.club.name}. Book now before it's gone!`,
      metaData: { clubId: entry.clubId },
    });
  }

  return mapOwnerWaitingListEntry({ row: updated });
};

/**
 * Owner removes a waiting-list entry.
 */
export const deleteWaitingListEntryService = async ({
  ownerUserId,
  entryId,
}: IDeleteWaitingListEntryService) => {
  const entry = await prisma.clubWaitingList.findUnique({
    where: { id: entryId },
    include: {
      club: {
        select: {
          id: true,
          userId: true,
          deactivatedAt: true,
        },
      },
    },
  });

  if (!entry || entry.club.deactivatedAt !== null) {
    throw { statusCode: 404, message: 'Waiting list entry not found' };
  }

  if (entry.club.userId !== ownerUserId) {
    throw { statusCode: 403, message: 'You do not own this club' };
  }

  await prisma.clubWaitingList.delete({
    where: { id: entryId },
  });

  return { message: 'Waiting list entry deleted successfully' };
};
