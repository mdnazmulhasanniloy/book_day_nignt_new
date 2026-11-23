import { env } from '@/env';
import prisma from '@/app/configs/db.configs';
import {
  IExploreListService,
  IExploreDetailService,
  ILightweightExploreItem,
  IExploreFeedService,
  IExploreMapService,
  IExploreMapPin,
  IExploreClubEventsService,
  IExploreClubArtistsService,
} from '@/app/modules/explore/explore.types';
import { mapEventModule } from '@/app/modules/eventModule/eventModule.helpers';
import { buildPublicGuestListPayload } from '@/app/modules/guestList/guestList.helpers';
import { mapPublicVipHost } from '@/app/modules/hosts/hosts.helpers';
import { mapTicketTierTree } from '@/app/modules/event/event.ticketTier.helpers';
import {
  ensureArtistForLineup,
  mapArtist,
} from '@/app/modules/artists/artists.helpers';
import { Prisma } from '@prisma/client';
import { EXPLORE_DEFAULT_RADIUS_KM, EXPLORE_MAP_MAX_PINS } from '@/app/modules/explore/explore.schema';
import { buildExploreFilters, exploreNeedsZone } from '@/app/modules/explore/explore.filters';
import { groupItemsByDay } from '@/app/modules/explore/explore.grouping';
import { trackEventView } from '@/app/modules/explore/explore.viewTracking';

/**
 * Shared by GET /explore and GET /explore/feed (T-034, T-036).
 * Centre: lat/lng when both are given, otherwise the city centre when cityId is given (any City row,
 * launched or not). Unknown cityId throws 404. Radius: radiusKm or the server default (20 km).
 * cityTimezone is only loaded when needed (cityId given and a zone or centre is wanted).
 */
export const resolveExploreCentre = async ({
  lat,
  lng,
  cityId,
  radiusKm,
  needsZone,
}: {
  lat?: number;
  lng?: number;
  cityId?: string;
  radiusKm?: number;
  needsZone: boolean;
}) => {
  let centre: { lat: number; lng: number } | undefined;
  let cityTimezone: string | undefined;
  if (cityId !== undefined && (needsZone || lat === undefined || lng === undefined)) {
    const found = await prisma.city.findUnique({
      where: { id: cityId },
      select: { lat: true, lng: true, timezone: true },
    });
    if (!found) {
      throw { statusCode: 404, message: 'City not found', errorType: 'NOT_FOUND' };
    }
    cityTimezone = found.timezone;
    if (lat === undefined || lng === undefined) {
      centre = { lat: found.lat, lng: found.lng };
    }
  }
  if (lat !== undefined && lng !== undefined) {
    centre = { lat, lng };
  }
  const radiusMetres = (radiusKm ?? EXPLORE_DEFAULT_RADIUS_KM) * 1000;
  return { centre, cityTimezone, radiusMetres };
};

/**
 * Service for fetching a paginated list of Clubs and Events based on filters.
 * Utilizes complex PostGIS Raw SQL queries.
 * @returns Promise<{ data: ILightweightExploreItem[], total: number }>
 */
export const exploreListService = async ({ query, userId, now: clockOverride }: IExploreListService) => {
  const clock = clockOverride ?? new Date();
  const {
    type,
    lat,
    lng,
    isPopular,
    sort,
    dateFilter,
    radiusKm,
    cityId,
    group,
    from,
    to,
  } = query;
  const page = Number(query.page || 1);
  const limit = Number(query.limit || 10);
  const skip = (page - 1) * limit;

  const dayGrouping = group === 'day';
  const needsZone = exploreNeedsZone({ query, dayGrouping });

  const { centre, cityTimezone, radiusMetres } = await resolveExploreCentre({
    lat,
    lng,
    cityId,
    radiusKm,
    needsZone,
  });
  const centrePoint = centre
    ? Prisma.sql`ST_SetSRID(ST_MakePoint(${centre.lng}, ${centre.lat}), 4326)`
    : undefined;
  const clubDistance = centrePoint
    ? Prisma.sql`, ROUND((ST_Distance(c.geog, ${centrePoint}::geography) / 1000)::numeric, 1) as "distanceKm"`
    : Prisma.empty;
  const eventDistance = centrePoint
    ? Prisma.sql`, ROUND((ST_Distance(e.geog, ${centrePoint}::geography) / 1000)::numeric, 1) as "distanceKm"`
    : Prisma.empty;
  const selectDistance = centrePoint ? Prisma.sql`, "distanceKm"` : Prisma.empty;

  const { clubWhere, clubHaving, eventWhere } = buildExploreFilters({
    query,
    clock,
    centrePoint,
    radiusMetres,
    cityTimezone,
  });

  const wishlistSubqueryClub = userId
    ? Prisma.sql`, EXISTS(SELECT 1 FROM "Wishlist" w WHERE w."clubId" = c.id AND w."userId" = ${userId}) as "isWishlist"`
    : Prisma.empty;

  const wishlistSubqueryEvent = userId
    ? Prisma.sql`, EXISTS(SELECT 1 FROM "Wishlist" w WHERE w."eventId" = e.id AND w."userId" = ${userId}) as "isWishlist"`
    : Prisma.empty;

  const clubQuery = Prisma.sql`
    SELECT 
      c.id, c.name, c.lat, c.lng, c.location, 'CLUB' as "type",
      COALESCE(AVG(r.rating), 0) as review, c."createdAt",
      NULL::timestamp(3) as "startAt", NULL::text as "timeZone",
      c."isVip", c.thumbnail, 
      COALESCE((SELECT MIN(price) FROM "ClubPackage" WHERE "clubId" = c.id AND "isActive" = true), 0) as "minPrice",
      COALESCE((SELECT MAX(price) FROM "ClubPackage" WHERE "clubId" = c.id AND "isActive" = true), 0) as "maxPrice",
      (SELECT currency FROM "ClubPackage" WHERE "clubId" = c.id AND "isActive" = true LIMIT 1) as currency
      ${clubDistance}
      ${wishlistSubqueryClub}
    FROM "Club" c
    LEFT JOIN "ClubReview" r ON c.id = r."clubId"
    ${clubWhere}
    GROUP BY c.id
    ${clubHaving}
  `;

  const eventQuery = Prisma.sql`
    SELECT 
      e.id, e."eventName" as name, e.lat, e.lng, e.location, 'EVENT' as "type",
      0 as review, e."createdAt", e."startAt" as "startAt", e."timezone" as "timeZone",
      false as "isVip", e.thumbnail, 
      e."eventPrice" as "minPrice", 
      e."eventPrice" as "maxPrice", 
      e.currency
      ${eventDistance}
      ${wishlistSubqueryEvent}
    FROM "Event" e
    ${eventWhere}
  `;

  let combinedQuery: Prisma.Sql;
  if (type === 'CLUB') {
    combinedQuery = clubQuery;
  } else if (type === 'EVENT' || dayGrouping) {
    // group=day applies to events only: clubs have no start date.
    combinedQuery = eventQuery;
  } else {
    combinedQuery = Prisma.sql`
      ${clubQuery}
      UNION ALL
      ${eventQuery}
    `;
  }

  // Default order stays createdAt DESC for old clients. The chronological order by startAt (index
  // (eventStatus, startAt)) applies when a date feature is used: group=day, from, to or this_week.
  const chronological = dayGrouping || from !== undefined || to !== undefined || dateFilter === 'this_week';
  let orderBy = chronological
    ? Prisma.sql`ORDER BY "startAt" ASC NULLS LAST, "createdAt" DESC, id ASC`
    : Prisma.sql`ORDER BY "createdAt" DESC`;
  if (isPopular) {
    // Only applies effectively when type=CLUB or mixed, orders by review DESC
    orderBy = Prisma.sql`ORDER BY review DESC NULLS LAST, "createdAt" DESC`;
  } else if (sort === 'oldest') {
    orderBy = Prisma.sql`ORDER BY "createdAt" ASC`;
  } else if (sort === 'newest') {
    orderBy = Prisma.sql`ORDER BY "createdAt" DESC`;
  }

  // Count query
  const countResult = await prisma.$queryRaw<{ count: bigint }[]>`
    WITH combined AS (
      ${combinedQuery}
    )
    SELECT COUNT(*) as count FROM combined
  `;
  const total = Number(countResult[0]?.count || 0);

  const selectWishlist = userId ? Prisma.sql`, "isWishlist"` : Prisma.empty;

  const selectGroupColumns = dayGrouping ? Prisma.sql`, "startAt", "timeZone"` : Prisma.empty;

  // Data query
  const data = await prisma.$queryRaw<{ 
    id: string, name: string, lat: number, lng: number, location: string, type: "CLUB" | "EVENT",
    review: number, isVip: boolean, thumbnail: string, minPrice: number, maxPrice: number, currency: string,
    isWishlist?: boolean, distanceKm?: string | number | null, startAt?: Date | null, timeZone?: string | null
  }[]>`
    WITH combined AS (
      ${combinedQuery}
    )
    SELECT id, name, lat, lng, location, "type", review, "isVip", thumbnail, "minPrice", "maxPrice", currency${selectGroupColumns}${selectDistance}${selectWishlist} FROM combined
    ${orderBy}
    LIMIT ${limit} OFFSET ${skip}
  `;

  const formattedData: ILightweightExploreItem[] = data.map((item) => {
    const base: ILightweightExploreItem = {
      id: item.id,
      name: item.name,
      lat: Number(item.lat),
      lng: Number(item.lng),
      location: item.location,
      type: item.type,
      thumbnail: item.thumbnail,
      currency: item.currency || '',
    };

    if (userId !== undefined) {
      base.isWishlist = Boolean(item.isWishlist);
    }

    if (centre !== undefined && item.distanceKm !== undefined && item.distanceKm !== null) {
      base.distanceKm = Number(item.distanceKm);
    }

    if (item.type === 'CLUB') {
      return {
        ...base,
        review: Number(item.review),
        isVip: Boolean(item.isVip),
        priceRange: {
          minPrice: Number(item.minPrice),
          maxPrice: Number(item.maxPrice),
        },
      };
    } else {
      return {
        ...base,
        price: Number(item.minPrice), // minPrice acts as the price placeholder for Events
      };
    }
  });

  if (dayGrouping) {
    // Each item is bucketed by the local day of its start in the city zone (cityId) or its own zone.
    const wrapped = data.flatMap((row, i) => {
      const item = formattedData[i];
      if (!item || !row.startAt) return [];
      const startAt = new Date(row.startAt);
      return [{ startAt, timeZone: cityTimezone ?? row.timeZone ?? 'UTC', item: { ...item, startAt } }];
    });
    const groups = groupItemsByDay({ items: wrapped, now: clock }).map((g) => ({
      label: g.label,
      date: g.date,
      items: g.items.map((w) => w.item),
    }));
    // `data` stays the flat list (stable return type); the controller sends `groups` when present.
    return { data: formattedData, total, groups };
  }

  return { data: formattedData, total };
};

/**
 * GET /explore/map (T-038): lightweight pins for the same filters, centre and radius as GET /explore.
 * Filters come from buildExploreFilters (shared with exploreListService). No paging; at most
 * `maxPins` rows (default EXPLORE_MAP_MAX_PINS), nearest first when a centre exists, otherwise newest first.
 * meta.total is the full match count, so the client can tell when the map is truncated.
 */
export const exploreMapService = async ({ query, now: clockOverride, maxPins }: IExploreMapService) => {
  const clock = clockOverride ?? new Date();
  const cap = maxPins ?? EXPLORE_MAP_MAX_PINS;
  const { type, lat, lng, radiusKm, cityId } = query;

  const { centre, cityTimezone, radiusMetres } = await resolveExploreCentre({
    lat,
    lng,
    cityId,
    radiusKm,
    needsZone: exploreNeedsZone({ query, dayGrouping: false }),
  });
  const centrePoint = centre
    ? Prisma.sql`ST_SetSRID(ST_MakePoint(${centre.lng}, ${centre.lat}), 4326)`
    : undefined;
  const clubDistance = centrePoint
    ? Prisma.sql`, ROUND((ST_Distance(c.geog, ${centrePoint}::geography) / 1000)::numeric, 1) as "distanceKm"`
    : Prisma.empty;
  const eventDistance = centrePoint
    ? Prisma.sql`, ROUND((ST_Distance(e.geog, ${centrePoint}::geography) / 1000)::numeric, 1) as "distanceKm"`
    : Prisma.empty;
  const selectDistance = centrePoint ? Prisma.sql`, "distanceKm"` : Prisma.empty;

  const { clubWhere, clubHaving, eventWhere } = buildExploreFilters({
    query,
    clock,
    centrePoint,
    radiusMetres,
    cityTimezone,
  });

  // Same row sets as exploreListService, narrower columns. Club price-from is NULL without an active package.
  const combinedQuery =
    type === 'CLUB'
      ? Prisma.sql`
          SELECT
            c.id, c.name, c.lat, c.lng, 'CLUB' as "type", c.thumbnail, c."createdAt",
            NULL::timestamp(3) as "startAt",
            (SELECT MIN(price) FROM "ClubPackage" WHERE "clubId" = c.id AND "isActive" = true) as "minPrice"
            ${clubDistance}
          FROM "Club" c
          LEFT JOIN "ClubReview" r ON c.id = r."clubId"
          ${clubWhere}
          GROUP BY c.id
          ${clubHaving}
        `
      : Prisma.sql`
          SELECT
            e.id, e."eventName" as name, e.lat, e.lng, 'EVENT' as "type", e.thumbnail, e."createdAt",
            e."startAt" as "startAt", e."eventPrice" as "minPrice"
            ${eventDistance}
          FROM "Event" e
          ${eventWhere}
        `;

  const orderBy = centrePoint
    ? Prisma.sql`ORDER BY "distanceKm" ASC, "createdAt" DESC, id ASC`
    : Prisma.sql`ORDER BY "createdAt" DESC, id ASC`;

  const countResult = await prisma.$queryRaw<{ count: bigint }[]>`
    WITH combined AS (${combinedQuery})
    SELECT COUNT(*) as count FROM combined
  `;
  const total = Number(countResult[0]?.count || 0);

  const rows = await prisma.$queryRaw<{
    id: string;
    name: string;
    lat: number;
    lng: number;
    type: 'CLUB' | 'EVENT';
    thumbnail: string;
    startAt: Date | null;
    minPrice: string | number | null;
    distanceKm?: string | number | null;
  }[]>`
    WITH combined AS (${combinedQuery})
    SELECT id, name, lat, lng, "type", thumbnail, "startAt", "minPrice"${selectDistance} FROM combined
    ${orderBy}
    LIMIT ${cap}
  `;

  const data: IExploreMapPin[] = rows.map((row) => {
    const pin: IExploreMapPin = {
      id: row.id,
      type: row.type,
      name: row.name,
      lat: Number(row.lat),
      lng: Number(row.lng),
      startAt: row.startAt ? new Date(row.startAt).toISOString() : null,
      thumbnail: row.thumbnail,
      minPrice: row.minPrice === null || row.minPrice === undefined ? null : Number(row.minPrice),
    };
    if (centre !== undefined && row.distanceKm !== undefined && row.distanceKm !== null) {
      pin.distanceKm = Number(row.distanceKm);
    }
    return pin;
  });

  return {
    data,
    meta: { total, returned: data.length, maxPins: cap, truncated: total > data.length },
  };
};

/**
 * Service for fetching details of a specific Club or Event.
 * Returns aggregated reviews for Clubs.
 * @returns Promise<Record<string, unknown>>
 */
export const exploreDetailService = async ({ id, query, userId }: IExploreDetailService) => {
  if (query.type === 'CLUB') {
    const club = await prisma.club.findUnique({
      where: { id },
      include: {
        clubOpeningHours: true,
        clubPackages: {
          where: { isActive: true },
          orderBy: { sortOrder: 'asc' }
        },
        vipHosts: {
          where: { host: { isActive: true } },
          include: { host: true },
          orderBy: { createdAt: 'asc' },
        },
      }
    });

    if (!club || (club as Record<string, unknown>).deactivatedAt !== null) {
      return null;
    }

    const reviewAgg = await prisma.clubReview.aggregate({
      where: { clubId: id },
      _avg: { rating: true },
      _count: { id: true }
    });

    let isWishlist: boolean | undefined = undefined;
    let isFollowing: boolean | undefined = undefined;
    if (userId) {
      const [wishlistEntry, followEntry] = await Promise.all([
        prisma.wishlist.findUnique({
          where: { userId_clubId: { userId, clubId: id } }
        }),
        prisma.clubFollower.findUnique({
          where: { userId_clubId: { userId, clubId: id } }
        })
      ]);
      isWishlist = Boolean(wishlistEntry);
      isFollowing = Boolean(followEntry);
    }

    const {
      userId: ownerUserId,
      createdAt,
      updatedAt,
      vipHosts,
      ...restClub
    } = club;
    const publicClub = restClub as Record<string, unknown>;
    delete publicClub.deactivatedAt;
    delete publicClub.geog;

    return {
      ...publicClub,
      hosts: vipHosts.map((link) => mapPublicVipHost(link.host)),
      aggregateRating: reviewAgg._avg.rating || 0,
      totalReviews: reviewAgg._count.id || 0,
      ...(isWishlist !== undefined ? { isWishlist } : {}),
      ...(isFollowing !== undefined ? { isFollowing } : {}),
    };
  } else {
    const event = await prisma.event.findUnique({
      where: { id },
      include: {
        ticketTiers: {
          where: { isActive: true },
          orderBy: { sortOrder: 'asc' },
        },
        lineup: {
          orderBy: { sortOrder: 'asc' },
        },
        modules: {
          // Keep sold-out modules visible (status resolved via mapEventModule),
          // matching ticket-tier explore behavior so VIP section does not disappear.
          where: { isActive: true },
          orderBy: { sortOrder: 'asc' },
        },
        guestList: {
          include: {
            fallbacks: { orderBy: { sortOrder: 'asc' } },
          },
        },
        vipHosts: {
          where: { host: { isActive: true } },
          include: { host: true },
          orderBy: { createdAt: 'asc' },
        },
      },
    });

    if (!event || (event as Record<string, unknown>).deactivatedAt !== null) {
      return null;
    }

    // T-041: Redis counter (+ recent view for a logged-in user), never on the DB hot row.
    // Event.viewCount is increased by the worker flush, not per request. Canceled events are not counted.
    if (event.eventStatus !== 'CANCELED') {
      trackEventView({ eventId: id, userId });
    }

    let isWishlist: boolean | undefined = undefined;
    if (userId) {
      const wishlistEntry = await prisma.wishlist.findUnique({
        where: { userId_eventId: { userId, eventId: id } }
      });
      isWishlist = Boolean(wishlistEntry);
    }

    // CR-11 (T-040): live COUNT(*), caller own state only with a bearer token.
    const interestedCount = await prisma.eventInterest.count({ where: { eventId: id } });
    const isInterested = userId
      ? Boolean(await prisma.eventInterest.findUnique({ where: { userId_eventId: { userId, eventId: id } }, select: { id: true } }))
      : undefined;

    // Fetch organizer info
    const organizerClub = await prisma.club.findFirst({
      where: { userId: event.userId, deactivatedAt: null },
      select: {
        id: true,
        name: true,
        thumbnail: true,
        location: true,
        followerCount: true,
      },
    });

    const {
      userId: ownerUserId,
      createdAt,
      updatedAt,
      modules,
      guestList,
      vipHosts,
      ticketTiers,
      lineup,
      ...restEvent
    } = event;
    const publicEvent = restEvent as Record<string, unknown>;
    delete publicEvent.deactivatedAt;
    delete publicEvent.geog;

    const publicGuestList = await buildPublicGuestListPayload({
      guestList,
      event,
    });

    const publicLineup = [];
    for (const row of lineup) {
      let artistId = row.artistId;
      let artist = null;
      if (!artistId) {
        const ensured = await ensureArtistForLineup(prisma, row);
        artistId = ensured.id;
        artist = mapArtist(ensured);
        await prisma.eventLineup.update({
          where: { id: row.id },
          data: { artistId },
        });
      } else {
        artist = mapArtist(
          await prisma.artist.findUniqueOrThrow({ where: { id: artistId } })
        );
      }

      publicLineup.push({
        id: row.id,
        eventId: row.eventId,
        artistId,
        artistName: row.artistName,
        artistAvatar: row.artistAvatar,
        audioPreviewUrl: row.audioPreviewUrl,
        spotifyUrl: row.spotifyUrl,
        soundcloudUrl: row.soundcloudUrl,
        isVerified: row.isVerified,
        sortOrder: row.sortOrder,
        artist,
      });
    }

    return {
      ...publicEvent,
      ticketTiers: mapTicketTierTree(ticketTiers),
      lineup: publicLineup,
      modules: modules.map(mapEventModule),
      guestList: publicGuestList,
      hosts: vipHosts.map((link) => mapPublicVipHost(link.host)),
      organizer: organizerClub || {
        name: event.eventName,
        followerCount: 0,
      },
      ...(isWishlist !== undefined ? { isWishlist } : {}),
      interestedCount,
      ...(isInterested !== undefined ? { isInterested } : {}),
    };
  }
};

/**
 * Service to generate the aggregated "FOR YOU" home feed.
 */
export const exploreFeedService = async ({ query, userId: _userId }: IExploreFeedService) => {
  const { city, lat, lng, cityId, radiusKm } = query;
  const { centre, radiusMetres } = await resolveExploreCentre({ lat, lng, cityId, radiusKm, needsZone: false });
  const now = new Date();
  const startToday = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 0, 0, 0);
  const endToday = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 59);

  const tom = new Date(now.getTime() + 86400000);
  const startTom = new Date(tom.getFullYear(), tom.getMonth(), tom.getDate(), 0, 0, 0);
  const endTom = new Date(tom.getFullYear(), tom.getMonth(), tom.getDate(), 23, 59, 59);

  const cityFilter = city ? { location: { contains: city, mode: 'insensitive' as const } } : {};

  // With a centre (lat/lng or cityId) every module is limited to the radius (ST_DWithin on geog).
  // Without one nothing changes. Ids are resolved with raw SQL because Prisma cannot filter geography.
  let eventIdsInRadius: string[] | undefined;
  let clubIdsInRadius: string[] | undefined;
  if (centre) {
    const point = Prisma.sql`ST_SetSRID(ST_MakePoint(${centre.lng}, ${centre.lat}), 4326)`;
    const [eventRows, clubRows] = await Promise.all([
      prisma.$queryRaw<{ id: string }[]>`SELECT id FROM "Event" WHERE "deactivatedAt" IS NULL AND "eventStatus" = 'UPCOMING' AND geog IS NOT NULL AND ST_DWithin(geog, ${point}, ${radiusMetres})`,
      prisma.$queryRaw<{ id: string }[]>`SELECT id FROM "Club" WHERE "deactivatedAt" IS NULL AND geog IS NOT NULL AND ST_DWithin(geog, ${point}, ${radiusMetres})`,
    ]);
    eventIdsInRadius = eventRows.map((r) => r.id);
    clubIdsInRadius = clubRows.map((r) => r.id);
  }
  const eventRadius = eventIdsInRadius ? { id: { in: eventIdsInRadius } } : {};
  const clubRadius = clubIdsInRadius ? { id: { in: clubIdsInRadius } } : {};

  const [todayEvents, tomorrowEvents, blowingUpEvents, popularOrganizers, allGenresEvents] = await Promise.all([
    prisma.event.findMany({
      where: {
        deactivatedAt: null,
        eventStatus: 'UPCOMING',
        startAt: { lte: endToday },
        endAt: { gte: startToday },
        ...cityFilter,
        ...eventRadius,
      },
      select: {
        id: true,
        eventName: true,
        thumbnail: true,
        location: true,
        startAt: true,
        endAt: true,
        eventPrice: true,
        currency: true,
        musicGenres: true,
        categoryType: true,
      },
      take: 10,
      orderBy: { startAt: 'asc' },
    }),
    prisma.event.findMany({
      where: {
        deactivatedAt: null,
        eventStatus: 'UPCOMING',
        startAt: { lte: endTom },
        endAt: { gte: startTom },
        ...cityFilter,
        ...eventRadius,
      },
      select: {
        id: true,
        eventName: true,
        thumbnail: true,
        location: true,
        startAt: true,
        endAt: true,
        eventPrice: true,
        currency: true,
        musicGenres: true,
        categoryType: true,
      },
      take: 10,
      orderBy: { startAt: 'asc' },
    }),
    prisma.event.findMany({
      where: {
        deactivatedAt: null,
        eventStatus: 'UPCOMING',
        endAt: { gt: now },
        ...cityFilter,
        ...eventRadius,
      },
      select: {
        id: true,
        eventName: true,
        thumbnail: true,
        location: true,
        startAt: true,
        endAt: true,
        eventPrice: true,
        currency: true,
        musicGenres: true,
        categoryType: true,
        viewCount: true,
      },
      take: 10,
      orderBy: [{ viewCount: 'desc' }, { startAt: 'asc' }],
    }),
    prisma.club.findMany({
      where: {
        deactivatedAt: null,
        ...cityFilter,
        ...eventRadius,
        ...clubRadius,
      },
      select: {
        id: true,
        name: true,
        thumbnail: true,
        location: true,
        followerCount: true,
        rulesAndVibe: true,
      },
      take: 10,
      orderBy: { followerCount: 'desc' },
    }),
    prisma.event.findMany({
      where: {
        deactivatedAt: null,
        eventStatus: 'UPCOMING',
        endAt: { gt: now },
        ...eventRadius,
      },
      select: {
        musicGenres: true,
      },
    }),
  ]);

  const genreSet = new Set<string>();
  allGenresEvents.forEach((ev) => {
    ev.musicGenres.forEach((g) => genreSet.add(g));
  });

  return {
    today: todayEvents,
    tomorrow: tomorrowEvents,
    blowingUp: blowingUpEvents,
    popularOrganizers,
    genres: Array.from(genreSet),
  };
};

/**
 * Service to aggregate distinct music genres and event counts.
 */
export const exploreGenresService = async () => {
  const events = await prisma.event.findMany({
    where: {
      deactivatedAt: null,
      eventStatus: 'UPCOMING',
      endAt: { gt: new Date() },
    },
    select: { musicGenres: true },
  });

  const countMap: Record<string, number> = {};
  events.forEach((ev) => {
    ev.musicGenres.forEach((genre) => {
      countMap[genre] = (countMap[genre] || 0) + 1;
    });
  });

  const result = Object.entries(countMap).map(([genre, eventCount]) => ({
    genre,
    eventCount,
  }));

  result.sort((a, b) => b.eventCount - a.eventCount);

  return result;
};

/**
 * Service to fetch upcoming events hosted at a specific club.
 */
export const exploreClubUpcomingEventsService = async ({
  clubId,
  page,
  limit,
}: IExploreClubEventsService) => {
  const club = await prisma.club.findUnique({
    where: { id: clubId },
    select: { id: true, userId: true },
  });

  if (!club) {
    throw { statusCode: 404, message: 'Club not found' };
  }

  const skip = (page - 1) * limit;
  const where = {
    OR: [{ clubId: club.id }, { userId: club.userId }],
    eventStatus: 'UPCOMING' as const,
    endAt: { gt: new Date() },
    deactivatedAt: null,
  };

  const [data, total] = await Promise.all([
    prisma.event.findMany({
      where,
      select: {
        id: true,
        eventName: true,
        thumbnail: true,
        location: true,
        startAt: true,
        endAt: true,
        eventPrice: true,
        currency: true,
        categoryType: true,
        musicGenres: true,
      },
      orderBy: { startAt: 'asc' },
      skip,
      take: limit,
    }),
    prisma.event.count({ where }),
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

/**
 * Service to fetch past events archive hosted at a specific club.
 */
export const exploreClubPastEventsService = async ({
  clubId,
  page,
  limit,
}: IExploreClubEventsService) => {
  const club = await prisma.club.findUnique({
    where: { id: clubId },
    select: { id: true, userId: true },
  });

  if (!club) {
    throw { statusCode: 404, message: 'Club not found' };
  }

  const skip = (page - 1) * limit;
  const where = {
    OR: [{ clubId: club.id }, { userId: club.userId }],
    endAt: { lte: new Date() },
    deactivatedAt: null,
  };

  const [data, total] = await Promise.all([
    prisma.event.findMany({
      where,
      select: {
        id: true,
        eventName: true,
        thumbnail: true,
        location: true,
        startAt: true,
        endAt: true,
        eventPrice: true,
        currency: true,
        categoryType: true,
        musicGenres: true,
      },
      orderBy: { endAt: 'desc' },
      skip,
      take: limit,
    }),
    prisma.event.count({ where }),
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

/**
 * Service to fetch distinct resident and guest artists who have played at this club.
 */
export const exploreClubArtistsService = async ({
  clubId,
}: IExploreClubArtistsService) => {
  const club = await prisma.club.findUnique({
    where: { id: clubId },
    select: { userId: true },
  });

  if (!club) {
    throw { statusCode: 404, message: 'Club not found' };
  }

  const lineups = await prisma.eventLineup.findMany({
    where: {
      event: {
        userId: club.userId,
        deactivatedAt: null,
      },
    },
    select: {
      artistName: true,
      artistAvatar: true,
      isVerified: true,
      spotifyUrl: true,
      soundcloudUrl: true,
    },
    orderBy: { createdAt: 'desc' },
  });

  const uniqueArtists = Array.from(
    new Map(lineups.map((a) => [a.artistName.toLowerCase(), a])).values()
  );

  return uniqueArtists;
};

interface ISharePreviewData {
  name?: string;
  eventName?: string;
  description?: string | null;
  location?: string | null;
  thumbnail?: string | null;
  coverImage?: string | null;
}

export const getSharePreviewHtmlService = async ({ id, type }: { id: string, type: 'CLUB' | 'EVENT' }): Promise<string | null> => {
  const data = await exploreDetailService({ 
    id, 
    query: { type }, 
    userId: undefined 
  });

  if (!data) return null;
  const preview = data as unknown as ISharePreviewData;
  const name = String(preview.name || preview.eventName || 'BookDiaNight');
  const description = String(preview.description || 'Join us on BookDiaNight!');
  const location = String(preview.location || 'Dhaka, Bangladesh');
  const thumbnail = String(preview.thumbnail || preview.coverImage || '');
  const typeLabel = type === 'CLUB' ? 'Club' : 'Event';
  
  const shareUrl = `${env.SERVER_URL.replace(/\/+$/, '')}/explore/${type.toLowerCase()}/${id}`;
  const appSchemeUrl = `bookdianight://${type.toLowerCase()}/${id}`;

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover" />
 
  <title>${name} | BookDiaNight</title>
 
  <meta property="og:site_name" content="BookDiaNight" />
  <meta property="og:type" content="website" />
  <meta property="og:title" content="${name}" />
  <meta property="og:description" content="${description} · ${location}" />
  <meta property="og:url" content="${shareUrl}" />
  <meta property="og:image" content="${thumbnail}" />
  <meta property="og:image:alt" content="${name}" />
  <meta property="og:image:width" content="1200" />
  <meta property="og:image:height" content="630" />
 
  <meta name="twitter:card" content="summary_large_image" />
  <meta name="twitter:title" content="${name}" />
  <meta name="twitter:description" content="${description} · ${location}" />
  <meta name="twitter:image" content="${thumbnail}" />
 
  <meta name="theme-color" content="#0D0D0D" />
  <meta name="description" content="${description} · ${location}" />
 
  <style>
    :root {
      --bg: #070707;
      --card: #121212;
      --line: rgba(255, 255, 255, 0.08);
      --text: #ffffff;
      --muted: #9a9a9a;
      --gold: #e1b144;
      --gold-soft: rgba(225, 177, 68, 0.14);
    }
    * { box-sizing: border-box; }
    html, body {
      margin: 0; min-height: 100%; background: var(--bg); color: var(--text);
      font-family: Inter, system-ui, -apple-system, Segoe UI, Roboto, sans-serif;
      -webkit-font-smoothing: antialiased;
    }
    body {
      min-height: 100dvh; display: flex; align-items: center; justify-content: center;
      padding: 24px 16px 40px;
      background: radial-gradient(ellipse 80% 50% at 50% -10%, rgba(225, 177, 68, 0.18), transparent 55%), var(--bg);
    }
    .shell { width: 100%; max-width: 420px; }
    .brand {
      display: flex; align-items: center; justify-content: center;
      margin-bottom: 18px;
    }
    .brand img {
      display: block; height: 56px; width: auto; max-width: 180px; object-fit: contain;
    }
    .card {
      background: linear-gradient(180deg, #161616 0%, #101010 100%);
      border: 1px solid var(--line); border-radius: 24px; overflow: hidden;
      box-shadow: 0 24px 60px rgba(0, 0, 0, 0.45);
    }
    .cover-wrap {
      position: relative; aspect-ratio: 4 / 5; background: #1a1a1a; overflow: hidden;
    }
    .cover-wrap img { width: 100%; height: 100%; object-fit: cover; display: block; }
    .cover-fade {
      position: absolute; inset: auto 0 0 0; height: 42%;
      background: linear-gradient(to top, #101010 8%, transparent); pointer-events: none;
    }
    .badge-row { position: absolute; top: 14px; left: 14px; display: flex; flex-wrap: wrap; gap: 8px; z-index: 1; }
    .badge {
      padding: 6px 10px; border-radius: 999px; font-size: 11px; font-weight: 700;
      letter-spacing: 0.02em; background: rgba(0, 0, 0, 0.55);
      border: 1px solid rgba(255, 255, 255, 0.16); backdrop-filter: blur(8px);
    }
    .content { padding: 18px 18px 20px; }
    h1 { margin: 0 0 8px; font-size: 26px; line-height: 1.15; font-weight: 800; letter-spacing: -0.02em; }
    .meta { display: flex; align-items: flex-start; gap: 8px; color: var(--muted); font-size: 13px; line-height: 1.45; margin: 0 0 14px; }
    .meta svg { flex: 0 0 auto; margin-top: 2px; opacity: 0.85; }
    .desc {
      margin: 0 0 18px; color: #cfcfcf; font-size: 14px; line-height: 1.5;
      display: -webkit-box; -webkit-line-clamp: 3; -webkit-box-orient: vertical; overflow: hidden;
    }
    .actions { display: grid; gap: 10px; }
    .btn {
      display: flex; align-items: center; justify-content: center; min-height: 52px;
      border-radius: 14px; text-decoration: none; font-size: 15px; font-weight: 800;
      transition: transform 0.15s ease, opacity 0.15s ease;
    }
    .btn:active { transform: scale(0.98); }
    .btn-primary { background: var(--gold); color: #111; box-shadow: 0 10px 28px rgba(225, 177, 68, 0.28); }
    .footnote { margin-top: 14px; text-align: center; color: #6f6f6f; font-size: 12px; line-height: 1.4; }
  </style>
</head>
<body>
  <div class="shell">
    <div class="brand">
      <img src="https://bookdianight-storage.fra1.cdn.digitaloceanspaces.com/branding/bookdianight-logo.png" alt="BookDiaNight" />
    </div>
 
    <article class="card">
      <div class="cover-wrap">
        <div class="badge-row">
          <span class="badge">${typeLabel}</span>
        </div>
        <img src="${thumbnail}" alt="${name}" />
        <div class="cover-fade"></div>
      </div>
 
      <div class="content">
        <h1>${name}</h1>
 
        <p class="meta">
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" aria-hidden="true">
            <path d="M12 22s7-6.2 7-12a7 7 0 1 0-14 0c0 5.8 7 12 7 12Z" stroke="currentColor" stroke-width="1.8"/>
            <circle cx="12" cy="10" r="2.5" stroke="currentColor" stroke-width="1.8"/>
          </svg>
          <span>${location}</span>
        </p>
 
        <p class="desc">${description}</p>
 
        <div class="actions">
          <a class="btn btn-primary" href="${appSchemeUrl}">Open in BookDiaNight</a>
        </div>
      </div>
    </article>
 
    <p class="footnote">
      Opens the ${typeLabel.toLowerCase()} details in the BookDiaNight app.
    </p>
  </div>
 
  <script>
    (function () {
      var appUrl = "${appSchemeUrl}";
      if (!appUrl) return;
      var timer = setTimeout(function () {}, 1200);
      window.location.href = appUrl;
      clearTimeout(timer);
    })();
  </script>
</body>
</html>`;
};
