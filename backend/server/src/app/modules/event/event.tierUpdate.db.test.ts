import { after, describe, it } from 'node:test';
import assert from 'node:assert/strict';
import type { Prisma } from '@prisma/client';
import {
  closeTestPrisma,
  dbTestSkipReason,
  withRollback,
} from '@/testing/testDb';
import { createEvent, createTier, createUser } from '@/testing/fixtures';
import {
  reconcileEventTicketTiers,
  type TierInput,
} from '@/app/modules/event/event.ticketTier.helpers';

type Tx = Prisma.TransactionClient;

const tier = (tierName: string, extra: Partial<TierInput> = {}): TierInput => ({
  tierName,
  price: 10,
  capacity: 100,
  sortOrder: 0,
  isActive: true,
  ...extra,
});

const setup = async (tx: Tx) => {
  const owner = await createUser(tx, { accountRole: 'CLUB_OWNER' });
  const event = await createEvent(tx, owner.id);
  return { owner, event };
};

const reconcile = (tx: Tx, eventId: string, tiers: TierInput[]) =>
  reconcileEventTicketTiers({ tx, eventId, tiers });

// The helper validates before it writes, so the surrounding tx stays usable after a rejection.
const rejectsWith = async (
  fn: () => Promise<unknown>,
  statusCode: number,
  errorType: string
) => {
  await assert.rejects(fn, (e: unknown) => {
    const err = e as { statusCode?: number; errorType?: string; message?: string };
    assert.equal(err.statusCode, statusCode);
    assert.equal(err.errorType, errorType);
    assert.ok(err.message && err.message.length > 10);
    return true;
  });
};

describe('reconcileEventTicketTiers (T-004, ADR-004)', { skip: dbTestSkipReason() }, () => {
  after(closeTestPrisma);

  it('update with ids preserves ids and soldCount', () =>
    withRollback(async (tx) => {
      const { event } = await setup(tx);
      const a = await createTier(tx, event.id, { tierName: 'A', soldCount: 3 });
      const b = await createTier(tx, event.id, { tierName: 'B' });
      await reconcile(tx, event.id, [
        tier('A', { id: a.id, price: 20 }),
        tier('B', { id: b.id }),
      ]);
      const rows = await tx.eventTicketTier.findMany({ where: { eventId: event.id } });
      assert.equal(rows.length, 2);
      const ra = rows.find((r) => r.id === a.id);
      assert.ok(ra, 'tier A keeps its id');
      assert.equal(ra.soldCount, 3);
      assert.equal(Number(ra.price), 20);
      assert.ok(rows.find((r) => r.id === b.id));
    }));

  it('update WITHOUT ids (live app) matches by (groupName, tierName) and keeps soldCount', () =>
    withRollback(async (tx) => {
      const { event } = await setup(tx);
      const a = await createTier(tx, event.id, { tierName: 'Early', groupName: 'GA', soldCount: 3 });
      const b = await createTier(tx, event.id, { tierName: 'Early', groupName: 'VIP' });
      await reconcile(tx, event.id, [
        tier(' early ', { groupName: 'ga', price: 15 }),
        tier('Early', { groupName: 'VIP' }),
      ]);
      const rows = await tx.eventTicketTier.findMany({ where: { eventId: event.id } });
      assert.equal(rows.length, 2);
      const ra = rows.find((r) => r.id === a.id);
      assert.ok(ra, 'GA tier keeps its id');
      assert.equal(ra.soldCount, 3);
      assert.equal(Number(ra.price), 15);
      assert.ok(rows.find((r) => r.id === b.id));
    }));

  it('missing tier: deleted when soldCount = 0, kept inactive when sold', () =>
    withRollback(async (tx) => {
      const { event } = await setup(tx);
      const keep = await createTier(tx, event.id, { tierName: 'Keep' });
      const unsold = await createTier(tx, event.id, { tierName: 'Unsold' });
      const sold = await createTier(tx, event.id, { tierName: 'Sold', soldCount: 4 });
      await reconcile(tx, event.id, [tier('Keep', { id: keep.id })]);
      assert.equal(await tx.eventTicketTier.count({ where: { id: unsold.id } }), 0);
      const s = await tx.eventTicketTier.findUniqueOrThrow({ where: { id: sold.id } });
      assert.equal(s.isActive, false);
      assert.equal(s.soldCount, 4);
    }));

  it('capacity below soldCount returns 409 TIER_CAPACITY_BELOW_SOLD', () =>
    withRollback(async (tx) => {
      const { event } = await setup(tx);
      const a = await createTier(tx, event.id, { tierName: 'A', soldCount: 5 });
      await rejectsWith(
        () => reconcile(tx, event.id, [tier('A', { id: a.id, capacity: 4 })]),
        409,
        'TIER_CAPACITY_BELOW_SOLD'
      );
      // also on the id-less fallback path
      await rejectsWith(
        () => reconcile(tx, event.id, [tier('A', { capacity: 2 })]),
        409,
        'TIER_CAPACITY_BELOW_SOLD'
      );
      const row = await tx.eventTicketTier.findUniqueOrThrow({ where: { id: a.id } });
      assert.equal(row.capacity, 100);
    }));

  it('price change on a tier with sales is allowed', () =>
    withRollback(async (tx) => {
      const { event } = await setup(tx);
      const a = await createTier(tx, event.id, { tierName: 'A', soldCount: 5 });
      await reconcile(tx, event.id, [tier('A', { id: a.id, price: 99, capacity: 5 })]);
      const row = await tx.eventTicketTier.findUniqueOrThrow({ where: { id: a.id } });
      assert.equal(Number(row.price), 99);
      assert.equal(row.soldCount, 5);
    }));

  it('a tier id from another event is rejected (404 TIER_NOT_FOUND) and nothing changes', () =>
    withRollback(async (tx) => {
      const { owner, event } = await setup(tx);
      const other = await createEvent(tx, owner.id);
      const foreign = await createTier(tx, other.id, { tierName: 'Foreign', soldCount: 2 });
      const mine = await createTier(tx, event.id, { tierName: 'Mine', soldCount: 1 });
      await rejectsWith(
        () => reconcile(tx, event.id, [tier('X', { id: foreign.id })]),
        404,
        'TIER_NOT_FOUND'
      );
      assert.equal(await tx.eventTicketTier.count({ where: { eventId: other.id } }), 1);
      assert.equal(
        (await tx.eventTicketTier.findUniqueOrThrow({ where: { id: mine.id } })).soldCount,
        1
      );
    }));

  it('duplicate (groupName, tierName): no silent merge, exact price+capacity pair first', () =>
    withRollback(async (tx) => {
      const { event } = await setup(tx);
      const e1 = await createTier(tx, event.id, { tierName: 'Early', price: 10, soldCount: 7, sortOrder: 1 });
      const e2 = await createTier(tx, event.id, { tierName: 'Early', price: 12, soldCount: 0, sortOrder: 2 });
      // ADR example: the app sends the 12 tier first, then the 10 tier
      const res = await reconcile(tx, event.id, [
        tier('Early', { price: 12, sortOrder: 1 }),
        tier('Early', { price: 10, sortOrder: 2 }),
      ]);
      const rows = await tx.eventTicketTier.findMany({ where: { eventId: event.id } });
      assert.equal(rows.length, 2, 'both survive, not merged');
      const r1 = rows.find((r) => r.id === e1.id);
      const r2 = rows.find((r) => r.id === e2.id);
      assert.ok(r1 && r2);
      assert.equal(r1.soldCount, 7);
      assert.equal(Number(r1.price), 10, 'sold tier stays on the 10 price');
      assert.equal(Number(r2.price), 12);
      assert.equal(res.warnings.length, 0, 'exact pairs are unambiguous');
    }));

  it('duplicates paired by position log TIER_MATCH_AMBIGUOUS; surplus incoming is created', () =>
    withRollback(async (tx) => {
      const { event } = await setup(tx);
      const first = await createTier(tx, event.id, { tierName: 'Dup', price: 10, soldCount: 2, sortOrder: 1 });
      const second = await createTier(tx, event.id, { tierName: 'Dup', price: 10, soldCount: 0, sortOrder: 2 });
      const res = await reconcile(tx, event.id, [
        tier('Dup', { price: 50, sortOrder: 1 }),
        tier('Dup', { price: 60, sortOrder: 2 }),
        tier('Dup', { price: 70, sortOrder: 3 }),
      ]);
      const rows = await tx.eventTicketTier.findMany({ where: { eventId: event.id } });
      assert.equal(rows.length, 3);
      assert.equal(Number(rows.find((r) => r.id === first.id)?.price), 50);
      assert.equal(Number(rows.find((r) => r.id === second.id)?.price), 60);
      assert.equal(rows.find((r) => r.id === first.id)?.soldCount, 2);
      assert.equal(res.warnings.length, 2);
      assert.equal(res.warnings[0].code, 'TIER_MATCH_AMBIGUOUS');
      assert.equal(res.warnings[0].eventId, event.id);
    }));

  it('sections keep their children by parentId; children match under the matched parent', () =>
    withRollback(async (tx) => {
      const { event } = await setup(tx);
      const parent = await createTier(tx, event.id, { tierName: 'Section', groupName: 'G' });
      const child = await createTier(tx, event.id, { tierName: 'Child', parentId: parent.id, soldCount: 3 });
      await reconcile(tx, event.id, [
        tier('Section', { groupName: 'G', children: [tier('Child', { price: 30 })] }),
      ]);
      const rows = await tx.eventTicketTier.findMany({ where: { eventId: event.id } });
      assert.equal(rows.length, 2);
      const c = rows.find((r) => r.id === child.id);
      assert.ok(c, 'child kept its id');
      assert.equal(c.parentId, parent.id);
      assert.equal(c.soldCount, 3);
      assert.equal(Number(c.price), 30);
    }));

  it('removed section with a sold child is not deleted (cascade would destroy sales)', () =>
    withRollback(async (tx) => {
      const { event } = await setup(tx);
      const parent = await createTier(tx, event.id, { tierName: 'Section' });
      const child = await createTier(tx, event.id, { tierName: 'Child', parentId: parent.id, soldCount: 3 });
      await reconcile(tx, event.id, [tier('Other')]);
      const c = await tx.eventTicketTier.findUniqueOrThrow({ where: { id: child.id } });
      assert.equal(c.isActive, false);
      assert.equal(c.parentId, parent.id);
      const p = await tx.eventTicketTier.findUniqueOrThrow({ where: { id: parent.id } });
      assert.equal(p.isActive, false);
    }));

  it('mixed payload: tiers without id are created when another tier carries an id', () =>
    withRollback(async (tx) => {
      const { event } = await setup(tx);
      const a = await createTier(tx, event.id, { tierName: 'A', soldCount: 2 });
      const b = await createTier(tx, event.id, { tierName: 'B', soldCount: 0 });
      await reconcile(tx, event.id, [tier('A', { id: a.id }), tier('B')]);
      const rows = await tx.eventTicketTier.findMany({ where: { eventId: event.id } });
      assert.equal(rows.length, 2, 'old B deleted (unsold, unreferenced), new B created');
      assert.notEqual(rows.find((r) => r.tierName === 'B')?.id, b.id);
      assert.equal(rows.find((r) => r.id === a.id)?.soldCount, 2);
    }));

  it('soldCount is never taken from the client', () =>
    withRollback(async (tx) => {
      const { event } = await setup(tx);
      const a = await createTier(tx, event.id, { tierName: 'A', soldCount: 3 });
      await reconcile(tx, event.id, [
        { ...tier('A', { id: a.id }), soldCount: 0 } as TierInput,
      ]);
      assert.equal(
        (await tx.eventTicketTier.findUniqueOrThrow({ where: { id: a.id } })).soldCount,
        3
      );
    }));
});
