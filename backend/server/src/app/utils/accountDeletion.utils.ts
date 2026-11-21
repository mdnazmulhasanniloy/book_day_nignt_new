import { AccountStatus, Prisma } from '@prisma/client';

type Tx = Prisma.TransactionClient;

/**
 * Soft-delete side effects shared by self-delete and admin-delete.
 * Caller must set user.accountStatus = DELETED in the same transaction.
 */
export const applySoftDeleteSideEffects = async (
  tx: Tx,
  userId: string,
  now: Date = new Date()
): Promise<void> => {
  await tx.device.updateMany({
    where: { userId },
    data: {
      fcmToken: null,
      isActive: false,
      isLogout: true,
    },
  });

  await tx.notification.deleteMany({ where: { userId } });
  await tx.wishlist.deleteMany({ where: { userId } });
  await tx.clubWaitingList.deleteMany({ where: { userId } });

  const clubFollows = await tx.clubFollower.findMany({
    where: { userId },
    select: { clubId: true },
  });
  if (clubFollows.length > 0) {
    await tx.clubFollower.deleteMany({ where: { userId } });
    await Promise.all(
      clubFollows.map((f) =>
        tx.club.update({
          where: { id: f.clubId },
          data: { followerCount: { decrement: 1 } },
        })
      )
    );
    const clubIds = [...new Set(clubFollows.map((f) => f.clubId))];
    await tx.club.updateMany({
      where: { id: { in: clubIds }, followerCount: { lt: 0 } },
      data: { followerCount: 0 },
    });
  }

  const artistFollows = await tx.artistFollower.findMany({
    where: { userId },
    select: { artistId: true },
  });
  if (artistFollows.length > 0) {
    await tx.artistFollower.deleteMany({ where: { userId } });
    await Promise.all(
      artistFollows.map((f) =>
        tx.artist.update({
          where: { id: f.artistId },
          data: { followerCount: { decrement: 1 } },
        })
      )
    );
    const artistIds = [...new Set(artistFollows.map((f) => f.artistId))];
    await tx.artist.updateMany({
      where: { id: { in: artistIds }, followerCount: { lt: 0 } },
      data: { followerCount: 0 },
    });
  }

  await tx.club.updateMany({
    where: { userId, deactivatedAt: null },
    data: { deactivatedAt: now, bookingsClosed: true },
  });

  await tx.event.updateMany({
    where: { userId, deactivatedAt: null },
    data: { deactivatedAt: now, bookingsClosed: true },
  });

  await tx.vipHost.updateMany({
    where: { ownerUserId: userId, isActive: true },
    data: { isActive: false },
  });
};

export const markUserDeleted = async (tx: Tx, userId: string): Promise<void> => {
  await tx.user.update({
    where: { id: userId },
    data: { accountStatus: AccountStatus.DELETED },
  });
};
