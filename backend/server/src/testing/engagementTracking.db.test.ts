import { after, describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { closeTestPrisma, dbTestSkipReason, withRollback } from '@/testing/testDb';
import { createEvent, createUser } from '@/testing/fixtures';

// T-039 (migration 11): EventInterest, UserRecentEventView, EventViewDaily. Raw SQL on purpose: it
// checks the database objects themselves (the tables are not used by any service code yet).
type Tx = Parameters<Parameters<typeof withRollback>[0]>[0];

const count = async (tx: Tx, table: string): Promise<number> => {
  const rows = await tx.$queryRawUnsafe<{ n: bigint }[]>(`SELECT count(*) AS n FROM "${table}"`);
  return Number(rows[0].n);
};

// Run a statement that must fail without aborting the surrounding transaction.
const rejects = async (tx: Tx, sql: string, ...params: unknown[]) => {
  await tx.$executeRawUnsafe('SAVEPOINT chk');
  await assert.rejects(() => tx.$executeRawUnsafe(sql, ...params));
  await tx.$executeRawUnsafe('ROLLBACK TO SAVEPOINT chk');
};

const seed = async (tx: Tx) => {
  const owner = await createUser(tx, { accountRole: 'CLUB_OWNER' });
  const fan = await createUser(tx);
  const event = await createEvent(tx, owner.id);
  return { fan, event };
};

describe('T-039 engagement tracking tables', { skip: dbTestSkipReason() }, () => {
  after(closeTestPrisma);

  it('the three tables exist and are empty', () =>
    withRollback(async (tx) => {
      for (const t of ['EventInterest', 'UserRecentEventView', 'EventViewDaily']) {
        assert.equal(await count(tx, t), 0, `${t} must be empty`);
      }
    }));

  it('EventInterest: (userId, eventId) is unique, a second user may tap the same event', () =>
    withRollback(async (tx) => {
      const { fan, event } = await seed(tx);
      const other = await createUser(tx);
      const ins = `INSERT INTO "EventInterest" (id, "userId", "eventId") VALUES ($1, $2, $3)`;
      await tx.$executeRawUnsafe(ins, 't039-i1', fan.id, event.id);
      await rejects(tx, ins, 't039-i2', fan.id, event.id);
      await tx.$executeRawUnsafe(ins, 't039-i3', other.id, event.id);
      const rows = await tx.$queryRaw<{ createdAt: Date }[]>`
        SELECT "createdAt" FROM "EventInterest" WHERE id = 't039-i1'`;
      assert.ok(rows[0].createdAt instanceof Date, 'createdAt defaults to now()');
      assert.equal(await count(tx, 'EventInterest'), 2);
    }));

  it('UserRecentEventView: (userId, eventId) is unique, lastViewedAt defaults to now()', () =>
    withRollback(async (tx) => {
      const { fan, event } = await seed(tx);
      const ins = `INSERT INTO "UserRecentEventView" (id, "userId", "eventId") VALUES ($1, $2, $3)`;
      await tx.$executeRawUnsafe(ins, 't039-v1', fan.id, event.id);
      await rejects(tx, ins, 't039-v2', fan.id, event.id);
      const rows = await tx.$queryRaw<{ lastViewedAt: Date }[]>`
        SELECT "lastViewedAt" FROM "UserRecentEventView" WHERE id = 't039-v1'`;
      assert.ok(rows[0].lastViewedAt instanceof Date);
    }));

  it('EventViewDaily: composite primary key (eventId, day) rejects a duplicate', () =>
    withRollback(async (tx) => {
      const { event } = await seed(tx);
      const ins = `INSERT INTO "EventViewDaily" ("eventId", day, views) VALUES ($1, $2::date, $3)`;
      await tx.$executeRawUnsafe(ins, event.id, '2026-11-23', 1);
      await rejects(tx, ins, event.id, '2026-11-23', 5);
      await tx.$executeRawUnsafe(ins, event.id, '2026-11-24', 1);
      const pk = await tx.$queryRaw<{ n: bigint }[]>`
        SELECT count(*) AS n FROM pg_constraint
        WHERE conrelid = '"EventViewDaily"'::regclass AND contype = 'p'`;
      assert.equal(Number(pk[0].n), 1);
    }));

  it('deleting a user cascades to its interests and recent views', () =>
    withRollback(async (tx) => {
      const { fan, event } = await seed(tx);
      await tx.$executeRawUnsafe(
        `INSERT INTO "EventInterest" (id, "userId", "eventId") VALUES ('t039-c1', $1, $2)`,
        fan.id,
        event.id
      );
      await tx.$executeRawUnsafe(
        `INSERT INTO "UserRecentEventView" (id, "userId", "eventId") VALUES ('t039-c2', $1, $2)`,
        fan.id,
        event.id
      );
      await tx.$executeRawUnsafe(`DELETE FROM "User" WHERE id = $1`, fan.id);
      assert.equal(await count(tx, 'EventInterest'), 0);
      assert.equal(await count(tx, 'UserRecentEventView'), 0);
    }));

  it('deleting an event cascades to interests, recent views and daily counts', () =>
    withRollback(async (tx) => {
      const { fan, event } = await seed(tx);
      await tx.$executeRawUnsafe(
        `INSERT INTO "EventInterest" (id, "userId", "eventId") VALUES ('t039-d1', $1, $2)`,
        fan.id,
        event.id
      );
      await tx.$executeRawUnsafe(
        `INSERT INTO "UserRecentEventView" (id, "userId", "eventId") VALUES ('t039-d2', $1, $2)`,
        fan.id,
        event.id
      );
      await tx.$executeRawUnsafe(
        `INSERT INTO "EventViewDaily" ("eventId", day, views) VALUES ($1, '2026-11-23'::date, 3)`,
        event.id
      );
      await tx.$executeRawUnsafe(`DELETE FROM "Event" WHERE id = $1`, event.id);
      assert.equal(await count(tx, 'EventInterest'), 0);
      assert.equal(await count(tx, 'UserRecentEventView'), 0);
      assert.equal(await count(tx, 'EventViewDaily'), 0);
    }));

  it('indexes from data-model 8.2 exist', () =>
    withRollback(async (tx) => {
      const rows = await tx.$queryRaw<{ indexname: string }[]>`
        SELECT indexname FROM pg_indexes
        WHERE tablename IN ('EventInterest', 'UserRecentEventView') ORDER BY indexname`;
      const names = rows.map((r) => r.indexname);
      assert.ok(names.includes('EventInterest_eventId_createdAt_idx'));
      assert.ok(names.includes('UserRecentEventView_userId_lastViewedAt_idx'));
    }));
});
