import prisma from '@/app/configs/db.configs';
import {
  ICreateClubService,
  IUpdateClubService,
  IGetClubListService,
  IGetClubDetailService,
} from '@/app/modules/club/club.types';
import { ILightweightExploreItem } from '@/app/modules/explore/explore.types';
import { Club, Prisma } from '@prisma/client';
import { TAdminClubListQuery } from '@/app/modules/club/club.schema';
import { sendPushNotification, getUsersNearby } from '@/app/modules/notification/notification.helpers';

/**
 * Service for creating a Club.
 * Executes a transaction to insert the Club, set its PostGIS geography,
 * and populate nested relations for opening hours and packages.
 * @returns Promise<Club>
 */
export const createClubService = async ({
  userId,
  payload,
}: ICreateClubService): Promise<Club> => {
  const { openingHours, packages, socialLinks, ...clubData } = payload;

  if (packages && packages.length > 1) {
    const firstCurrency = packages[0].currency;
    const hasMixedCurrency = packages.some(
      (pkg) => pkg.currency !== firstCurrency
    );
    if (hasMixedCurrency) {
      throw {
        status: 422,
        message: 'All packages within a club must have the same currency',
      };
    }
  }

  const club = await prisma.$transaction(async (tx) => {
    // 1. Create the base Club record
    const newClub = await tx.club.create({
      data: {
        ...clubData,
        socialLinks: (socialLinks as Prisma.InputJsonValue) ?? Prisma.JsonNull,
        userId,
      },
    });

    // 2. Set the PostGIS geography point using raw SQL
    await tx.$executeRaw`
      UPDATE "Club" 
      SET geog = ST_SetSRID(ST_MakePoint(${clubData.lng}, ${clubData.lat}), 4326)::geography 
      WHERE id = ${newClub.id}
    `;

    // 3. Create Opening Hours
    if (openingHours && openingHours.length > 0) {
      const hoursData = openingHours.map((hour) => ({
        ...hour,
        clubId: newClub.id,
      }));
      await tx.clubOpeningHour.createMany({
        data: hoursData,
      });
    }

    // 4. Create Packages
    if (packages && packages.length > 0) {
      const packageData = packages.map((pkg) => ({
        ...pkg,
        clubId: newClub.id,
      }));
      await tx.clubPackage.createMany({
        data: packageData,
      });
    }

    return newClub;
  });

  // 5. Notify users within 5 km — fire-and-forget, must not block the response
  void notifyNearbyUsersOfNewClub({ club, creatorUserId: userId });

  return club;
};


// --- Post-creation: notify nearby users ---
const notifyNearbyUsersOfNewClub = async ({
  club,
  creatorUserId,
}: {
  club: Club;
  creatorUserId: string;
}) => {
  try {
    const nearbyUserIds = await getUsersNearby({
      lat: club.lat,
      lng: club.lng,
      radiusKm: 5,
      excludeUserId: creatorUserId,
    });

    if (nearbyUserIds.length === 0) return;

    const CHUNK = 500;
    for (let i = 0; i < nearbyUserIds.length; i += CHUNK) {
      const chunk = nearbyUserIds.slice(i, i + CHUNK);
      await sendPushNotification({
        userIds: chunk,
        notificationType: 'NEW_CLUB',
        title: 'New Club Near You! 🎶',
        description: `'${club.name}' just opened nearby. Check it out!`,
        metaData: { clubId: club.id },
      });
      await sendPushNotification({
        userIds: chunk,
        notificationType: 'NEW_CLUB_NEARBY',
        title: 'Club Nearby 📍',
        description: `A new club '${club.name}' is now available within 5 km of you!`,
        metaData: { clubId: club.id },
      });
    }
  } catch (err) {
    const { default: logger } = await import('@/app/configs/logger.configs');
    logger.error('[createClubService] Failed to send nearby notifications', err);
  }
};

/**
 * Service for updating a Club.
 * Validates ownership, updates the Club, updates the PostGIS geography if location changed,
 * and upserts opening hours + packages within a transaction.
 *
 * Packages remove rule: isActive:false → hard-delete if unused, else deactivate.
 * Omitted packages are left untouched.
 * Opening hours: id → update that row; no id → upsert by clubId + dayOfWeek.
 */
export const updateClubService = async ({
  clubId,
  userId,
  payload,
}: IUpdateClubService): Promise<Club> => {
  const { openingHours, packages, socialLinks, isActive, ...clubData } =
    payload;

  if (packages && packages.length > 1) {
    const active = packages.filter((pkg) => pkg.isActive !== false);
    if (active.length > 1) {
      const firstCurrency = active[0].currency;
      const hasMixedCurrency = active.some(
        (pkg) => pkg.currency !== firstCurrency
      );
      if (hasMixedCurrency) {
        throw {
          statusCode: 422,
          message: 'All packages within a club must have the same currency',
        };
      }
    }
  }

  // Verify ownership and existence
  await prisma.club.findUniqueOrThrow({
    where: { id: clubId, userId },
  });

  let deactivatedAt: Date | null | undefined = undefined;
  if (isActive === false) {
    deactivatedAt = new Date();
  } else if (isActive === true) {
    deactivatedAt = null;
  }

  return await prisma.$transaction(async (tx) => {
    // 1. Update the base Club record
    const updatedClub = await tx.club.update({
      where: { id: clubId },
      data: {
        ...clubData,
        ...(deactivatedAt !== undefined && { deactivatedAt }),
        ...(socialLinks !== undefined && {
          socialLinks: (socialLinks as Prisma.InputJsonValue) ?? Prisma.JsonNull,
        }),
      },
    });

    // 2. Update PostGIS geography point if lat/lng changed
    if (clubData.lat !== undefined && clubData.lng !== undefined) {
      await tx.$executeRaw`
        UPDATE "Club" 
        SET geog = ST_SetSRID(ST_MakePoint(${clubData.lng}, ${clubData.lat}), 4326)::geography 
        WHERE id = ${clubId}
      `;
    }

    // 3. Upsert Opening Hours (id optional; fallback clubId + dayOfWeek)
    if (openingHours && openingHours.length > 0) {
      for (const hour of openingHours) {
        const { id, ...hourData } = hour;

        if (id) {
          const existing = await tx.clubOpeningHour.findFirst({
            where: { id, clubId },
            select: { id: true },
          });
          if (!existing) {
            throw {
              statusCode: 404,
              message: `Opening hour not found: ${id}`,
            };
          }
          await tx.clubOpeningHour.update({
            where: { id },
            data: hourData,
          });
          continue;
        }

        await tx.clubOpeningHour.upsert({
          where: {
            clubId_dayOfWeek: {
              clubId,
              dayOfWeek: hourData.dayOfWeek,
            },
          },
          create: {
            ...hourData,
            clubId,
          },
          update: hourData,
        });
      }
    }

    // 4. Upsert Packages (no id = create; id = update; isActive false = remove)
    if (packages && packages.length > 0) {
      for (const pkg of packages) {
        const { id, isActive: packageIsActive = true, ...pkgData } = pkg;

        if (!id) {
          if (packageIsActive === false) {
            // New row marked removed — nothing to create.
            continue;
          }
          await tx.clubPackage.create({
            data: {
              ...pkgData,
              isActive: true,
              clubId,
            },
          });
          continue;
        }

        const existing = await tx.clubPackage.findFirst({
          where: { id, clubId },
          select: { id: true },
        });
        if (!existing) {
          throw {
            statusCode: 404,
            message: `Package not found: ${id}`,
          };
        }

        if (packageIsActive === false) {
          const bookingCount = await tx.clubBooking.count({
            where: { clubPackageId: id },
          });
          if (bookingCount === 0) {
            await tx.clubPackage.delete({ where: { id } });
          } else {
            await tx.clubPackage.update({
              where: { id },
              data: { isActive: false },
            });
          }
          continue;
        }

        await tx.clubPackage.update({
          where: { id },
          data: {
            ...pkgData,
            isActive: true,
          },
        });
      }
    }

    return updatedClub;
  });
};

/**
 * Service for fetching a paginated list of Clubs belonging to an owner.
 * @returns Promise<{ data: Club[], total: number }>
 */
export const getClubListService = async ({
  userId,
  query,
}: IGetClubListService) => {
  const { page, limit, isActive } = query;
  const skip = (page - 1) * limit;

  const where: Prisma.ClubWhereInput = { userId };
  if (isActive !== undefined) {
    where.deactivatedAt = isActive ? null : { not: null };
  }

  const [total, data] = await prisma.$transaction([
    prisma.club.count({ where }),
    prisma.club.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      skip,
      take: limit,
      include: {
        clubPackages: {
          where: { isActive: true },
          select: { price: true, currency: true },
        },
        reviews: {
          select: { rating: true },
        },
        wishlists: {
          where: { userId },
          select: { id: true },
        },
      },
    }),
  ]);

  const mappedData: ILightweightExploreItem[] = data.map((club) => {
    let minPrice = 0;
    let maxPrice = 0;
    let currency = '';

    if (club.clubPackages.length > 0) {
      const prices = club.clubPackages.map((p) => Number(p.price));
      minPrice = Math.min(...prices);
      maxPrice = Math.max(...prices);
      currency = club.clubPackages[0].currency;
    }

    let review = 0;
    if (club.reviews.length > 0) {
      review =
        club.reviews.reduce((acc, r) => acc + r.rating, 0) /
        club.reviews.length;
    }

    return {
      id: club.id,
      name: club.name,
      lat: club.lat,
      lng: club.lng,
      location: club.location,
      type: 'CLUB',
      review,
      isVip: club.isVip,
      thumbnail: club.thumbnail,
      priceRange: { minPrice, maxPrice },
      currency,
      isWishlist: club.wishlists.length > 0,
    };
  });

  return { data: mappedData, total };
};

/**
 * Service for fetching full details of a specific Club belonging to an owner.
 * @returns Promise<Club>
 */
export const getClubDetailService = async ({
  clubId,
  userId,
}: IGetClubDetailService) => {
  return await prisma.club.findUniqueOrThrow({
    where: { id: clubId, userId },
    include: {
      clubOpeningHours: true,
      clubPackages: {
        orderBy: { sortOrder: 'asc' },
      },
    },
  });
};

/**
 * This service function is used to retrieve all clubs for admin.
 * @param query - Pagination parameters for filtering and sorting.
 * @returns Promise<void>
 */
export const retrieveClubsForAdminService = async ({
  query,
}: {
  query: TAdminClubListQuery;
}) => {
  try {
    const page = Number(query.page || 1);
    const limit = Number(query.limit || 10);
    const isActive = query.isActive;
    const skip = (page - 1) * limit;

    const whereCondition: Prisma.ClubWhereInput = {};
    if (isActive !== undefined) {
      if (isActive) {
        whereCondition.deactivatedAt = null;
      } else {
        whereCondition.deactivatedAt = { not: null };
      }
    }

    const [clubs, total] = await prisma.$transaction([
      prisma.club.findMany({
        where: whereCondition,
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
        include: {
          clubPackages: {
            take: 1,
            orderBy: { price: 'asc' },
          },
        },
      }),
      prisma.club.count({ where: whereCondition }),
    ]);

    const data = clubs.map(club => {
      const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      const d = club.createdAt;
      let hours = d.getHours();
      const ampm = hours >= 12 ? 'PM' : 'AM';
      hours = hours % 12;
      hours = hours ? hours : 12;
      const dateAndTime = `${d.getDate()} ${monthNames[d.getMonth()]}, ${hours} ${ampm}`;
      
      const firstPackage = club.clubPackages.length > 0 ? club.clubPackages[0] : null;

      return {
        id: club.id,
        name: club.name,
        description: club.description,
        thumbnail: club.thumbnail,
        images: club.images,
        dateAndTime,
        table: firstPackage ? firstPackage.name : '-',
        country: club.location,
        price: firstPackage ? Number(firstPackage.price) : 0,
        currency: firstPackage ? firstPackage.currency : 'EUR',
        isActive: club.deactivatedAt === null,
        deactivatedAt: club.deactivatedAt,
        createdAt: club.createdAt,
      };
    });

    return { data, total, page, limit };
  } catch (error) {
    throw error;
  }
};

export const closeClubBookingsService = async ({
  userId,
  clubId,
  closed,
}: {
  userId: string;
  clubId: string;
  closed: boolean;
}) => {
  const club = await prisma.club.findUnique({
    where: { id: clubId },
    select: { id: true, userId: true, deactivatedAt: true },
  });

  if (!club || club.deactivatedAt !== null) {
    throw { statusCode: 404, message: 'Club not found' };
  }
  if (club.userId !== userId) {
    throw { statusCode: 403, message: 'You do not own this club' };
  }

  return prisma.club.update({
    where: { id: clubId },
    data: { bookingsClosed: closed },
    select: { id: true, bookingsClosed: true },
  });
};
