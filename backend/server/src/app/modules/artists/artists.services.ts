import { Artist, Prisma } from '@prisma/client';
import prisma from '@/app/configs/db.configs';
import {
  artistNameKey,
  mapArtist,
  mapArtistProfile,
  TUpcomingEventItem,
} from '@/app/modules/artists/artists.helpers';
import {
  TAdminListArtistsQuery,
  TAdminUpdateArtistBody,
  TListArtistsQuery,
  TMyArtistsQuery,
  TOwnerUpdateArtistBody,
} from '@/app/modules/artists/artists.schema';
import { resolveExploreCentre } from '@/app/modules/explore/explore.services';

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

// ---------------------------------------------------------------------------
// T-044 (CR-12): list, profile, owner edit, admin list and edit.
// ---------------------------------------------------------------------------

const ARTIST_NOT_FOUND = 'Artist not found';
const UPCOMING_EVENTS_LIMIT = 20;

const notFound = () => ({ statusCode: 404, message: ARTIST_NOT_FOUND });
const nameExists = () => ({
  statusCode: 409,
  message: 'Artist name already exists',
  errorType: 'ARTIST_NAME_EXISTS',
});

/**
 * A caller id may be absent (anonymous) but never empty: an empty id would make Prisma drop the
 * filter and leak another user's data.
 */
const assertUserId = ({ userId }: { userId: string | undefined }) => {
  if (userId !== undefined && userId.trim() === '') {
    throw new Error('userId must not be empty');
  }
};

const escapeLike = (value: string) => value.replace(/[\\%_]/g, (c) => `\\${c}`);

/** Same predicate as GET /explore type=EVENT: active, UPCOMING and not yet ended. */
const upcomingEventWhere = ({ now }: { now: Date }) =>
  ({
    deactivatedAt: null,
    eventStatus: 'UPCOMING',
    endAt: { gt: now },
  }) satisfies Prisma.EventWhereInput;

const followedSet = async ({
  userId,
  artistIds,
}: {
  userId: string;
  artistIds: string[];
}) => {
  if (artistIds.length === 0) return new Set<string>();
  const rows = await prisma.artistFollower.findMany({
    where: { userId, artistId: { in: artistIds } },
    select: { artistId: true },
  });
  return new Set(rows.map((r) => r.artistId));
};

const paging = ({ page, limit }: { page: string; limit: string }) => {
  const p = Number(page);
  const l = Number(limit);
  return { page: p, limit: l, skip: (p - 1) * l };
};

const pageMeta = ({
  page,
  limit,
  total,
}: {
  page: number;
  limit: number;
  total: number;
}) => ({
  page,
  limit,
  total,
  totalPages: Math.ceil(total / limit) || 1,
});

/**
 * GET /artists: artists linked to at least one upcoming event, sorted by upcoming event count, then
 * name. Optional city filter (same centre and default radius as GET /explore). `isFollowing` only
 * when a token user id is given.
 */
export const listArtistsService = async ({
  query,
  userId,
  now = new Date(),
}: {
  query: TListArtistsQuery;
  userId?: string;
  now?: Date;
}) => {
  assertUserId({ userId });
  const { page, limit, skip } = paging(query);
  const { centre, radiusMetres } = await resolveExploreCentre({
    cityId: query.cityId,
    needsZone: false,
  });

  const conds: Prisma.Sql[] = [
    Prisma.sql`e."deactivatedAt" IS NULL`,
    Prisma.sql`e."eventStatus" = 'UPCOMING'`,
    Prisma.sql`e."endAt" > ${now}`,
  ];
  if (query.search) {
    conds.push(Prisma.sql`a."name" ILIKE ${`%${escapeLike(query.search)}%`}`);
  }
  if (centre) {
    conds.push(
      Prisma.sql`ST_DWithin(e.geog, ST_SetSRID(ST_MakePoint(${centre.lng}, ${centre.lat}), 4326)::geography, ${radiusMetres})`
    );
  }
  const from = Prisma.sql`FROM "Artist" a
    JOIN "EventLineup" l ON l."artistId" = a.id
    JOIN "Event" e ON e.id = l."eventId"
    WHERE ${Prisma.join(conds, ' AND ')}`;

  const [rows, totalRows] = await Promise.all([
    prisma.$queryRaw<{ id: string; n: number }[]>`
      SELECT a.id, COUNT(DISTINCT e.id)::int AS n ${from}
      GROUP BY a.id, a.name
      ORDER BY n DESC, a.name ASC, a.id ASC
      LIMIT ${limit} OFFSET ${skip}`,
    prisma.$queryRaw<{ count: bigint }[]>`SELECT COUNT(DISTINCT a.id) AS count ${from}`,
  ]);
  const total = Number(totalRows[0]?.count ?? 0);

  const artists = await prisma.artist.findMany({
    where: { id: { in: rows.map((r) => r.id) } },
  });
  const byId = new Map(artists.map((a) => [a.id, a]));
  const followed = userId
    ? await followedSet({ userId, artistIds: rows.map((r) => r.id) })
    : undefined;

  const data = rows.flatMap((row) => {
    const artist = byId.get(row.id);
    if (!artist) return [];
    return [
      mapArtistProfile(artist, {
        upcomingEventCount: row.n,
        ...(followed ? { isFollowing: followed.has(artist.id) } : {}),
      }),
    ];
  });
  return { data, meta: pageMeta({ page, limit, total }) };
};

const upcomingEventsFor = async ({
  artistId,
  now,
}: {
  artistId: string;
  now: Date;
}): Promise<TUpcomingEventItem[]> => {
  const events = await prisma.event.findMany({
    where: { ...upcomingEventWhere({ now }), lineup: { some: { artistId } } },
    orderBy: [{ startAt: 'asc' }, { id: 'asc' }],
    take: UPCOMING_EVENTS_LIMIT,
    select: {
      id: true,
      eventName: true,
      lat: true,
      lng: true,
      location: true,
      thumbnail: true,
      currency: true,
      eventPrice: true,
      startAt: true,
    },
  });
  return events.map((e) => ({
    id: e.id,
    name: e.eventName,
    lat: e.lat,
    lng: e.lng,
    location: e.location,
    type: 'EVENT' as const,
    thumbnail: e.thumbnail,
    currency: e.currency,
    price: Number(e.eventPrice),
    startAt: e.startAt,
  }));
};

const buildProfile = async ({
  artist,
  userId,
  now = new Date(),
}: {
  artist: Artist;
  userId?: string;
  now?: Date;
}) => {
  assertUserId({ userId });
  const upcomingEvents = await upcomingEventsFor({ artistId: artist.id, now });
  const followed = userId
    ? await followedSet({ userId, artistIds: [artist.id] })
    : undefined;
  return mapArtistProfile(artist, {
    upcomingEvents,
    ...(followed ? { isFollowing: followed.has(artist.id) } : {}),
  });
};

/** GET /artists/{id}: any existing artist. `isFollowing` only when a token user id is given. */
export const getArtistProfileService = async ({
  artistId,
  userId,
}: {
  artistId: string;
  userId?: string;
}) => {
  assertUserId({ userId });
  const artist = await prisma.artist.findUnique({ where: { id: artistId } });
  if (!artist) throw notFound();
  return buildProfile({ artist, userId });
};

const profileData = (
  body: TOwnerUpdateArtistBody
): Prisma.ArtistUpdateInput => ({
  ...(body.photo !== undefined ? { avatar: body.photo } : {}),
  ...(body.bio !== undefined ? { bio: body.bio } : {}),
  ...(body.spotifyUrl !== undefined ? { spotifyUrl: body.spotifyUrl } : {}),
  // socialLinks replaces the whole object; null clears the column.
  ...(body.socialLinks !== undefined
    ? { socialLinks: body.socialLinks === null ? Prisma.DbNull : body.socialLinks }
    : {}),
});

/**
 * PATCH /artists/{id} (club owner). The caller "manages" the artist only when they own an active
 * event (Event.userId = caller, not deactivated) whose lineup has this artist (EventLineup.artistId).
 * The "created the artist" rule is NOT implemented: Artist has no creator column. Not found and not
 * managed look the same (404) so artist ids cannot be probed.
 */
export const ownerUpdateArtistService = async ({
  userId,
  artistId,
  body,
}: {
  userId: string;
  artistId: string;
  body: TOwnerUpdateArtistBody;
}) => {
  if (typeof userId !== 'string' || userId.trim() === '') {
    throw new Error('userId is required');
  }
  const managed = await prisma.eventLineup.findFirst({
    where: { artistId, event: { userId, deactivatedAt: null } },
    select: { id: true },
  });
  if (!managed) throw notFound();

  const artist = await prisma.artist.update({
    where: { id: artistId },
    data: profileData(body),
  });
  return buildProfile({ artist, userId });
};

/** GET /admin/artists: every artist, sorted by name then id. */
export const adminListArtistsService = async ({
  query,
}: {
  query: TAdminListArtistsQuery;
}) => {
  const { page, limit, skip } = paging(query);
  const where: Prisma.ArtistWhereInput = {
    ...(query.search
      ? { name: { contains: query.search, mode: 'insensitive' } }
      : {}),
    ...(query.isVerified !== undefined ? { isVerified: query.isVerified } : {}),
  };
  const [rows, total] = await Promise.all([
    prisma.artist.findMany({
      where,
      orderBy: [{ name: 'asc' }, { id: 'asc' }],
      skip,
      take: limit,
    }),
    prisma.artist.count({ where }),
  ]);
  return {
    data: rows.map((a) => mapArtistProfile(a)),
    meta: pageMeta({ page, limit, total }),
  };
};

const errorCode = (error: unknown): unknown =>
  typeof error === 'object' && error !== null
    ? (error as { code?: unknown }).code
    : undefined;

/** PATCH /admin/artists/{id}: edit, rename (keeps nameKey in sync, 409 on a duplicate) and verify. */
export const adminUpdateArtistService = async ({
  artistId,
  body,
}: {
  artistId: string;
  body: TAdminUpdateArtistBody;
}) => {
  const existing = await prisma.artist.findUnique({
    where: { id: artistId },
    select: { id: true },
  });
  if (!existing) throw notFound();

  const data: Prisma.ArtistUpdateInput = { ...profileData(body) };
  if (body.isVerified !== undefined) data.isVerified = body.isVerified;
  if (body.name !== undefined) {
    const nameKey = artistNameKey(body.name);
    const clash = await prisma.artist.findFirst({
      where: { nameKey, id: { not: artistId } },
      select: { id: true },
    });
    if (clash) throw nameExists();
    data.name = body.name;
    data.nameKey = nameKey;
  }

  try {
    const artist = await prisma.artist.update({ where: { id: artistId }, data });
    return mapArtistProfile(artist);
  } catch (error) {
    if (errorCode(error) === 'P2002') throw nameExists();
    if (errorCode(error) === 'P2025') throw notFound();
    throw error;
  }
};
