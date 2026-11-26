import { after, describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { closeTestPrisma, dbTestSkipReason, withRollback } from '@/testing/testDb';
import { createClub, createEvent, createUser } from '@/testing/fixtures';

// T-029: the backfill migration fills geog only where it is NULL and lat/lng are valid.
const MIGRATION = resolve(
  process.cwd(),
  '../prisma/migrations/20261123140000_backfill_geog/migration.sql'
);

const statements = (): string[] =>
  readFileSync(MIGRATION, 'utf8')
    .split('\n')
    .filter((l) => !l.trim().startsWith('--'))
    .join('\n')
    .split(';')
    .map((s) => s.trim())
    .filter(Boolean);

describe('T-029 geog backfill migration', { skip: dbTestSkipReason() }, () => {
  after(closeTestPrisma);

  it('fills NULL geog for valid coordinates, leaves invalid ones NULL, never overwrites, is idempotent', async () => {
    await withRollback(async (tx) => {
      const owner = await createUser(tx, { accountRole: 'CLUB_OWNER' });
      const clubOk = await createClub(tx, owner.id, { lat: 41.9, lng: 12.5 });
      const clubBad = await createClub(tx, owner.id, { lat: 123, lng: 12.5 });
      const clubNaN = await createClub(tx, owner.id, { lat: 1, lng: 1 });
      const clubSet = await createClub(tx, owner.id, { lat: 10, lng: 10 });
      const evOk = await createEvent(tx, owner.id, { lat: 45.46, lng: 9.19 });
      const evBad = await createEvent(tx, owner.id, { lat: 10, lng: 200 });
      const evInf = await createEvent(tx, owner.id, { lat: 1, lng: 1 });
      const evSet = await createEvent(tx, owner.id, { lat: 20, lng: 20 });

      // Prisma rejects NaN and Infinity, so set them with raw SQL.
      await tx.$executeRawUnsafe(`UPDATE "Club" SET lat = 'NaN'::float8 WHERE id = '${clubNaN.id}'`);
      await tx.$executeRawUnsafe(`UPDATE "Event" SET lng = 'Infinity'::float8 WHERE id = '${evInf.id}'`);

      // An existing geog that disagrees with lat/lng must survive untouched.
      await tx.$executeRawUnsafe(
        `UPDATE "Club" SET geog = ST_SetSRID(ST_MakePoint(1, 2), 4326)::geography WHERE id = '${clubSet.id}'`
      );
      await tx.$executeRawUnsafe(
        `UPDATE "Event" SET geog = ST_SetSRID(ST_MakePoint(3, 4), 4326)::geography WHERE id = '${evSet.id}'`
      );

      const read = async () => {
        const ids = [clubOk.id, clubBad.id, clubNaN.id, clubSet.id];
        const eids = [evOk.id, evBad.id, evInf.id, evSet.id];
        const c = await tx.$queryRawUnsafe<{ id: string; g: string | null }[]>(
          `SELECT id, ST_AsText(geog::geometry) AS g FROM "Club" WHERE id = ANY($1::text[])`,
          ids
        );
        const e = await tx.$queryRawUnsafe<{ id: string; g: string | null }[]>(
          `SELECT id, ST_AsText(geog::geometry) AS g FROM "Event" WHERE id = ANY($1::text[])`,
          eids
        );
        return Object.fromEntries([...c, ...e].map((r) => [r.id, r.g]));
      };

      const before = await read();
      assert.equal(before[clubOk.id], null);

      for (const s of statements()) await tx.$executeRawUnsafe(s);
      const first = await read();
      assert.equal(first[clubOk.id], 'POINT(12.5 41.9)');
      assert.equal(first[clubBad.id], null);
      assert.equal(first[clubNaN.id], null);
      assert.equal(first[clubSet.id], 'POINT(1 2)');
      assert.equal(first[evOk.id], 'POINT(9.19 45.46)');
      assert.equal(first[evBad.id], null);
      assert.equal(first[evInf.id], null);
      assert.equal(first[evSet.id], 'POINT(3 4)');

      for (const s of statements()) await tx.$executeRawUnsafe(s);
      assert.deepEqual(await read(), first);
    });
  });
});
