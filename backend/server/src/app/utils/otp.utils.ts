import crypto from 'crypto';

import { THashOtpArgs, TCompareOtpArgs } from '@/app/@types/otp.types';
import { getRedisClient } from '@/app/configs/redis.configs';
import { createRedisKey } from '@/app/utils/system.utils';
import { otpTtlSeconds } from '@/app/utils/otpPolicy';
import {
  AuthErrorType,
  otpExpireAt,
  otpResendCooldownSeconds,
  REDIS_PREFIXES,
} from '@/const';
import { env } from '@/env';

const secret = env.OTP_HASH_SECRET;
/**
 * Hashes a plain OTP using HMAC-SHA256.
 */
export function hashOtp({ otp }: THashOtpArgs): string {
  return crypto.createHmac('sha256', secret).update(otp).digest('hex');
}

/**
 * Timing-safe OTP comparison
 */
export function compareOtp({ hashedOtp, otp }: TCompareOtpArgs): boolean {
  const inputHashedOtp = hashOtp({ otp });

  const stored = Buffer.from(hashedOtp, 'hex');
  const incoming = Buffer.from(inputHashedOtp, 'hex');

  if (stored.length !== incoming.length) return false;

  return crypto.timingSafeEqual(stored, incoming);
}

/** Stores only the OTP hash. Replaces any previous code and attempt counter. */
export async function saveHashedOtp(
  userId: string,
  hashedOtp: string
): Promise<void> {
  const redisClient = getRedisClient();
  await redisClient.del(createRedisKey(REDIS_PREFIXES.otpAttempts, userId));
  await redisClient.set(
    createRedisKey(REDIS_PREFIXES.otp, userId),
    hashedOtp,
    'EX',
    otpTtlSeconds(otpExpireAt)
  );
}

/** Blocks a resend until the cooldown key expires. Does not replace the current OTP when blocked. */
export async function assertResendAllowed(userId: string): Promise<void> {
  const redisClient = getRedisClient();
  const key = createRedisKey(REDIS_PREFIXES.otpResend, userId);
  const coolingDown = await redisClient.get(key);
  if (coolingDown) {
    throw {
      statusCode: 429,
      message: 'Please wait before requesting another code',
      errorType: AuthErrorType.RESEND_TOO_SOON,
    };
  }
  await redisClient.set(key, '1', 'EX', otpResendCooldownSeconds);
}
