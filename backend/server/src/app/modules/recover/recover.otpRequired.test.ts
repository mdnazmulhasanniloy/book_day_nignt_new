import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import {
  clearRecoverVerified,
  isRecoverVerified,
  markRecoverVerified,
} from '@/app/modules/recover/recover.verified.helpers';

const fakeRedis = () => {
  const store = new Map<string, string>();
  return {
    store,
    set: async (k: string, v: string) => void store.set(k, v),
    get: async (k: string) => store.get(k) ?? null,
    del: async (k: string) => void store.delete(k),
  };
};

describe('recover reset requires OTP verification (BUG-S19)', () => {
  it('reset without verify: not verified', async () => {
    const redis = fakeRedis();
    assert.equal(await isRecoverVerified({ redis, userId: 'u1' }), false);
  });

  it('after verify: verified; after reset: marker cleared (single use)', async () => {
    const redis = fakeRedis();
    await markRecoverVerified({ redis, userId: 'u1', ttlSeconds: 600 });
    assert.equal(await isRecoverVerified({ redis, userId: 'u1' }), true);
    await clearRecoverVerified({ redis, userId: 'u1' });
    assert.equal(await isRecoverVerified({ redis, userId: 'u1' }), false);
  });

  it('marker is per user', async () => {
    const redis = fakeRedis();
    await markRecoverVerified({ redis, userId: 'u1' });
    assert.equal(await isRecoverVerified({ redis, userId: 'u2' }), false);
  });
});
