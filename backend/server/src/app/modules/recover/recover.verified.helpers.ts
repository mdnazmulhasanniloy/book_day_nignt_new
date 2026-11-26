import { REDIS_PREFIXES } from '@/const';
import { createRedisKey } from '@/app/utils/system.utils';

type TRedisLike = {
  set: (...args: any[]) => Promise<unknown>;
  get: (key: string) => Promise<string | null>;
  del: (key: string) => Promise<unknown>;
};

/** Fallback marker lifetime in seconds when the page token expiry is unknown. */
export const RECOVER_VERIFIED_DEFAULT_TTL = 15 * 60;

export const markRecoverVerified = async ({
  redis,
  userId,
  ttlSeconds,
}: {
  redis: TRedisLike;
  userId: string;
  ttlSeconds?: number;
}): Promise<void> => {
  const ttl =
    ttlSeconds && ttlSeconds > 0 ? ttlSeconds : RECOVER_VERIFIED_DEFAULT_TTL;
  await redis.set(
    createRedisKey(REDIS_PREFIXES.recoverVerified, userId),
    '1',
    'EX',
    ttl
  );
};

export const isRecoverVerified = async ({
  redis,
  userId,
}: {
  redis: TRedisLike;
  userId: string;
}): Promise<boolean> =>
  (await redis.get(createRedisKey(REDIS_PREFIXES.recoverVerified, userId))) !==
  null;

export const clearRecoverVerified = async ({
  redis,
  userId,
}: {
  redis: TRedisLike;
  userId: string;
}): Promise<void> => {
  await redis.del(createRedisKey(REDIS_PREFIXES.recoverVerified, userId));
};
