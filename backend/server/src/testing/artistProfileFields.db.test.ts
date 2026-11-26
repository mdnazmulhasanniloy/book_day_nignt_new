import { after, describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { closeTestPrisma, dbTestSkipReason, withRollback } from '@/testing/testDb';

// T-043 (migration 12): Artist.bio TEXT NULL and Artist.socialLinks JSONB NULL. Raw SQL on purpose:
// it checks the database columns themselves (no service code reads them yet, T-044 does).
describe('T-043 artist profile fields', { skip: dbTestSkipReason() }, () => {
  after(closeTestPrisma);

  it('bio and socialLinks exist with the documented types and are nullable', () =>
    withRollback(async (tx) => {
      const cols = await tx.$queryRaw<{ column_name: string; data_type: string; is_nullable: string; column_default: string | null }[]>`
        SELECT column_name, data_type, is_nullable, column_default FROM information_schema.columns
        WHERE table_name = 'Artist' AND column_name IN ('bio', 'socialLinks') ORDER BY column_name`;
      assert.equal(cols.length, 2, 'both columns must exist');
      assert.deepEqual(cols[0], { column_name: 'bio', data_type: 'text', is_nullable: 'YES', column_default: null });
      assert.deepEqual(cols[1], { column_name: 'socialLinks', data_type: 'jsonb', is_nullable: 'YES', column_default: null });
    }));

  it('an artist created without the new fields has both NULL; values round-trip', () =>
    withRollback(async (tx) => {
      await tx.$executeRawUnsafe(`INSERT INTO "Artist" (id, name, "nameKey", "updatedAt") VALUES ('t043-a1', 'A', 't043-a1', now())`);
      const a = await tx.$queryRaw<{ bio: string | null; socialLinks: unknown }[]>`SELECT bio, "socialLinks" FROM "Artist" WHERE id = 't043-a1'`;
      assert.equal(a[0].bio, null);
      assert.equal(a[0].socialLinks, null);
      await tx.$executeRawUnsafe(`UPDATE "Artist" SET bio = 'Hello', "socialLinks" = '{"instagram":"https://x.test/a"}'::jsonb WHERE id = 't043-a1'`);
      const b = await tx.$queryRaw<{ bio: string | null; socialLinks: Record<string, string> }[]>`SELECT bio, "socialLinks" FROM "Artist" WHERE id = 't043-a1'`;
      assert.equal(b[0].bio, 'Hello');
      assert.equal(b[0].socialLinks.instagram, 'https://x.test/a');
    }));
});
