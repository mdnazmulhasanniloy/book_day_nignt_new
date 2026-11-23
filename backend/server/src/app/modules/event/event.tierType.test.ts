import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { createEventSchema, updateEventSchema } from '@/app/modules/event/event.schema';
import { assertTierSectionRules } from '@/app/modules/event/event.ticketTier.helpers';

// T-016 (CR-03): tierType on tier objects (Zod) and the section vs tier rule (pure part).

const baseTier = { tierName: 'Early', price: 10, capacity: 50 };
const baseEvent = {
  eventName: 'E',
  thumbnail: 'https://example.test/t.png',
  images: [],
  lat: 1,
  lng: 1,
  location: 'x',
  startAt: '2030-01-01T10:00:00Z',
  endAt: '2030-01-02T10:00:00Z',
  dressCode: 'casual',
  eventPrice: 0,
  currency: 'USD',
};

describe('tierType in event schemas (T-016)', () => {
  it('accepts TICKET and PASS on a section and on a child', () => {
    const r = createEventSchema.safeParse({
      ...baseEvent,
      ticketTiers: [{ ...baseTier, tierType: 'PASS', children: [{ ...baseTier, tierType: 'TICKET' }] }],
    });
    assert.equal(r.success, true);
    if (r.success) {
      assert.equal(r.data.ticketTiers?.[0].tierType, 'PASS');
      assert.equal(r.data.ticketTiers?.[0].children[0].tierType, 'TICKET');
    }
  });

  it('rejects an unknown tierType on create and update', () => {
    assert.equal(
      createEventSchema.safeParse({ ...baseEvent, ticketTiers: [{ ...baseTier, tierType: 'VIP' }] }).success,
      false
    );
    assert.equal(
      updateEventSchema.safeParse({ ticketTiers: [{ ...baseTier, tierType: 'vip' }] }).success,
      false
    );
  });

  it('an old client that omits tierType still validates (field stays undefined)', () => {
    const r = updateEventSchema.safeParse({ ticketTiers: [baseTier] });
    assert.equal(r.success, true);
    if (r.success) assert.equal(r.data.ticketTiers?.[0].tierType, undefined);
  });
});

describe('assertTierSectionRules (T-016)', () => {
  const rule = (args: Parameters<typeof assertTierSectionRules>[0]) => () => assertTierSectionRules(args);
  const expect422 = (type: string) => (e: unknown) => {
    const err = e as { statusCode?: number; errorType?: string };
    assert.equal(err.statusCode, 422);
    assert.equal(err.errorType, type);
    return true;
  };

  it('a section that already has sales is rejected', () => {
    assert.throws(
      rule({ eventId: 'e1', sections: [{ hasChildren: true, existing: { id: 't1', eventId: 'e1', parentId: null, soldCount: 2 } }] }),
      expect422('TIER_SECTION_HAS_SALES')
    );
  });

  it('a childless tier with sales is fine', () => {
    assertTierSectionRules({
      eventId: 'e1',
      sections: [{ hasChildren: false, existing: { id: 't1', eventId: 'e1', parentId: null, soldCount: 2 } }],
    });
  });

  it('a child whose parent belongs to another event is rejected', () => {
    assert.throws(
      rule({
        eventId: 'e1',
        sections: [{ hasChildren: true, existing: { id: 't1', eventId: 'e2', parentId: null, soldCount: 0 } }],
      }),
      expect422('TIER_INVALID_PARENT')
    );
  });

  it('a child whose parent is itself a child is rejected', () => {
    assert.throws(
      rule({
        eventId: 'e1',
        sections: [{ hasChildren: true, existing: { id: 't1', eventId: 'e1', parentId: 'p', soldCount: 0 } }],
      }),
      expect422('TIER_INVALID_PARENT')
    );
  });

  it('a new section with children passes', () => {
    assertTierSectionRules({ eventId: 'e1', sections: [{ hasChildren: true, existing: null }] });
  });
});
