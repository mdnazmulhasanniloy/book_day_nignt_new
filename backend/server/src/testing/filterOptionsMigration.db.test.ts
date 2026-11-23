import { after, describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { closeTestPrisma, dbTestSkipReason, withRollback } from '@/testing/testDb';
import { createEvent, createUser } from '@/testing/fixtures';

// T-031 (migration 10): City and FilterOption tables, backfill of FilterOption from the genre and
// mood text found on events. Raw SQL on purpose: it checks the database objects themselves.
const MIGRATION = resolve(
  process.cwd(),
  '../prisma/migrations/20261123150000_add_cities_filter_options/migration.sql'
);

// The backfill is the INSERT statements of the migration (the DDL is already applied).
const backfillStatements = (): string[] =>
  readFileSync(MIGRATION, 'utf8')
    .split('\n')
    .filter((l) => !l.trim().startsWith('--'))
    .join('\n')
    .split(';')
    .map((s) => s.trim())
    .filter((s) => /^INSERT INTO "FilterOption"/i.test(s));

type Row = { kind: string; label: string; labelKey: string; sortOrder: number; isActive: boolean };

describe('T-031 cities and filter options', { skip: dbTestSkipReason() }, () => {
  after(closeTestPrisma);

  it('City starts empty and a city can be created inactive (isLaunched defaults to false)', () =>
    withRollback(async (tx) => {
      const before = await tx.$queryRaw<{ n: bigint }[]>`SELECT count(*) AS n FROM "City"`;
      assert.equal(Number(before[0].n), 0);
      await tx.$executeRawUnsafe(
        `INSERT INTO "City" (id, name, "countryCode", lat, lng, "updatedAt")
         VALUES ('t031-city', 'T031 Town', 'IT', 41.9, 12.5, now())`
      );
      const rows = await tx.$queryRaw<{ isLaunched: boolean; timezone: string }[]>`
        SELECT "isLaunched", timezone FROM "City" WHERE id = 't031-city'`;
      assert.equal(rows[0].isLaunched, false);
      assert.equal(rows[0].timezone, 'UTC');
    }));

  it('City (name, countryCode) is unique', () =>
    withRollback(async (tx) => {
      const ins = `INSERT INTO "City" (id, name, "countryCode", lat, lng, "updatedAt")
                   VALUES ($1, 'T031 Dup', 'IT', 1, 1, now())`;
      await tx.$executeRawUnsafe(ins, 't031-a');
      await assert.rejects(() => tx.$executeRawUnsafe(ins, 't031-b'));
    }));

  it('FilterOption defaults to active, sortOrder 0, and (kind, labelKey) is unique', () =>
    withRollback(async (tx) => {
      const ins = `INSERT INTO "FilterOption" (id, kind, label, "labelKey", "updatedAt")
                   VALUES ($1, 'GENRE'::"FilterOptionKind", 'T031 X', 't031 x', now())`;
      await tx.$executeRawUnsafe(ins, 't031-f1');
      const rows = await tx.$queryRaw<Row[]>`
        SELECT "isActive", "sortOrder" FROM "FilterOption" WHERE id = 't031-f1'`;
      assert.equal(rows[0].isActive, true);
      assert.equal(rows[0].sortOrder, 0);
      await tx.$executeRawUnsafe('SAVEPOINT dup');
      await assert.rejects(() => tx.$executeRawUnsafe(ins, 't031-f2'));
      await tx.$executeRawUnsafe('ROLLBACK TO SAVEPOINT dup');
      // the same key under the other kind is allowed
      await tx.$executeRawUnsafe(
        `INSERT INTO "FilterOption" (id, kind, label, "labelKey", "updatedAt")
         VALUES ('t031-f3', 'MOOD'::"FilterOptionKind", 'T031 X', 't031 x', now())`
      );
    }));

  it('backfill: trimmed, case-insensitive de-duplication, alphabetical sortOrder, idempotent, City untouched', () =>
    withRollback(async (tx) => {
      const owner = await createUser(tx, { accountRole: 'CLUB_OWNER' });
      await createEvent(tx, owner.id, {
        musicGenres: ['t031 Techno', '  t031 techno ', 't031 House', '', '   '],
        moodTags: ['t031 Chill', 'T031 CHILL', 't031 Wild'],
      });
      await createEvent(tx, owner.id, {
        musicGenres: ['t031 Techno', 't031 hip-hop'],
        moodTags: [],
      });
      assert.ok(backfillStatements().length >= 2, 'migration has a GENRE and a MOOD backfill');

      const read = () =>
        tx.$queryRaw<Row[]>`
          SELECT kind::text AS kind, label, "labelKey", "sortOrder", "isActive"
          FROM "FilterOption" WHERE "labelKey" LIKE 't031 %' ORDER BY kind, "sortOrder", "labelKey"`;
      assert.equal((await read()).length, 0);

      for (const s of backfillStatements()) await tx.$executeRawUnsafe(s);
      const first = await read();
      const genres = first.filter((r) => r.kind === 'GENRE');
      const moods = first.filter((r) => r.kind === 'MOOD');
      assert.deepEqual(
        genres.map((r) => r.labelKey),
        ['t031 hip-hop', 't031 house', 't031 techno']
      );
      assert.deepEqual(moods.map((r) => r.labelKey), ['t031 chill', 't031 wild']);
      assert.ok(first.every((r) => r.isActive));
      // sortOrder follows the alphabetical order of labelKey inside a kind
      for (const list of [genres, moods]) {
        const orders = list.map((r) => r.sortOrder);
        assert.deepEqual(orders, [...orders].sort((a, b) => a - b));
        assert.equal(new Set(orders).size, orders.length);
      }
      // labels are trimmed; no empty label was created
      assert.ok(first.every((r) => r.label === r.label.trim() && r.label.length > 0));
      // the most frequent spelling wins for the label ("t031 Techno" appears twice, the lower-case spelling once)
      assert.equal(genres.find((r) => r.labelKey === 't031 techno')?.label, 't031 Techno');

      // second run changes nothing
      for (const s of backfillStatements()) await tx.$executeRawUnsafe(s);
      assert.deepEqual(await read(), first);

      const cities = await tx.$queryRaw<{ n: bigint }[]>`SELECT count(*) AS n FROM "City"`;
      assert.equal(Number(cities[0].n), 0);
    }));
});
