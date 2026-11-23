import { after, before, describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';

// T-041: the worker job that moves the Redis view counters to EventViewDaily and
// Event.viewCount. DB-backed (database named *_test or *_rehearsal only). No real
// Redis: a tiny in-memory hash store implements the three commands the job uses.
// Rows are read with raw SQL so this does not depend on the generated client models.

const testUrl = process.env.TEST_DATABASE_URL;
const safeName = (url: string): string => {
  const name = decodeURIComponent(new URL(url).pathname.replace(/^\//, ''));
  if (!/_(test|rehearsal)$/.test(name)) {
    throw new Error(`Refusing to run: database "${name}" must end in _test or _rehearsal`);
  }
  return url;
};
const skip = testUrl ? false : 'TEST_DATABASE_URL not set (needs a *_test or *_rehearsal database)';

class FakeHashRedis {
  hashes = new Map<string, Record<string, string>>();
  /** Runs right after a successful rename: simulates views arriving mid flush. */
  afterRename?: () => void;
  hincrby(key: string, field: string, by: number) {
    const h = this.hashes.get(key) ?? {};
    h[field] = String(Number(h[field] ?? 0) + by);
    this.hashes.set(key, h);
  }
  async rename(from: string, to: string) {
    const h = this.hashes.get(from);
    if (!h) throw new Error('ERR no such key');
    this.hashes.delete(from);
    this.hashes.set(to, h);
    this.afterRename?.();
    return 'OK';
  }
  async hgetall(key: string) {
    return { ...(this.hashes.get(key) ?? {}) };
  }
  async del(...keys: string[]) {
    return keys.filter((k) => this.hashes.delete(k)).length;
  }
}

type JobModule = typeof import('@/app/queues/system/jobs/flushEventViews.job');
type Db = typeof import('@/app/configs/db.configs');

const NOW = new Date('2026-11-23T10:00:00.000Z');
const TODAY = 'views:2026-11-23';
const YESTERDAY = 'views:2026-11-22';

describe('flush-event-views job (T-041)', { skip }, () => {
  let mod: JobModule;
  let db: Db['default'];
  let userId: string;
  const eventIds: string[] = [];

  const newEvent = async () => {
    const e = await db.event.create({
      data: {
        userId,
        eventName: 'T041 flush',
        thumbnail: 'https://example.test/t.png',
        lat: 1,
        lng: 1,
        startAt: new Date(Date.now() + 86_400_000),
        endAt: new Date(Date.now() + 2 * 86_400_000),
        dressCode: 'casual',
        eventPrice: 10,
        currency: 'USD',
      },
    });
    eventIds.push(e.id);
    return e.id;
  };
  const daily = async (eventId: string) =>
    db.$queryRaw<{ day: string; views: number }[]>`
      SELECT to_char("day", 'YYYY-MM-DD') AS day, "views" FROM "EventViewDaily"
      WHERE "eventId" = ${eventId} ORDER BY "day"`;
  const viewCount = async (eventId: string) =>
    (await db.$queryRaw<{ viewCount: number }[]>`SELECT "viewCount" FROM "Event" WHERE "id" = ${eventId}`)[0].viewCount;
  const flush = (redis: FakeHashRedis) => mod.flushEventViews({ redis, now: NOW });

  before(async () => {
    process.env.DATABASE_URL = safeName(testUrl as string);
    mod = await import('@/app/queues/system/jobs/flushEventViews.job');
    db = (await import('@/app/configs/db.configs')).default;
    const tag = randomUUID();
    userId = (
      await db.user.create({
        data: { name: 'T041', email: `t041-${tag}@example.test`, phoneNumber: `+1555${tag.slice(0, 7)}` },
      })
    ).id;
  });

  after(async () => {
    try {
      await db.event.deleteMany({ where: { id: { in: eventIds } } });
      await db.user.deleteMany({ where: { id: userId } });
    } finally {
      await db.$disconnect();
    }
  });

  it('is registered as the flush-event-views job', () => {
    assert.equal(mod.default.name, 'flush-event-views');
  });

  it('writes EventViewDaily and viewCount, clears the hash, and a second run changes nothing', async () => {
    const a = await newEvent();
    const b = await newEvent();
    const redis = new FakeHashRedis();
    for (let i = 0; i < 7; i++) redis.hincrby(TODAY, a, 1);
    for (let i = 0; i < 3; i++) redis.hincrby(TODAY, b, 1);

    await flush(redis);
    assert.deepEqual(await daily(a), [{ day: '2026-11-23', views: 7 }]);
    assert.deepEqual(await daily(b), [{ day: '2026-11-23', views: 3 }]);
    assert.equal(await viewCount(a), 7);
    assert.equal(await viewCount(b), 3);
    assert.equal(redis.hashes.size, 0, 'hash and processing key are gone');

    await flush(redis);
    assert.deepEqual(await daily(a), [{ day: '2026-11-23', views: 7 }]);
    assert.equal(await viewCount(a), 7);
  });

  it('adds to an existing row (views = views + n) and keeps days separate', async () => {
    const a = await newEvent();
    const redis = new FakeHashRedis();
    redis.hincrby(YESTERDAY, a, 2);
    redis.hincrby(TODAY, a, 5);
    await flush(redis);
    redis.hincrby(TODAY, a, 4);
    await flush(redis);
    assert.deepEqual(await daily(a), [
      { day: '2026-11-22', views: 2 },
      { day: '2026-11-23', views: 9 },
    ]);
    assert.equal(await viewCount(a), 11);
  });

  it('loses nothing when views arrive between the rename and the read', async () => {
    const a = await newEvent();
    const redis = new FakeHashRedis();
    redis.hincrby(TODAY, a, 5);
    let fired = false;
    redis.afterRename = () => {
      if (fired) return;
      fired = true;
      redis.hincrby(TODAY, a, 2); // lands in a fresh live hash
    };
    await flush(redis);
    assert.deepEqual(await daily(a), [{ day: '2026-11-23', views: 5 }]);
    assert.deepEqual(redis.hashes.get(TODAY), { [a]: '2' }, 'late views stay for the next run');
    await flush(redis);
    assert.deepEqual(await daily(a), [{ day: '2026-11-23', views: 7 }]);
    assert.equal(await viewCount(a), 7);
  });

  it('picks up a processing key left by a crashed run', async () => {
    const a = await newEvent();
    const redis = new FakeHashRedis();
    redis.hashes.set('views:flushing:2026-11-23', { [a]: '4' });
    redis.hincrby(TODAY, a, 1);
    await flush(redis);
    assert.deepEqual(await daily(a), [{ day: '2026-11-23', views: 5 }]);
    assert.equal(redis.hashes.size, 0);
  });

  it('skips unknown events and junk values without failing the rest', async () => {
    const a = await newEvent();
    const redis = new FakeHashRedis();
    redis.hincrby(TODAY, a, 2);
    redis.hincrby(TODAY, randomUUID(), 3); // event deleted since the view
    redis.hashes.get(TODAY)!['junk'] = 'abc';
    redis.hashes.get(TODAY)!['neg'] = '-4';
    await flush(redis);
    assert.deepEqual(await daily(a), [{ day: '2026-11-23', views: 2 }]);
    assert.equal(redis.hashes.size, 0);
  });

  it('does nothing when there is no hash', async () => {
    await flush(new FakeHashRedis());
  });
});
