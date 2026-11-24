import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { createEventSchema, updateEventSchema } from '@/app/modules/event/event.schema';

// T-017 (CR-17): timezone is an optional, validated IANA name. No inference from city or location.

const baseEvent = {
  eventName: 'E',
  thumbnail: 'https://example.test/t.png',
  images: [],
  lat: 23.78,
  lng: 90.4,
  location: 'Dhaka',
  startAt: '2030-01-01T10:00:00Z',
  endAt: '2030-01-02T10:00:00Z',
  dressCode: 'casual',
  eventPrice: 10,
  currency: 'USD',
};

describe('timezone in event schemas (T-017)', () => {
  it('a body without timezone still validates and leaves it undefined (DB default UTC applies)', () => {
    const c = createEventSchema.safeParse(baseEvent);
    assert.equal(c.success, true);
    if (c.success) assert.equal(c.data.timezone, undefined);
    const u = updateEventSchema.safeParse({ eventName: 'x' });
    assert.equal(u.success, true);
    if (u.success) assert.equal(u.data.timezone, undefined);
  });

  it('accepts real IANA names including UTC and aliases', () => {
    for (const tz of ['UTC', 'Europe/Paris', 'America/New_York', 'Asia/Dhaka', 'Asia/Kolkata', 'Etc/GMT+5']) {
      assert.equal(createEventSchema.safeParse({ ...baseEvent, timezone: tz }).success, true, tz);
      assert.equal(updateEventSchema.safeParse({ timezone: tz }).success, true, tz);
    }
  });

  it('rejects arbitrary strings, offsets, wrong case, empty and non-strings', () => {
    for (const tz of ['Mars/Olympus', 'banana', '+02:00', 'europe/paris', '', 'Europe/', 123, null]) {
      assert.equal(createEventSchema.safeParse({ ...baseEvent, timezone: tz }).success, false, String(tz));
      assert.equal(updateEventSchema.safeParse({ timezone: tz }).success, false, String(tz));
    }
  });
});
