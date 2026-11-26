import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  exploreMapQuerySchema,
  exploreQuerySchema,
  EXPLORE_MAP_MAX_PINS,
} from '@/app/modules/explore/explore.schema';

// T-038: the map query schema accepts the /explore filters and none of the paging fields.
describe('exploreMapQuerySchema (T-038)', () => {
  it('requires type', () => {
    assert.equal(exploreMapQuerySchema.safeParse({}).success, false);
    assert.equal(exploreMapQuerySchema.safeParse({ type: 'CLUB' }).success, true);
  });

  it('cap constant is 300 (api-spec)', () => {
    assert.equal(EXPLORE_MAP_MAX_PINS, 300);
  });

  it('applies the same validation rules as /explore', () => {
    const bad: Record<string, unknown>[] = [
      { radiusKm: 25 },
      { cityId: 'x' },
      { from: '2027-02-30' },
      { from: '2027-03-05', to: '2027-03-01' },
      { type: 'EVENT', isVip: true },
    ];
    for (const extra of bad) {
      const q = { type: 'EVENT', ...extra };
      assert.equal(exploreQuerySchema.safeParse(q).success, false, JSON.stringify(q));
      assert.equal(exploreMapQuerySchema.safeParse(q).success, false, JSON.stringify(q));
    }
  });

  it('drops page, limit, sort and group', () => {
    const r = exploreMapQuerySchema.parse({ type: 'EVENT', page: '3', limit: '5', sort: 'oldest', group: 'day' });
    assert.equal('page' in r, false);
    assert.equal('limit' in r, false);
    assert.equal('sort' in r, false);
    assert.equal('group' in r, false);
  });
});
