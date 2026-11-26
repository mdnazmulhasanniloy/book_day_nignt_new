import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  classifyEventDay,
  groupItemsByDay,
  localDateString,
} from '@/app/modules/explore/explore.grouping';
import { exploreQuerySchema } from '@/app/modules/explore/explore.schema';

// T-035 (CR-09, CR-10): day buckets Today, Tomorrow, This Weekend, Upcoming computed with IANA time
// zone arithmetic. Every test passes a fixed clock; nothing reads the real date.
// Calendar facts used: 2027-03-24 is a Wednesday; Europe/Rome moves from UTC+1 to UTC+2 on
// Sunday 2027-03-28 at 02:00 local (01:00Z).

const ROME = 'Europe/Rome';
const iso = (s: string) => new Date(s);

describe('classifyEventDay (T-035)', () => {
  // now = Wednesday 2027-03-24 12:00 UTC = 13:00 Rome (CET).
  const now = iso('2027-03-24T12:00:00Z');

  it('Today and Tomorrow follow the local calendar day', () => {
    assert.equal(classifyEventDay({ startAt: iso('2027-03-24T20:00:00Z'), now, timeZone: ROME }), 'Today');
    assert.equal(classifyEventDay({ startAt: iso('2027-03-25T08:00:00Z'), now, timeZone: ROME }), 'Tomorrow');
  });

  it('the same instant lands on different days in different zones', () => {
    const startAt = iso('2027-03-24T23:30:00Z'); // 00:30 on the 25th in Rome, still the 24th in UTC
    assert.equal(classifyEventDay({ startAt, now, timeZone: 'UTC' }), 'Today');
    assert.equal(classifyEventDay({ startAt, now, timeZone: ROME }), 'Tomorrow');
  });

  it('an overnight event (23:00 to 03:00 local) is grouped by its local start day', () => {
    // Starts Wed 23:00 Rome (22:00Z), ends Thu 03:00: it starts today, so it is Today.
    assert.equal(classifyEventDay({ startAt: iso('2027-03-24T22:00:00Z'), now, timeZone: ROME }), 'Today');
    // Starts Thu 23:00 Rome, ends Fri 03:00: it starts tomorrow, so it is Tomorrow, not Upcoming.
    assert.equal(classifyEventDay({ startAt: iso('2027-03-25T22:00:00Z'), now, timeZone: ROME }), 'Tomorrow');
    // Starts Fri 23:00 Rome, ends Sat 03:00: starts on the Friday evening, so This Weekend.
    assert.equal(classifyEventDay({ startAt: iso('2027-03-26T22:00:00Z'), now, timeZone: ROME }), 'This Weekend');
  });

  it('weekend is Friday 18:00 local to Sunday end; Monday and earlier Friday are Upcoming', () => {
    // Friday 2027-03-26 17:59 Rome (CET, UTC+1) = 16:59Z; 18:00 = 17:00Z.
    assert.equal(classifyEventDay({ startAt: iso('2027-03-26T16:59:00Z'), now, timeZone: ROME }), 'Upcoming');
    assert.equal(classifyEventDay({ startAt: iso('2027-03-26T17:00:00Z'), now, timeZone: ROME }), 'This Weekend');
    assert.equal(classifyEventDay({ startAt: iso('2027-03-27T10:00:00Z'), now, timeZone: ROME }), 'This Weekend');
    // Sunday 23:30 Rome (CEST, UTC+2) = 21:30Z is the last weekend minute.
    assert.equal(classifyEventDay({ startAt: iso('2027-03-28T21:30:00Z'), now, timeZone: ROME }), 'This Weekend');
    // Monday 2027-03-29 00:30 Rome (CEST) = Sunday 22:30Z: local Monday, so Upcoming.
    assert.equal(classifyEventDay({ startAt: iso('2027-03-28T22:30:00Z'), now, timeZone: ROME }), 'Upcoming');
  });

  it('a weekend of a later week is Upcoming', () => {
    assert.equal(classifyEventDay({ startAt: iso('2027-04-03T21:00:00Z'), now, timeZone: ROME }), 'Upcoming');
  });

  it('Today and Tomorrow win over This Weekend', () => {
    const fri = iso('2027-03-26T12:00:00Z'); // Friday 13:00 Rome
    assert.equal(classifyEventDay({ startAt: iso('2027-03-26T20:00:00Z'), now: fri, timeZone: ROME }), 'Today');
    assert.equal(classifyEventDay({ startAt: iso('2027-03-27T20:00:00Z'), now: fri, timeZone: ROME }), 'Tomorrow');
    assert.equal(classifyEventDay({ startAt: iso('2027-03-28T20:00:00Z'), now: fri, timeZone: ROME }), 'This Weekend');
  });

  it('an event that already started on an earlier local day is still Today (it is still running)', () => {
    assert.equal(classifyEventDay({ startAt: iso('2027-03-23T22:30:00Z'), now, timeZone: ROME }), 'Today');
  });

  it('daylight saving: the 2027-03-28 shift does not move buckets by an hour', () => {
    // now = Saturday 2027-03-27 20:00 Rome (CET) = 19:00Z. Tomorrow is Sunday 28th, the DST day.
    const sat = iso('2027-03-27T19:00:00Z');
    // Sunday 00:30 local CET (+1) = Saturday 23:30Z.
    assert.equal(classifyEventDay({ startAt: iso('2027-03-27T23:30:00Z'), now: sat, timeZone: ROME }), 'Tomorrow');
    // Sunday 23:30 local CEST (+2) = 21:30Z: still the 28th.
    assert.equal(classifyEventDay({ startAt: iso('2027-03-28T21:30:00Z'), now: sat, timeZone: ROME }), 'Tomorrow');
    // Monday 29th 00:30 local CEST = Sunday 22:30Z. With the stale +1 offset it would read 23:30 on the
    // 28th and wrongly be Tomorrow. Correct: local Monday = Upcoming.
    assert.equal(classifyEventDay({ startAt: iso('2027-03-28T22:30:00Z'), now: sat, timeZone: ROME }), 'Upcoming');
    // Sunday 01:30Z is 03:30 local CEST on the 28th (after the gap): Tomorrow.
    assert.equal(classifyEventDay({ startAt: iso('2027-03-28T01:30:00Z'), now: sat, timeZone: ROME }), 'Tomorrow');
  });

  it('daylight saving does not shift the Today boundary on the transition day itself', () => {
    // now = Sunday 2027-03-28 10:00 Rome (CEST) = 08:00Z. Monday 00:30 CEST = Sunday 22:30Z is Tomorrow.
    const sun = iso('2027-03-28T08:00:00Z');
    assert.equal(classifyEventDay({ startAt: iso('2027-03-28T22:30:00Z'), now: sun, timeZone: ROME }), 'Tomorrow');
    assert.equal(classifyEventDay({ startAt: iso('2027-03-28T21:30:00Z'), now: sun, timeZone: ROME }), 'Today');
  });

  it('events with the default UTC zone are bucketed by UTC day', () => {
    assert.equal(classifyEventDay({ startAt: iso('2027-03-24T23:59:00Z'), now, timeZone: 'UTC' }), 'Today');
    assert.equal(classifyEventDay({ startAt: iso('2027-03-25T00:00:00Z'), now, timeZone: 'UTC' }), 'Tomorrow');
  });
});

describe('localDateString (T-035)', () => {
  it('returns the local calendar date', () => {
    assert.equal(localDateString({ date: iso('2027-03-28T22:30:00Z'), timeZone: ROME }), '2027-03-29');
    assert.equal(localDateString({ date: iso('2027-03-28T22:30:00Z'), timeZone: 'UTC' }), '2027-03-28');
  });
});

describe('groupItemsByDay (T-035)', () => {
  const now = iso('2027-03-24T12:00:00Z');
  const mk = (id: string, startAt: string, timeZone = ROME) => ({ id, startAt: iso(startAt), timeZone });

  it('returns buckets in fixed order, keeps item order, drops empty buckets, labels each bucket with a date', () => {
    const items = [
      mk('a', '2027-03-24T20:00:00Z'),
      mk('b', '2027-03-25T20:00:00Z'),
      mk('c', '2027-03-26T20:00:00Z'),
      mk('d', '2027-03-27T20:00:00Z'),
      mk('e', '2027-04-10T20:00:00Z'),
    ];
    const groups = groupItemsByDay({ items, now });
    assert.deepEqual(
      groups.map((g) => [g.label, g.date, g.items.map((i) => i.id)]),
      [
        ['Today', '2027-03-24', ['a']],
        ['Tomorrow', '2027-03-25', ['b']],
        ['This Weekend', '2027-03-26', ['c', 'd']],
        ['Upcoming', '2027-04-10', ['e']],
      ]
    );
    const only = groupItemsByDay({ items: [mk('e', '2027-04-10T20:00:00Z')], now });
    assert.deepEqual(only.map((g) => g.label), ['Upcoming']);
    assert.deepEqual(groupItemsByDay({ items: [], now }), []);
  });
});

describe('exploreQuerySchema date range and group (T-035)', () => {
  it('accepts from and to as ISO dates, group=day and dateFilter=this_week', () => {
    const r = exploreQuerySchema.safeParse({ from: '2027-03-01', to: '2027-03-31', group: 'day', dateFilter: 'this_week' });
    assert.equal(r.success, true);
  });

  it('from after to is rejected', () => {
    assert.equal(exploreQuerySchema.safeParse({ from: '2027-04-02', to: '2027-04-01' }).success, false);
    assert.equal(exploreQuerySchema.safeParse({ from: '2027-04-01', to: '2027-04-01' }).success, true);
  });

  it('rejects malformed and impossible dates', () => {
    for (const bad of ['2027-13-01', '2027-02-30', 'tomorrow', '2027-3-1', '2027-03-01T10:00:00Z']) {
      assert.equal(exploreQuerySchema.safeParse({ from: bad }).success, false, bad);
    }
  });

  it('group=day is not allowed with type=CLUB (clubs have no start date)', () => {
    assert.equal(exploreQuerySchema.safeParse({ group: 'day', type: 'CLUB' }).success, false);
    assert.equal(exploreQuerySchema.safeParse({ group: 'day', type: 'EVENT' }).success, true);
    assert.equal(exploreQuerySchema.safeParse({ group: 'none', type: 'CLUB' }).success, true);
  });

  it('unknown group value is rejected', () => {
    assert.equal(exploreQuerySchema.safeParse({ group: 'week' }).success, false);
  });
});
