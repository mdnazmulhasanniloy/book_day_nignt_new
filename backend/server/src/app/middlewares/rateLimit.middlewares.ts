import type { NextFunction, Request, Response } from 'express';
import type { TRedisPrefix } from '@/app/@types/system.types';
import { getTraceId } from '@/app/configs/requestContext.configs';
import { getRedisClient } from '@/app/configs/redis.configs';
import { extractToken, verifyAccessToken } from '@/app/utils/jwt.utils';
import { asyncHandler, createRedisKey } from '@/app/utils/system.utils';
import {
  AuthErrorType,
  promoValidateMaxPerWindow,
  promoValidateWindowSeconds,
  REDIS_PREFIXES,
} from '@/const';

type RateLimitOptions = {
  /** Redis key prefix for the per-IP counter (see REDIS_PREFIXES). */
  ipPrefix: TRedisPrefix;
  /** Redis key prefix for the per-user counter; omit for IP-only limiting. */
  userPrefix?: TRedisPrefix;
  max: number;
  windowSeconds: number;
  message: string;
};

/**
 * Best-effort user id from a bearer token. Never rejects: an expired or garbage
 * token falls back to IP-only limiting, because the live app treats 401 as logout.
 */
const userIdFromBearer = (req: Request): string | null => {
  const token = extractToken(req);
  if (!token) return null;
  const decoded = verifyAccessToken(token);
  const sub = decoded.data?.sub;
  return typeof sub === 'string' && sub.length > 0 ? sub : null;
};

/** Fixed-window counter: INCR, set EXPIRE on the first hit, then report the count and seconds left. */
const hit = async (key: string, windowSeconds: number) => {
  const redis = getRedisClient();
  const count = await redis.incr(key);
  if (count === 1) await redis.expire(key, windowSeconds);
  let ttl = await redis.ttl(key);
  if (ttl < 0) {
    // expire was lost (crash between INCR and EXPIRE): re-arm so the key cannot stick forever
    await redis.expire(key, windowSeconds);
    ttl = windowSeconds;
  }
  return { count, ttl };
};

/**
 * Generic fixed-window limiter keyed by client IP (req.ip, which honours the
 * `trust proxy` setting in app.ts) and, when a valid bearer token is present,
 * also by user id. Over the limit: 429, `Retry-After` seconds, errorType
 * RATE_LIMITED (never 401/403, the live Flutter app logs out on those).
 * Redis errors propagate to the global error handler, like limitOtpSendMiddleware.
 * Nothing sensitive (body, code, token) is logged or stored in keys.
 */
export const createRateLimitMiddleware = ({
  ipPrefix,
  userPrefix,
  max,
  windowSeconds,
  message,
}: RateLimitOptions) =>
  asyncHandler(
    async (req: Request, res: Response, next: NextFunction): Promise<void> => {
      const ip = (req.ip || 'unknown').replace(/:/g, '_');
      const results = [await hit(createRedisKey(ipPrefix, ip), windowSeconds)];
      const userId = userPrefix ? userIdFromBearer(req) : null;
      if (userPrefix && userId) {
        results.push(await hit(createRedisKey(userPrefix, userId), windowSeconds));
      }
      if (results.some((r) => r.count > max)) {
        const retryAfter = Math.max(
          1,
          ...results.filter((r) => r.count > max).map((r) => r.ttl)
        );
        res.set('Retry-After', String(retryAfter));
        res.status(429).json({
          success: false,
          message,
          errorType: AuthErrorType.RATE_LIMITED,
          traceId: getTraceId(),
        });
        return;
      }
      next();
    }
  );

/** POST /promo/validate: 20 per minute per IP and per user (T-019, S-09). */
export const limitPromoValidateMiddleware = createRateLimitMiddleware({
  ipPrefix: REDIS_PREFIXES.promoValidateIp,
  userPrefix: REDIS_PREFIXES.promoValidateUser,
  max: promoValidateMaxPerWindow,
  windowSeconds: promoValidateWindowSeconds,
  message: 'Too many promo code attempts. Try again shortly.',
});
