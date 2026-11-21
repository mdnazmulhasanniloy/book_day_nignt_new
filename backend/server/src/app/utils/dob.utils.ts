import { MIN_SIGNUP_AGE } from '@/const';

const ISO_UTC = /^(\d{4})-(\d{2})-(\d{2})T\d{2}:\d{2}:\d{2}(\.\d+)?Z$/;

export function ageInYears(birth: Date, now: Date): number {
  let age = now.getUTCFullYear() - birth.getUTCFullYear();
  const monthDelta = now.getUTCMonth() - birth.getUTCMonth();
  if (
    monthDelta < 0 ||
    (monthDelta === 0 && now.getUTCDate() < birth.getUTCDate())
  ) {
    age -= 1;
  }
  return age;
}

/**
 * Accepts an ISO UTC datetime, rejects impossible calendar dates,
 * future dates, and ages below MIN_SIGNUP_AGE.
 */
export function assertSignupDob(value: string, now: Date = new Date()): Date {
  const match = ISO_UTC.exec(value);
  if (!match) {
    throw new Error('dateOfBirth must be an ISO UTC datetime');
  }
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    throw new Error('dateOfBirth is not a real calendar date');
  }
  const year = Number(match[1]);
  const month = Number(match[2]);
  const day = Number(match[3]);
  if (
    date.getUTCFullYear() !== year ||
    date.getUTCMonth() + 1 !== month ||
    date.getUTCDate() !== day
  ) {
    throw new Error('dateOfBirth is not a real calendar date');
  }
  if (date.getTime() > now.getTime()) {
    throw new Error('dateOfBirth cannot be in the future');
  }
  if (ageInYears(date, now) < MIN_SIGNUP_AGE) {
    throw new Error(`You must be at least ${MIN_SIGNUP_AGE} years old`);
  }
  return date;
}
