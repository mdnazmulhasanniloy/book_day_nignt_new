import prisma from '@/app/configs/db.configs';
import {
  IFollowClubParams,
  IUnfollowClubParams,
  IIsFollowingParams,
  IGetUserFollowingParams,
} from '@/app/modules/follow/follow.types';

/**
 * Service to follow a club/organizer.
 * Idempotently creates ClubFollower and increments club.followerCount.
 */
export const followClubService = async ({
  userId,
  clubId,
}: IFollowClubParams): Promise<{ isFollowing: boolean }> => {
  const club = await prisma.club.findFirst({
    where: { id: clubId, deactivatedAt: null },
  });

  if (!club) {
    throw { statusCode: 404, message: 'Club not found or deactivated' };
  }

  const existing = await prisma.clubFollower.findUnique({
    where: {
      userId_clubId: {
        userId,
        clubId,
      },
    },
  });

  if (!existing) {
    await prisma.$transaction([
      prisma.clubFollower.create({
        data: {
          userId,
          clubId,
        },
      }),
      prisma.club.update({
        where: { id: clubId },
        data: {
          followerCount: { increment: 1 },
        },
      }),
    ]);
  }

  return { isFollowing: true };
};

/**
 * Service to unfollow a club/organizer.
 * Deletes ClubFollower and decrements club.followerCount (not below 0).
 */
export const unfollowClubService = async ({
  userId,
  clubId,
}: IUnfollowClubParams): Promise<{ isFollowing: boolean }> => {
  const existing = await prisma.clubFollower.findUnique({
    where: {
      userId_clubId: {
        userId,
        clubId,
      },
    },
  });

  if (existing) {
    await prisma.$transaction([
      prisma.clubFollower.delete({
        where: { id: existing.id },
      }),
      prisma.club.update({
        where: { id: clubId },
        data: {
          followerCount: { decrement: 1 },
        },
      }),
    ]);
  }

  return { isFollowing: false };
};

/**
 * Service to check if the user is following a club.
 */
export const isFollowingClubService = async ({
  userId,
  clubId,
}: IIsFollowingParams): Promise<{ isFollowing: boolean }> => {
  const existing = await prisma.clubFollower.findUnique({
    where: {
      userId_clubId: {
        userId,
        clubId,
      },
    },
  });

  return { isFollowing: !!existing };
};

/**
 * Service to retrieve clubs followed by the current user.
 */
export const getUserFollowingService = async ({
  userId,
  page,
  limit,
}: IGetUserFollowingParams) => {
  const skip = (page - 1) * limit;

  const [follows, total] = await Promise.all([
    prisma.clubFollower.findMany({
      where: { userId, club: { deactivatedAt: null } },
      include: {
        club: {
          select: {
            id: true,
            name: true,
            thumbnail: true,
            location: true,
            followerCount: true,
            rulesAndVibe: true,
            isVip: true,
          },
        },
      },
      orderBy: { createdAt: 'desc' },
      skip,
      take: limit,
    }),
    prisma.clubFollower.count({
      where: { userId, club: { deactivatedAt: null } },
    }),
  ]);

  return {
    meta: {
      page,
      limit,
      total,
      totalPages: Math.ceil(total / limit),
    },
    data: follows.map((f) => f.club),
  };
};
