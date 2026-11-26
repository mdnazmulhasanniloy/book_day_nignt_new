import { Job } from 'bullmq';
import { IJobHandler } from '@/app/@types/queue.types';
import { IFlushEventViews } from '@/app/queues/system/system.types';
import { QUEUE_JOBS } from '@/const';
import prisma from '@/app/configs/db.configs';
import logger from '@/app/configs/logger.configs';
import { getRedisClient } from '@/app/configs/redis.configs';

/**
 * Moves the Redis view counters to Postgres (T-041, CR-11).
 *
 * The server only does `HINCRBY views:<yyyy-mm-dd UTC> <eventId> 1` on
 * GET /explore/:id (key format shared with `explore.viewTracking.ts` in the
 * server package; keep the two in step). Every minute the scheduler enqueues
 * this job; for each day hash (today and the two days before, the 3 day TTL
 * window) it:
 *   1. drains a leftover `views:flushing:<day>` key from a crashed run;
 *   2. RENAMEs the live hash to `views:flushing:<day>` (atomic; views arriving
 *      afterwards open a fresh live hash and are picked up by the next run);
 *   3. reads it, upserts `EventViewDaily (eventId, day)` with
 *      `views = views + n` and `Event.viewCount = viewCount + n` in ONE
 *      transaction, then deletes the processing key.
 * Running it twice does not double count: after a run the counts are gone from
 * Redis. Known small window: a crash after the database commit but before the
 * DEL re-applies that day's batch once (at least once, never lost). Events
 * that no longer exist are skipped.
 */
export const EVENT_VIEWS_KEY_PREFIX = 'views:';
const PROCESSING_PREFIX = 'views:flushing:';
/** Same window as the key TTL (3 days): today and the two days before. */
const DAYS_BACK = 2;

/** The Redis commands the flush needs (ioredis satisfies this). */
export interface IFlushRedis {
  rename(from: string, to: string): Promise<unknown>;
  hgetall(key: string): Promise<Record<string, string>>;
  del(...keys: string[]): Promise<unknown>;
}

const utcDay = (now: Date, daysBack: number): string =>
  new Date(now.getTime() - daysBack * 86_400_000).toISOString().slice(0, 10);

const applyBatch = async (day: string, hash: Record<string, string>): Promise<number> => {
  const ids: string[] = [];
  const counts: number[] = [];
  for (const [eventId, raw] of Object.entries(hash)) {
    const n = Number(raw);
    if (!Number.isInteger(n) || n <= 0) continue;
    ids.push(eventId);
    counts.push(n);
  }
  if (ids.length === 0) return 0;
  await prisma.$transaction([
    prisma.$executeRaw`
      INSERT INTO "EventViewDaily" ("eventId", "day", "views")
      SELECT e."id", ${day}::date, v."n"
      FROM unnest(${ids}::text[], ${counts}::int[]) AS v("id", "n")
      JOIN "Event" e ON e."id" = v."id"
      ON CONFLICT ("eventId", "day")
      DO UPDATE SET "views" = "EventViewDaily"."views" + EXCLUDED."views"`,
    prisma.$executeRaw`
      UPDATE "Event" e
      SET "viewCount" = e."viewCount" + v."n"
      FROM unnest(${ids}::text[], ${counts}::int[]) AS v("id", "n")
      WHERE e."id" = v."id"`,
  ]);
  return ids.length;
};

const drain = async (redis: IFlushRedis, day: string, processingKey: string): Promise<number> => {
  const hash = await redis.hgetall(processingKey);
  if (Object.keys(hash).length === 0) return 0;
  const written = await applyBatch(day, hash);
  await redis.del(processingKey);
  return written;
};

export const flushEventViews = async ({
  redis,
  now = new Date(),
}: {
  redis: IFlushRedis;
  now?: Date;
}): Promise<number> => {
  let events = 0;
  for (let back = 0; back <= DAYS_BACK; back++) {
    const day = utcDay(now, back);
    const liveKey = `${EVENT_VIEWS_KEY_PREFIX}${day}`;
    const processingKey = `${PROCESSING_PREFIX}${day}`;

    events += await drain(redis, day, processingKey); // crashed earlier run
    try {
      await redis.rename(liveKey, processingKey);
    } catch (error) {
      if (/no such key/i.test(String(error))) continue; // nothing viewed that day
      throw error;
    }
    events += await drain(redis, day, processingKey);
  }
  return events;
};

const handler: IJobHandler<IFlushEventViews> = {
  name: QUEUE_JOBS.FLUSH_EVENT_VIEWS,
  handler: async (_data: IFlushEventViews, _job: Job) => {
    const events = await flushEventViews({ redis: getRedisClient() });
    if (events > 0) logger.info(`[flushEventViews] flushed views of ${events} event-day counters`);
  },
};

export default handler;
