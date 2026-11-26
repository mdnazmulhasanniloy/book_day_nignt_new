import { Prisma } from '@prisma/client';
import type { TExploreMapQuery } from '@/app/modules/explore/explore.schema';

/** Filter fields shared by GET /explore and GET /explore/map (T-038). */
export type ExploreFilterQuery = Omit<TExploreMapQuery, 'type'>;

/** True when the date filters need the city time zone (T-035). */
export const exploreNeedsZone = ({
  query,
  dayGrouping,
}: {
  query: Pick<ExploreFilterQuery, 'from' | 'to' | 'dateFilter'>;
  dayGrouping: boolean;
}): boolean =>
  dayGrouping || query.from !== undefined || query.to !== undefined || query.dateFilter === 'this_week';

/**
 * Single source of the WHERE/HAVING fragments for clubs (alias c) and events (alias e).
 * Used by GET /explore and GET /explore/map so list and map cannot disagree.
 */
export const buildExploreFilters = ({
  query,
  clock,
  centrePoint,
  radiusMetres,
  cityTimezone,
}: {
  query: ExploreFilterQuery;
  clock: Date;
  centrePoint?: Prisma.Sql;
  radiusMetres: number;
  cityTimezone?: string;
}) => {
  const {
    isVip,
    search,
    minPrice,
    maxPrice,
    date,
    dateFilter,
    isFree,
    genres,
    mood,
    categoryType,
    city,
    from,
    to,
    ratings,
  } = query;

  // Build Club Conditions
  const clubConditions: Prisma.Sql[] = [Prisma.sql`c."deactivatedAt" IS NULL`];
  
  if (centrePoint) {
    clubConditions.push(Prisma.sql`ST_DWithin(c.geog, ${centrePoint}, ${radiusMetres})`);
  }
  if (isVip !== undefined) {
    clubConditions.push(Prisma.sql`c."isVip" = ${isVip}`);
  }
  if (search) {
    clubConditions.push(Prisma.sql`c."name" ILIKE ${`%${search}%`}`);
  }
  if (minPrice !== undefined || maxPrice !== undefined) {
    const minP = minPrice ?? 0;
    const maxP = maxPrice ?? 999999999;
    clubConditions.push(Prisma.sql`
      EXISTS (
        SELECT 1 FROM "ClubPackage" cp 
        WHERE cp."clubId" = c.id 
        AND cp."isActive" = true 
        AND cp.price >= ${minP} 
        AND cp.price <= ${maxP}
      )
    `);
  }
  if (date) {
    const d = new Date(date);
    const dayOfWeek = d.getUTCDay();
    clubConditions.push(Prisma.sql`
      EXISTS (
        SELECT 1 FROM "ClubOpeningHour" coh 
        WHERE coh."clubId" = c.id 
        AND coh."dayOfWeek" = ${dayOfWeek} 
        AND coh."isClosed" = false
      )
    `);
  }

  const clubWhere = clubConditions.length ? Prisma.sql`WHERE ${Prisma.join(clubConditions, ' AND ')}` : Prisma.empty;
  const clubHaving = ratings ? Prisma.sql`HAVING COALESCE(AVG(r.rating), 0) >= ${ratings}` : Prisma.empty;

  // Build Event Conditions
  const eventConditions: Prisma.Sql[] = [
    Prisma.sql`e."deactivatedAt" IS NULL`,
    Prisma.sql`e."eventStatus" = 'UPCOMING'`,
    Prisma.sql`e."endAt" > ${clock}`
  ];
  
  if (centrePoint) {
    eventConditions.push(Prisma.sql`ST_DWithin(e.geog, ${centrePoint}, ${radiusMetres})`);
  }
  if (search) {
    eventConditions.push(Prisma.sql`e."eventName" ILIKE ${`%${search}%`}`);
  }
  if (minPrice !== undefined) {
    eventConditions.push(Prisma.sql`e."eventPrice" >= ${minPrice}`);
  }
  if (maxPrice !== undefined) {
    eventConditions.push(Prisma.sql`e."eventPrice" <= ${maxPrice}`);
  }
  if (date) {
    const d = new Date(date);
    eventConditions.push(Prisma.sql`e."startAt" <= ${d} AND e."endAt" >= ${d}`);
  }
  if (dateFilter && dateFilter !== 'this_week') {
    const now = clock;
    let filterStart: Date;
    let filterEnd: Date;

    if (dateFilter === 'today') {
      filterStart = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 0, 0, 0);
      filterEnd = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 59);
    } else if (dateFilter === 'tomorrow') {
      const tom = new Date(now.getTime() + 86400000);
      filterStart = new Date(tom.getFullYear(), tom.getMonth(), tom.getDate(), 0, 0, 0);
      filterEnd = new Date(tom.getFullYear(), tom.getMonth(), tom.getDate(), 23, 59, 59);
    } else if (dateFilter === 'this_weekend') {
      const day = now.getDay();
      const daysUntilFriday = (5 - day + 7) % 7;
      const friday = new Date(now.getTime() + daysUntilFriday * 86400000);
      filterStart = new Date(friday.getFullYear(), friday.getMonth(), friday.getDate(), 0, 0, 0);
      const sunday = new Date(filterStart.getTime() + 2 * 86400000);
      filterEnd = new Date(sunday.getFullYear(), sunday.getMonth(), sunday.getDate(), 23, 59, 59);
    } else {
      const day = now.getDay();
      const daysUntilNextFriday = ((5 - day + 7) % 7) + 7;
      const friday = new Date(now.getTime() + daysUntilNextFriday * 86400000);
      filterStart = new Date(friday.getFullYear(), friday.getMonth(), friday.getDate(), 0, 0, 0);
      const sunday = new Date(filterStart.getTime() + 2 * 86400000);
      filterEnd = new Date(sunday.getFullYear(), sunday.getMonth(), sunday.getDate(), 23, 59, 59);
    }

    eventConditions.push(Prisma.sql`e."startAt" <= ${filterEnd} AND e."endAt" >= ${filterStart}`);
  }
  // T-035: this_week, from and to compare the LOCAL calendar date of startAt (AT TIME ZONE, DST-safe).
  // Zone = the city zone when cityId is given, else the event's own zone (default UTC).
  const eventZone = cityTimezone !== undefined ? Prisma.sql`${cityTimezone}::text` : Prisma.sql`e."timezone"`;
  const localStartDate = Prisma.sql`((e."startAt" AT TIME ZONE 'UTC') AT TIME ZONE ${eventZone})::date`;
  if (dateFilter === 'this_week') {
    const weekStart = Prisma.sql`date_trunc('week', (${clock.toISOString()}::timestamptz AT TIME ZONE ${eventZone}))::date`;
    eventConditions.push(Prisma.sql`${localStartDate} >= ${weekStart} AND ${localStartDate} < ${weekStart} + 7`);
  }
  if (from !== undefined) {
    eventConditions.push(Prisma.sql`${localStartDate} >= ${from}::date`);
  }
  if (to !== undefined) {
    eventConditions.push(Prisma.sql`${localStartDate} <= ${to}::date`);
  }
  if (isFree === true) {
    eventConditions.push(Prisma.sql`e."eventPrice" = 0`);
  }
  if (categoryType) {
    eventConditions.push(Prisma.sql`e."categoryType" = ${categoryType}::"EventCategoryType"`);
  }
  if (genres) {
    const list = genres.split(',').map((g) => g.trim().toUpperCase()).filter(Boolean);
    if (list.length > 0) {
      eventConditions.push(Prisma.sql`e."musicGenres" && ${list}::text[]`);
    }
  }
  if (mood) {
    const list = mood
      .split(',')
      .map((m) => m.trim())
      .filter(Boolean);
    if (list.length > 0) {
      eventConditions.push(Prisma.sql`e."moodTags" && ${list}::text[]`);
    }
  }
  if (city) {
    eventConditions.push(Prisma.sql`e."location" ILIKE ${`%${city}%`}`);
    clubConditions.push(Prisma.sql`c."location" ILIKE ${`%${city}%`}`);
  }

  const eventWhere = eventConditions.length ? Prisma.sql`WHERE ${Prisma.join(eventConditions, ' AND ')}` : Prisma.empty;
  return { clubWhere, clubHaving, eventWhere };
};
