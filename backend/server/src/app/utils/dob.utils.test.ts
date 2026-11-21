import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { assertSignupDob } from '@/app/utils/dob.utils';

const now = new Date('2026-11-11T12:00:00.000Z');

describe('assertSignupDob', () => {
  it('accepts an adult ISO date', () => {
    const date = assertSignupDob('2000-01-01T00:00:00.000Z', now);
    assert.equal(date.toISOString(), '2000-01-01T00:00:00.000Z');
  });

  it('rejects a future date', () => {
    assert.throws(
      () => assertSignupDob('2027-01-01T00:00:00.000Z', now),
      /future/
    );
  });

  it('rejects under 18', () => {
    assert.throws(
      () => assertSignupDob('2010-01-01T00:00:00.000Z', now),
      /at least 18/
    );
  });

  it('rejects an impossible calendar date', () => {
    assert.throws(
      () => assertSignupDob('2024-02-31T00:00:00.000Z', now),
      /real calendar date/
    );
  });

  it('rejects a non-ISO value', () => {
    assert.throws(
      () => assertSignupDob('01-01-2000', now),
      /ISO UTC/
    );
  });
});
