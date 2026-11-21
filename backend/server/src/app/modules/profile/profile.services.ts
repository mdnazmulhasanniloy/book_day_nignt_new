import prisma from '@/app/configs/db.configs';
import { getRedisClient } from '@/app/configs/redis.configs';
import { createRedisKey } from '@/app/utils/system.utils';
import {
  applySoftDeleteSideEffects,
  markUserDeleted,
} from '@/app/utils/accountDeletion.utils';
import { REDIS_PREFIXES } from '@/const';
import {
  IGetUserProfileService,
  IUpdateUserProfileService,
  IChangePasswordService,
  IDeleteAccountService,
  IGetDeletionPreviewService,
} from '@/app/modules/profile/profile.types';

/**
 * Service for fetching user profile.
 * Retrieves the user's core data and nested profile fields.
 * Returns the sanitized user record.
 * @returns Promise<Record<string, unknown>>
 */
export const getUserProfileService = async ({
  userId,
}: IGetUserProfileService): Promise<Record<string, unknown>> => {
  try {
    const user = await prisma.user.findUniqueOrThrow({
      where: { id: userId },
      include: { profile: true },
    });

    const { password: _password, ...userWithoutPassword } = user;
    return {
      user: {
        ...userWithoutPassword,
        registrationState: user.isVerified ? 'COMPLETE' : 'UNVERIFIED',
      },
    };
  } catch (error) {
    throw error;
  }
};

/**
 * Service for updating user profile.
 * Modifies the user's core fields and nested profile fields atomically via a transaction.
 * Returns the updated sanitized user record.
 * @returns Promise<Record<string, unknown>>
 */
export const updateUserProfileService = async ({
  userId,
  payload,
}: IUpdateUserProfileService): Promise<Record<string, unknown>> => {
  try {
    const { name, phoneNumber, ...profileData } = payload;

    // Convert dateOfBirth string to Date object if provided
    const parsedProfileData = {
      ...profileData,
      ...(profileData.dateOfBirth ? { dateOfBirth: new Date(profileData.dateOfBirth) } : {}),
    };

    const updatedUser = await prisma.$transaction(async (tx) => {
      // 1. Update User if User fields are provided
      if (name !== undefined || phoneNumber !== undefined) {
        await tx.user.update({
          where: { id: userId },
          data: {
            ...(name !== undefined && { name }),
            ...(phoneNumber !== undefined && { phoneNumber }),
          },
        });
      }

      // 2. Update Profile if Profile fields are provided
      if (Object.keys(parsedProfileData).length > 0) {
        await tx.profile.update({
          where: { userId },
          data: parsedProfileData,
        });
      }

      // 3. Fetch and return the combined result
      return await tx.user.findUniqueOrThrow({
        where: { id: userId },
        include: { profile: true },
      });
    });

    const { password: _password, ...userWithoutPassword } = updatedUser;
    return {
      user: userWithoutPassword,
    };
  } catch (error) {
    throw error;
  }
};

/**
 * Service for changing user password.
 * Hashes the new password and updates the user record.
 * @returns Promise<void>
 */
export const changePasswordService = async ({
  userId,
  payload,
}: IChangePasswordService): Promise<void> => {
  try {
    const { newPassword } = payload;
    const { hashPassword } = await import('@/app/utils/password.utils');
    const hashedPassword = await hashPassword(newPassword);

    await prisma.user.update({
      where: { id: userId },
      data: { password: hashedPassword },
    });
  } catch (error) {
    throw error;
  }
};

/**
 * Preview of soft-delete effects for the in-app confirmation screen.
 * Soft-delete keeps identity so admin can later restore ACTIVE access.
 */
export const getDeletionPreviewService = async ({
  userId,
}: IGetDeletionPreviewService) => {
  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: { id: true, accountRole: true, accountStatus: true },
  });

  if (!user || user.accountStatus === 'DELETED') {
    throw { statusCode: 404, message: 'Account not found' };
  }

  const [
    devicesCount,
    notificationsCount,
    wishlistsCount,
    clubFollowsCount,
    artistFollowsCount,
    waitingListsCount,
    reviewsCount,
    buyerPaidOrdersCount,
    sellerPaidOrdersCount,
    clubsCount,
    eventsCount,
    vipHostsCount,
  ] = await Promise.all([
    prisma.device.count({ where: { userId } }),
    prisma.notification.count({ where: { userId } }),
    prisma.wishlist.count({ where: { userId } }),
    prisma.clubFollower.count({ where: { userId } }),
    prisma.artistFollower.count({ where: { userId } }),
    prisma.clubWaitingList.count({ where: { userId } }),
    prisma.clubReview.count({ where: { userId } }),
    prisma.order.count({ where: { buyerUserId: userId, status: 'PAID' } }),
    prisma.order.count({ where: { sellerUserId: userId, status: 'PAID' } }),
    prisma.club.count({ where: { userId, deactivatedAt: null } }),
    prisma.event.count({ where: { userId, deactivatedAt: null } }),
    prisma.vipHost.count({ where: { ownerUserId: userId, isActive: true } }),
  ]);

  return {
    mode: 'SOFT_DELETE',
    canRestoreByAdmin: true,
    removed: [
      {
        key: 'appAccess',
        label: 'App login and API access',
        count: 1,
      },
      {
        key: 'sessionsAndPush',
        label: 'Active sessions and push notification tokens',
        count: devicesCount,
      },
      {
        key: 'notifications',
        label: 'In-app notifications',
        count: notificationsCount,
      },
      {
        key: 'wishlists',
        label: 'Wishlists',
        count: wishlistsCount,
      },
      {
        key: 'follows',
        label: 'Club and artist follows',
        count: clubFollowsCount + artistFollowsCount,
      },
      {
        key: 'waitingLists',
        label: 'Waiting-list entries',
        count: waitingListsCount,
      },
    ],
    hiddenOrDeactivated: [
      {
        key: 'ownedClubs',
        label: 'Your clubs (hidden from explore; can reopen after restore)',
        count: clubsCount,
      },
      {
        key: 'ownedEvents',
        label: 'Your events (hidden from explore; can reopen after restore)',
        count: eventsCount,
      },
      {
        key: 'vipHosts',
        label: 'VIP hosts you manage (set inactive)',
        count: vipHostsCount,
      },
    ],
    retained: [
      {
        key: 'profileIdentity',
        label:
          'Name, email, phone (kept so support can restore your account)',
        count: 1,
      },
      {
        key: 'buyerOrders',
        label: 'Completed ticket/table purchases and payment records',
        count: buyerPaidOrdersCount,
      },
      {
        key: 'sellerOrders',
        label: 'Orders sold through your clubs/events (legal/accounting)',
        count: sellerPaidOrdersCount,
      },
      {
        key: 'reviews',
        label: 'Club reviews you wrote (kept for venue history)',
        count: reviewsCount,
      },
    ],
    notes: [
      'This is a soft delete. You will immediately lose app access.',
      'Support/admin can restore your account later by setting status back to ACTIVE.',
      'Paid bookings and payment history are retained for legal and door operations.',
    ],
  };
};

/**
 * Soft-deletes the authenticated account (reversible by admin restore).
 * Clears sessions/FCM, removes personal preference data, hides owner listings.
 */
export const deleteAccountService = async ({
  userId,
  accessToken,
  tokenExp,
}: IDeleteAccountService) => {
  const user = await prisma.user.findUnique({ where: { id: userId } });
  if (!user || user.accountStatus === 'DELETED') {
    throw { statusCode: 404, message: 'Account not found' };
  }

  await prisma.$transaction(async (tx) => {
    await markUserDeleted(tx, userId);
    await applySoftDeleteSideEffects(tx, userId);
  });

  const redisClient = getRedisClient();
  await redisClient.del(createRedisKey(REDIS_PREFIXES.location, userId));

  if (accessToken && tokenExp) {
    const currentTime = Math.floor(Date.now() / 1000);
    const ttl = Math.floor(tokenExp - currentTime);
    if (ttl > 0) {
      await redisClient.set(
        createRedisKey(REDIS_PREFIXES.blacklist, accessToken),
        accessToken,
        'EX',
        ttl
      );
    }
  }

  return { deleted: true };
};
