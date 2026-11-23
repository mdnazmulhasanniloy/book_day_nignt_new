import { Prisma } from '@prisma/client';
import prisma from '@/app/configs/db.configs';

/**
 * Ranking rules of sort=trending and GET /explore/most-viewed (T-042, CR-11, client answer Q6c).
 * The weights and rules below are OUR proposal (the client asked us to document them) and are
 * listed as an open question; the formula is documented in api-spec.yaml and data-model.md.
 *
 * - Windows are whole UTC days that END with the UTC day of `now` (today included):
 *   7 days for trending, 30 days for most viewed.
 * - trending score = views in the 7 day window + Interested taps (EventInterest.createdAt) in the
 *   same window, weight 1 each. Ties: startAt ASC, then id ASC.
 * - most viewed score = views in the 30 day window. Events with 0 views are left out.
 *   Ties: startAt ASC, then id ASC.
 * - Views come from EventViewDaily. Until history exists (no EventViewDaily row on or before the
 *   first day of the window) the lifetime Event.viewCount is used instead (migration 11 rule).
 */
export const TRENDING_WINDOW_DAYS = 7;
export const MOST_VIEWED_WINDOW_DAYS = 30;
/** Same hard cap as the recent-views table (T-041). */
export const MOST_VIEWED_MAX_LIMIT = 20;

/** First UTC day (YYYY-MM-DD) of a window of `days` UTC days that ends with the day of `now`. */
export const rankingWindowStartDay = ({ now, days }: { now: Date; days: number }): string => {
  const start = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()) - (days - 1) * 86_400_000);
  return start.toISOString().slice(0, 10);
};

export interface IViewsWindow {
  startDay: string;
  startAt: Date;
  /** True while less history than the window exists: use the lifetime Event.viewCount. */
  useLifetime: boolean;
}

export const resolveViewsWindow = async ({ now, days }: { now: Date; days: number }): Promise<IViewsWindow> => {
  const startDay = rankingWindowStartDay({ now, days });
  const startAt = new Date(`${startDay}T00:00:00Z`);
  const oldest = await prisma.eventViewDaily.aggregate({ _min: { day: true } });
  const first = oldest._min.day;
  return { startDay, startAt, useLifetime: first === null || first > startAt };
};

/** Views of event alias e for the window (SQL bigint). */
export const viewsExpr = ({ window }: { window: IViewsWindow }): Prisma.Sql =>
  window.useLifetime
    ? Prisma.sql`e."viewCount"::bigint`
    : Prisma.sql`COALESCE((SELECT SUM(v."views") FROM "EventViewDaily" v WHERE v."eventId" = e.id AND v."day" >= ${window.startDay}::date), 0)::bigint`;

/** Interested taps of event alias e inside the window (SQL bigint). */
export const interestedExpr = ({ window }: { window: IViewsWindow }): Prisma.Sql =>
  Prisma.sql`(SELECT COUNT(*) FROM "EventInterest" i WHERE i."eventId" = e.id AND i."createdAt" >= ${window.startAt})::bigint`;
