import prisma from '@/app/configs/db.configs';
import { mapArtist } from '@/app/modules/artists/artists.helpers';
import { TMyArtistsQuery } from '@/app/modules/artists/artists.schema';

export const followArtistService = async ({
  userId,
  artistId,
}: {
  userId: string;
  artistId: string;
}) => {
  const artist = await prisma.artist.findUnique({ where: { id: artistId } });
  if (!artist) {
    throw { statusCode: 404, message: 'Artist not found' };
  }

  const existing = await prisma.artistFollower.findUnique({
    where: { userId_artistId: { userId, artistId } },
  });

  if (!existing) {
    await prisma.$transaction([
      prisma.artistFollower.create({
        data: { userId, artistId },
      }),
      prisma.artist.update({
        where: { id: artistId },
        data: { followerCount: { increment: 1 } },
      }),
    ]);
  }

  return { isFollowing: true };
};

export const unfollowArtistService = async ({
  userId,
  artistId,
}: {
  userId: string;
  artistId: string;
}) => {
  const existing = await prisma.artistFollower.findUnique({
    where: { userId_artistId: { userId, artistId } },
  });

  if (existing) {
    await prisma.$transaction([
      prisma.artistFollower.delete({ where: { id: existing.id } }),
      prisma.artist.update({
        where: { id: artistId },
        data: {
          followerCount: { decrement: 1 },
        },
      }),
    ]);

    await prisma.artist.updateMany({
      where: { id: artistId, followerCount: { lt: 0 } },
      data: { followerCount: 0 },
    });
  }

  return { isFollowing: false };
};

export const getMyArtistsService = async ({
  userId,
  query,
}: {
  userId: string;
  query: TMyArtistsQuery;
}) => {
  const { page, limit } = query;
  const skip = (page - 1) * limit;

  const where = { userId };

  const [rows, total] = await Promise.all([
    prisma.artistFollower.findMany({
      where,
      include: { artist: true },
      orderBy: { createdAt: 'desc' },
      skip,
      take: limit,
    }),
    prisma.artistFollower.count({ where }),
  ]);

  return {
    meta: {
      page,
      limit,
      total,
      totalPages: Math.ceil(total / limit) || 1,
    },
    data: rows.map((row) => mapArtist(row.artist)),
  };
};
