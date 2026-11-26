import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { createEventSchema, updateEventSchema } from '@/app/modules/event/event.schema';
import {
  assertPricingModeConsistent,
  deriveEventPricingMode,
  resolvePricingMode,
} from '@/app/modules/event/event.pricingMode.helpers';

// T-017 (CR-03): pricingMode rules (pure part) and optional descriptions (schema part).

const free = { price: 0 };
const paid = { price: 10 };
const expect422 = (e: unknown) => {
  const err = e as { statusCode?: number; errorType?: string };
  assert.equal(err.statusCode, 422);
  assert.equal(err.errorType, 'PRICING_MODE_INVALID');
  return true;
};
const check =
  (
    pricingMode: Parameters<typeof assertPricingModeConsistent>[0]['pricingMode'],
    eventPrice: number,
    tiers: Parameters<typeof assertPricingModeConsistent>[0]['tiers']
  ) =>
  () =>
    assertPricingModeConsistent({ pricingMode, eventPrice, tiers });

describe('assertPricingModeConsistent (T-017)', () => {
  it('TIERED needs at least one tier', () => {
    assert.throws(check('TIERED', 10, []), expect422);
    assert.doesNotThrow(check('TIERED', 10, [paid]));
  });
  it('SINGLE needs no tiers', () => {
    assert.throws(check('SINGLE', 10, [paid]), expect422);
    assert.doesNotThrow(check('SINGLE', 10, []));
  });
  it('FREE needs price 0 and no paid tier', () => {
    assert.throws(check('FREE', 5, []), expect422);
    assert.throws(check('FREE', 0, [paid]), expect422);
    assert.doesNotThrow(check('FREE', 0, []));
    assert.doesNotThrow(check('FREE', 0, [free]));
  });
  it('MIXED needs at least one free and one paid tier', () => {
    assert.throws(check('MIXED', 10, []), expect422);
    assert.throws(check('MIXED', 10, [paid]), expect422);
    assert.throws(check('MIXED', 10, [free]), expect422);
    assert.doesNotThrow(check('MIXED', 10, [free, paid]));
  });
  it('a section counts through its children; inactive tiers are ignored', () => {
    assert.doesNotThrow(check('MIXED', 10, [{ price: 99, children: [free, paid] }]));
    assert.throws(check('MIXED', 10, [{ price: 99, children: [paid] }]), expect422);
    assert.throws(check('SINGLE', 10, [{ price: 1, isActive: true }]), expect422);
    assert.doesNotThrow(check('SINGLE', 10, [{ price: 1, isActive: false }]));
    assert.doesNotThrow(check('FREE', 0, [{ price: 5, isActive: false }]));
  });
});

describe('deriveEventPricingMode (migration 4 rule)', () => {
  it('TIERED if any tier, else FREE if eventPrice 0, else SINGLE (never MIXED)', () => {
    assert.equal(deriveEventPricingMode({ eventPrice: 0, tiers: [free, paid] }), 'TIERED');
    assert.equal(deriveEventPricingMode({ eventPrice: 0, tiers: [] }), 'FREE');
    assert.equal(deriveEventPricingMode({ eventPrice: 12, tiers: [] }), 'SINGLE');
  });
});

describe('resolvePricingMode (T-017)', () => {
  it('explicit value is validated and returned', () => {
    assert.equal(resolvePricingMode({ requested: 'MIXED', stored: null, eventPrice: 5, tiers: [free, paid] }), 'MIXED');
    assert.throws(() => resolvePricingMode({ requested: 'FREE', stored: null, eventPrice: 5, tiers: [] }), expect422);
  });
  it('not sent and nothing stored: derived', () => {
    assert.equal(resolvePricingMode({ requested: undefined, stored: null, eventPrice: 0, tiers: [paid] }), 'TIERED');
  });
  it('not sent on update: stored value kept while still consistent, else derived (never 422)', () => {
    assert.equal(resolvePricingMode({ requested: undefined, stored: 'MIXED', eventPrice: 5, tiers: [free, paid] }), 'MIXED');
    assert.equal(resolvePricingMode({ requested: undefined, stored: 'MIXED', eventPrice: 5, tiers: [paid] }), 'TIERED');
  });
});

describe('optional descriptions (T-017)', () => {
  const base = {
    eventName: 'E',
    thumbnail: 'https://example.test/t.png',
    images: [],
    lat: 1,
    lng: 1,
    location: 'x',
    startAt: '2030-01-01T10:00:00Z',
    endAt: '2030-01-02T10:00:00Z',
    dressCode: 'c',
    eventPrice: 0,
    currency: 'USD',
  };
  const tier = { tierName: 'A', price: 1, capacity: 5 };
  it('empty string becomes null on event, section and child tier; text is kept; omitted stays undefined', () => {
    const r = createEventSchema.safeParse({
      ...base,
      eventDescription: '',
      ticketTiers: [{ ...tier, description: '', children: [{ ...tier, description: '' }, { ...tier, description: 'kid' }, tier] }],
    });
    assert.equal(r.success, true);
    if (r.success) {
      assert.equal(r.data.eventDescription, null);
      const t = r.data.ticketTiers?.[0];
      assert.equal(t?.description, null);
      assert.equal(t?.children[0].description, null);
      assert.equal(t?.children[1].description, 'kid');
      assert.equal(t?.children[2].description, undefined);
    }
    const u = updateEventSchema.safeParse({ eventDescription: '' });
    assert.equal(u.success && u.data.eventDescription, null);
  });
});
