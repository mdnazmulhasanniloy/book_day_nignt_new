import { ICronJob } from '@/app/@types/job.types';
import { getSystemQueue } from '@/app/queues/system/system.queue';
import { QUEUE_JOBS } from '@/const';

/** Deterministic per UTC minute: two scheduler instances (B-12) enqueue the same id, BullMQ keeps one. */
export const flushEventViewsJobId = (now: Date): string =>
  `flush-event-views-${now.toISOString().slice(0, 16).replace(/[-:T]/g, '')}`;

interface IJobQueue {
  add(name: string, data: object, opts: { jobId: string; removeOnComplete: boolean; removeOnFail: boolean }): Promise<unknown>;
}

/**
 * T-041: producer only. The worker job `flush-event-views` does the Redis
 * read-and-clear and the database upsert; the scheduler only enqueues it.
 */
export const enqueueFlushEventViews = async ({
  queue,
  now = new Date(),
}: {
  queue: IJobQueue;
  now?: Date;
}): Promise<void> => {
  await queue.add(
    QUEUE_JOBS.FLUSH_EVENT_VIEWS,
    {},
    { jobId: flushEventViewsJobId(now), removeOnComplete: true, removeOnFail: false }
  );
};

const flushEventViewsJob: ICronJob = {
  name: 'flushEventViews',
  schedule: '* * * * *',
  execute: async () => {
    await enqueueFlushEventViews({ queue: getSystemQueue() });
  },
};

export default flushEventViewsJob;
