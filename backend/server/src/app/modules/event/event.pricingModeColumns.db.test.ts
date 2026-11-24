import { after, describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  closeTestPrisma,
  dbTestSkipReason,
  withRollback,
} from '@/testing/testDb';
import { createEvent, createTier, createUser } from '@/testing/fixtures';

// T-015 (migration 4): expand-only columns. Raw SQL on purpose: it checks the database defaults
// and enums themselves, independent of the generated client.
describe('T-015 event timezone, pricing mode and tier type columns', { skip: dbTestSkipReason() }, () => {
  after(closeTestPrisma);

  it('an event created the old way gets timezone UTC and pricingMode SINGLE', () =>
    withRollback(async (tx) => {
      const owner = await createUser(tx, { accountRole: 'CLUB_OWNER' });
      const event = await createEvent(tx, owner.id);
      const rows = await tx.$queryRaw<{ timezone: string; pricingMode: string }[]>`
        SELECT "timezone", "pricingMode"::text AS "pricingMode" FROM "Event" WHERE id = ${event.id}`;
      assert.equal(rows[0].timezone, 'UTC');
      assert.equal(rows[0].pricingMode, 'SINGLE');
    }));

  it('a tier created the old way gets tierType TICKET', () =>
    withRollback(async (tx) => {
      const owner = await createUser(tx, { accountRole: 'CLUB_OWNER' });
      const event = await createEvent(tx, owner.id);
      const tier = await createTier(tx, event.id);
      const rows = await tx.$queryRaw<{ tierType: string }[]>`
        SELECT "tierType"::text AS "tierType" FROM "EventTicketTier" WHERE id = ${tier.id}`;
      assert.equal(rows[0].tierType, 'TICKET');
    }));

  it('enums have exactly the documented values', () =>
    withRollback(async (tx) => {
      const pm = await tx.$queryRaw<{ v: string }[]>`
        SELECT unnest(enum_range(NULL::"PricingMode"))::text AS v`;
      assert.deepEqual(pm.map((r) => r.v).sort(), ['FREE', 'MIXED', 'SINGLE', 'TIERED']);
      const tt = await tx.$queryRaw<{ v: string }[]>`
        SELECT unnest(enum_range(NULL::"TierType"))::text AS v`;
      assert.deepEqual(tt.map((r) => r.v).sort(), ['PASS', 'TICKET']);
    }));

  it('the new columns are NOT NULL', () =>
    withRollback(async (tx) => {
      const rows = await tx.$queryRaw<{ table_name: string; column_name: string; is_nullable: string }[]>`
        SELECT table_name, column_name, is_nullable FROM information_schema.columns
        WHERE (table_name = 'Event' AND column_name IN ('timezone', 'pricingMode'))
           OR (table_name = 'EventTicketTier' AND column_name = 'tierType')`;
      assert.equal(rows.length, 3);
      for (const r of rows) assert.equal(r.is_nullable, 'NO', `${r.table_name}.${r.column_name}`);
    }));
});
