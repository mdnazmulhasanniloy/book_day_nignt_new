import { randomInt } from 'crypto';

/**
 * Redis EX is seconds. Callers must not pass millisecond values.
 */
export function otpTtlSeconds(expireMinutes: number): number {
  if (!Number.isInteger(expireMinutes) || expireMinutes <= 0) {
    throw new Error('OTP expiry minutes must be a positive integer');
  }
  return expireMinutes * 60;
}

/** Unbiased numeric OTP from a CSPRNG. */
export function generateNumericOtp(length = 6): string {
  if (!Number.isInteger(length) || length <= 0) {
    throw new Error('OTP length must be a positive integer');
  }
  let otp = '';
  for (let i = 0; i < length; i += 1) {
    otp += String(randomInt(0, 10));
  }
  return otp;
}
