import { describe, it } from 'node:test';
import assert from 'node:assert/strict';

// T-041: the cron tick only enqueues; the worker does the flush. No Redis is
// opened (the queue is a recorder). Env defaults exist only so the config
// modules load; nothing connects.
process.env.NODE_ENV ??= 'test';
process.env.DATABASE_URL ??= 'postgresql://unused:unused@localhost:1/unused';
process.env.REDIS_HOST ??= 'localhost';
process.env.REDIS_PASSWORD ??= 'unused';
process.env.REDIS_PORT ??= '6379';

type Mod = typeof import('@/app/jobs/flushEventViews/flushEventViews.tasks');

describe('flushEventViews cron task (T-041)', () => {
  it('runs every minute and is a valid ICronJob', async () => {
    const mod: Mod = await import('@/app/jobs/flushEventViews/flushEventViews.tasks');
    assert.equal(mod.default.name, 'flushEventViews');
    assert.equal(mod.default.schedule, '* * * * *');
    assert.equal(typeof mod.default.execute, 'function');
  });

  it('enqueues flush-event-views with a deterministic per-minute jobId', async () => {
    const mod: Mod = await import('@/app/jobs/flushEventViews/flushEventViews.tasks');
    const calls: { name: string; opts: { jobId: string } }[] = [];
    const queue = {
      add: async (name: string, _data: object, opts: { jobId: string; removeOnComplete: boolean; removeOnFail: boolean }) => {
        calls.push({ name, opts });
      },
    };
    const t = new Date('2026-11-23T10:15:42.000Z');
    await mod.enqueueFlushEventViews({ queue, now: t });
    await mod.enqueueFlushEventViews({ queue, now: new Date('2026-11-23T10:15:59.999Z') });
    await mod.enqueueFlushEventViews({ queue, now: new Date('2026-11-23T10:16:00.000Z') });
    assert.deepEqual(calls.map((c) => c.name), ['flush-event-views', 'flush-event-views', 'flush-event-views']);
    assert.equal(calls[0].opts.jobId, 'flush-event-views-202611231015');
    assert.equal(calls[1].opts.jobId, calls[0].opts.jobId, 'same minute, same id');
    assert.notEqual(calls[2].opts.jobId, calls[0].opts.jobId);
    assert.ok(!calls[0].opts.jobId.includes(':'), 'BullMQ custom ids cannot contain a colon');
  });
});
