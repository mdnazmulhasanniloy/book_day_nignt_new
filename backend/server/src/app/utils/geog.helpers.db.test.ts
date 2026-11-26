import { after, describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { closeTestPrisma, dbTestSkipReason, withRollback } from '@/testing/testDb';
import { createClub, createEvent, createUser } from '@/testing/fixtures';
import { syncGeogFromLatLng } from '@/app/utils/geog.helpers';

// T-030: the helper writes geog from the stored lat/lng and never writes a bad geography.
describe('syncGeogFromLatLng (T-030)', { skip: dbTestSkipReason() }, () => {
  after(closeTestPrisma);

  it('writes valid coordinates and skips NaN, Infinity and out-of-range values (Event and Club)', async () => {
    await withRollback(async (tx) => {
      const owner = await createUser(tx, { accountRole: 'CLUB_OWNER' });
      const cases: Array<[number, number, boolean]> = [
        [10, 20, true],
        [Number.NaN, 20, false],
        [10, Number.POSITIVE_INFINITY, false],
        [91, 20, false],
        [10, -181, false],
      ];
      for (const [lat, lng, ok] of cases) {
        // Prisma refuses NaN/Infinity on create, so the coordinates are forced in with SQL.
        const ev = await createEvent(tx, owner.id, { lat: 0, lng: 0 });
        const cl = await createClub(tx, owner.id, { lat: 0, lng: 0 });
        await tx.$executeRaw`UPDATE "Event" SET lat = ${String(lat)}::float8, lng = ${String(lng)}::float8, geog = NULL WHERE id = ${ev.id}`;
        await tx.$executeRaw`UPDATE "Club" SET lat = ${String(lat)}::float8, lng = ${String(lng)}::float8, geog = NULL WHERE id = ${cl.id}`;
        assert.equal(await syncGeogFromLatLng({ tx, table: 'Event', id: ev.id }), ok, `event ${lat},${lng}`);
        assert.equal(await syncGeogFromLatLng({ tx, table: 'Club', id: cl.id }), ok, `club ${lat},${lng}`);
        const e = await tx.$queryRaw<{ n: bigint }[]>`SELECT COUNT(*) AS n FROM "Event" WHERE id = ${ev.id} AND geog IS NOT NULL`;
        const c = await tx.$queryRaw<{ n: bigint }[]>`SELECT COUNT(*) AS n FROM "Club" WHERE id = ${cl.id} AND geog IS NOT NULL`;
        assert.equal(Number(e[0].n), ok ? 1 : 0);
        assert.equal(Number(c[0].n), ok ? 1 : 0);
      }
    });
  });

  it('an unknown id writes nothing', async () => {
    await withRollback(async (tx) => {
      assert.equal(
        await syncGeogFromLatLng({ tx, table: 'Event', id: '00000000-0000-4000-8000-000000000000' }),
        false
      );
    });
  });
});
