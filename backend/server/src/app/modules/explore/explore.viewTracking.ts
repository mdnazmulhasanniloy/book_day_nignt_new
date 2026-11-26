import prisma from '@/app/configs/db.configs';
import { getRedisClient } from '@/app/configs/redis.configs';
import logger from '@/app/configs/logger.configs';
import { ITrackEventView } from '@/app/modules/explore/explore.types';

/**
 * View tracking for GET /explore/:id?type=EVENT (T-041, CR-11).
 *
 * Hot-row rule (data-model.md migration 11): the request path never writes
 * EventViewDaily or Event.viewCount. It only does a Redis HINCRBY on a per-day
 * hash; the worker job `flush-event-views` moves the counts to Postgres.
 * Key format is shared with `backend/worker/.../flushEventViews.job.ts`: keep
 * the two in step.
 */
export const EVENT_VIEWS_KEY_PREFIX = 'views:';
/** Keys must not pile up when the flush job is not running (for example after a rollback). */
export const EVENT_VIEWS_TTL_SECONDS = 3 * 24 * 60 * 60;
/** Personal "recently viewed" list length per user (client answer Q6c). */
export const RECENT_EVENT_VIEWS_LIMIT = 20;

/** UTC calendar day, the bucket of the Redis hash and of EventViewDaily.day (open question: day boundary). */
export const eventViewsDayKey = (now: Date): string =>
  `${EVENT_VIEWS_KEY_PREFIX}${now.toISOString().slice(0, 10)}`;

const countView = async ({ eventId, now }: { eventId: string; now: Date }): Promise<void> => {
  const redis = getRedisClient();
  const key = eventViewsDayKey(now);
  await redis.hincrby(key, eventId, 1);
  await redis.expire(key, EVENT_VIEWS_TTL_SECONDS);
};

const recordRecentView = async ({ eventId, userId, now }: { eventId: string; userId: string; now: Date }): Promise<void> => {
  await prisma.userRecentEventView.upsert({
    where: { userId_eventId: { userId, eventId } },
    create: { userId, eventId, lastViewedAt: now },
    update: { lastViewedAt: now },
  });
  const stale = await prisma.userRecentEventView.findMany({
    where: { userId },
    orderBy: [{ lastViewedAt: 'desc' }, { id: 'desc' }],
    skip: RECENT_EVENT_VIEWS_LIMIT,
    select: { id: true },
  });
  if (stale.length > 0) {
    await prisma.userRecentEventView.deleteMany({ where: { id: { in: stale.map((r) => r.id) } } });
  }
};

/**
 * Best effort and fire and forget: the caller must not await it, and it never
 * throws. A Redis or database failure drops that view (logged), the response is
 * unaffected. Call only for an existing, active, non-canceled event.
 */
export const trackEventView = ({ eventId, userId, now = new Date() }: ITrackEventView): void => {
  void countView({ eventId, now }).catch((error) => {
    logger.warn(`[viewTracking] view dropped for event ${eventId}: ${String(error)}`);
  });
  if (userId) {
    void recordRecentView({ eventId, userId, now }).catch((error) => {
      logger.warn(`[viewTracking] recent view dropped for event ${eventId}: ${String(error)}`);
    });
  }
};
