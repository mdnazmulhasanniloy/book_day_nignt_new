import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  MOST_VIEWED_WINDOW_DAYS,
  TRENDING_WINDOW_DAYS,
  rankingWindowStartDay,
} from '@/app/modules/explore/explore.ranking';

// T-042: ranking windows are whole UTC days ending with today (no database needed).
describe('rankingWindowStartDay (T-042)', () => {
  it('7 days include today and the 6 days before', () => {
    assert.equal(rankingWindowStartDay({ now: new Date('2026-12-01T12:00:00Z'), days: TRENDING_WINDOW_DAYS }), '2026-11-25');
  });
  it('30 days include today and the 29 days before', () => {
    assert.equal(rankingWindowStartDay({ now: new Date('2026-12-01T12:00:00Z'), days: MOST_VIEWED_WINDOW_DAYS }), '2026-11-02');
  });
  it('uses the UTC day, not the local day', () => {
    assert.equal(rankingWindowStartDay({ now: new Date('2026-12-01T23:59:59Z'), days: 7 }), '2026-11-25');
    assert.equal(rankingWindowStartDay({ now: new Date('2026-12-02T00:00:00Z'), days: 7 }), '2026-11-26');
  });
  it('crosses month and year boundaries', () => {
    assert.equal(rankingWindowStartDay({ now: new Date('2027-01-03T00:00:00Z'), days: 7 }), '2026-12-28');
  });
});
