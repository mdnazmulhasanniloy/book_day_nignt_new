import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { generateNumericOtp, otpTtlSeconds } from '@/app/utils/otpPolicy';

describe('otp policy', () => {
  it('stores expiry in seconds, not milliseconds', () => {
    assert.equal(otpTtlSeconds(5), 300);
    assert.notEqual(otpTtlSeconds(5), 5 * 60 * 1000);
  });

  it('generates a 6-digit numeric code', () => {
    const otp = generateNumericOtp(6);
    assert.match(otp, /^\d{6}$/);
  });
});
