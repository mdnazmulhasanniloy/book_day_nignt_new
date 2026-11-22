import type { Application } from 'express';
import type { AddressInfo } from 'node:net';
import Stripe from 'stripe';
import { getRedisClient, initializeRedis } from '@/app/configs/redis.configs';

/** In-memory stand-in for the ioredis methods the server uses. */
export class FakeRedis {
  private store = new Map<string, { v: string; exp?: number }>();
  private live(key: string) {
    const e = this.store.get(key);
    if (e?.exp && e.exp <= Date.now()) {
      this.store.delete(key);
      return undefined;
    }
    return e;
  }
  async get(key: string) {
    return this.live(key)?.v ?? null;
  }
  async set(key: string, value: string, mode?: string, ttl?: number) {
    this.store.set(key, {
      v: String(value),
      exp: mode === 'EX' && ttl ? Date.now() + ttl * 1000 : undefined,
    });
    return 'OK';
  }
  async del(...keys: string[]) {
    return keys.filter((k) => this.store.delete(k)).length;
  }
  async incr(key: string) {
    const n = Number(this.live(key)?.v ?? 0) + 1;
    this.store.set(key, { v: String(n), exp: this.store.get(key)?.exp });
    return n;
  }
  async expire(key: string, seconds: number) {
    const e = this.live(key);
    if (!e) return 0;
    e.exp = Date.now() + seconds * 1000;
    return 1;
  }
  async ttl(key: string) {
    const e = this.live(key);
    if (!e) return -2;
    return e.exp ? Math.ceil((e.exp - Date.now()) / 1000) : -1;
  }
}

/**
 * Makes `getRedisClient()` behave like FakeRedis for this test process.
 * The module export is a non-configurable getter (cannot be mocked), so we
 * initialise the real client (lazyConnect: no socket is opened) and override
 * its methods on the instance. Needs REDIS_* env like the other tests (.env).
 */
export const installFakeRedis = (): FakeRedis => {
  const fake = new FakeRedis();
  initializeRedis();
  const client = getRedisClient() as unknown as Record<string, unknown>;
  for (const m of ['get', 'set', 'del', 'incr', 'expire', 'ttl'] as const) {
    client[m] = fake[m].bind(fake);
  }
  return fake;
};

/** Records BullMQ-style `add()` calls so tests can assert on name and payload. */
export class FakeQueue {
  readonly jobs: { name: string; data: unknown; opts?: unknown }[] = [];
  async add(name: string, data: unknown, opts?: unknown) {
    this.jobs.push({ name, data, opts });
    return { id: String(this.jobs.length) };
  }
  find(name: string) {
    return this.jobs.filter((j) => j.name === name);
  }
}

/** Valid `stripe-signature` header for a raw payload. */
export const signStripePayload = (payload: string, secret: string): string =>
  new Stripe('sk_test_dummy').webhooks.generateTestHeaderString({
    payload,
    secret,
  });

/** Serves an Express app on an ephemeral port (no real app.ts side effects). */
export const startTestServer = async (app: Application) => {
  const server = app.listen(0, '127.0.0.1');
  await new Promise((r) => server.once('listening', r));
  const baseUrl = `http://127.0.0.1:${(server.address() as AddressInfo).port}`;
  return {
    baseUrl,
    close: () => new Promise<void>((r) => server.close(() => r())),
  };
};
