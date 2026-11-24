import { after, describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { resolve } from 'node:path';
import { readFileSync } from 'node:fs';
import { closeTestPrisma, dbTestSkipReason, withRollback } from '@/testing/testDb';

// T-032: tests for backend/server/scripts/seed-discovery.ts. The task names
// scripts/seed-discovery.test.ts, but DB tests must be *.db.test.ts under src/ to be picked up
// by `npm run test:db`. The script lives outside tsconfig rootDir (src), so it is loaded with a
// runtime require (tsx) instead of a static import, and typed here.
type FilterItem = { labelKey: string; label: string; labelIt: string };
type CityItem = {
  name: string;
  countryCode: string;
  lat: number;
  lng: number;
  timezone: string;
  isLaunched: boolean;
};
type FilterData = { genres: FilterItem[]; moods: FilterItem[] };
type CityData = { cities: CityItem[] };
type Tx = Parameters<Parameters<ReturnType<typeof import('@/testing/testDb').getTestPrisma>['$transaction']>[0]>[0];
type Seed = {
  loadSeedData: () => { filterOptions: FilterData; cities: CityData };
  validateSeedData: (d: { filterOptions: FilterData; cities: CityData }) => void;
  applySeed: (tx: Tx, d: { filterOptions: FilterData; cities: CityData }) => Promise<void>;
  resolveSeedDatabaseUrl: (env: Record<string, string | undefined>) => string;
};
const seed: Seed = require(resolve(process.cwd(), 'scripts/seed-discovery.ts'));

const GENRES = [
  'House',
  'Techno',
  'Tech House',
  'Deep House',
  'Melodic House & Techno',
  'Afro House',
  'Disco & Nu-Disco',
  'Hip-Hop & Rap',
  'R&B',
  'Reggaeton',
  'Latin',
  'Pop & Commercial',
  'EDM',
  'Drum & Bass',
  'Rock & Indie',
];
const MOODS = [
  'Party',
  'Chill',
  'Underground',
  'Elegant',
  'Exclusive',
  'Social',
  'Romantic',
  'High Energy',
];

const clone = <T>(v: T): T => JSON.parse(JSON.stringify(v));
const counts = async (tx: Tx) => ({
  genre: await tx.filterOption.count({ where: { kind: 'GENRE' } }),
  mood: await tx.filterOption.count({ where: { kind: 'MOOD' } }),
  city: await tx.city.count(),
});

describe('T-032 seed data files (no database)', () => {
  const data = seed.loadSeedData();

  it('genres are the client list in the client order (15)', () => {
    assert.deepEqual(
      data.filterOptions.genres.map((g) => g.label),
      GENRES
    );
    assert.equal(data.filterOptions.genres.length, 15);
  });

  it('moods are the client list in the client order (8) with Italian labels', () => {
    assert.deepEqual(
      data.filterOptions.moods.map((m) => m.label),
      MOODS
    );
    assert.equal(data.filterOptions.moods.length, 8);
    assert.deepEqual(
      data.filterOptions.moods.map((m) => m.labelIt),
      ['Festa', 'Relax', 'Underground', 'Elegante', 'Esclusivo', 'Social', 'Romantico', 'Alta energia']
    );
  });

  it('every seeded city is inactive and the file passes validation', () => {
    assert.ok(data.cities.cities.length > 0);
    for (const c of data.cities.cities) assert.equal(c.isLaunched, false, c.name);
    assert.doesNotThrow(() => seed.validateSeedData(data));
  });

  it('cities cover the client destinations, Monaco is its own country code', () => {
    const key = (c: CityItem) => `${c.name}|${c.countryCode}`;
    assert.deepEqual(data.cities.cities.map(key).sort(), [
      'Barcelona|ES',
      'Bologna|IT',
      "Côte d'Azur|FR",
      'Las Vegas|US',
      'Madrid|ES',
      'Milan|IT',
      'Monaco|MC',
      'New York|US',
      'Paris|FR',
      'Rome|IT',
      'Turin|IT',
    ]);
  });

  it('validation rejects an invalid timezone, coordinate or duplicate key', () => {
    const bad = (mutate: (d: ReturnType<typeof seed.loadSeedData>) => void, re: RegExp) => {
      const d = clone(data);
      mutate(d);
      assert.throws(() => seed.validateSeedData(d), re);
    };
    bad((d) => (d.cities.cities[0].timezone = 'Mars/Olympus'), /timezone/i);
    bad((d) => (d.cities.cities[0].lat = 91), /lat/i);
    bad((d) => (d.cities.cities[0].lng = -181), /lng/i);
    bad((d) => (d.cities.cities[0].lat = Number.NaN), /lat/i);
    bad((d) => (d.filterOptions.genres[1].labelKey = d.filterOptions.genres[0].labelKey), /duplicate/i);
    bad((d) => (d.filterOptions.moods[0].label = '  '), /label/i);
  });

  it('refuses a database that is not a local *_test or *_rehearsal one', () => {
    const url = (db: string, host = 'localhost') =>
      `postgresql://postgres:x@${host}:5441/${db}?schema=public`;
    assert.throws(() => seed.resolveSeedDatabaseUrl({}), /DATABASE_URL/);
    assert.throws(() => seed.resolveSeedDatabaseUrl({ DATABASE_URL: url('bookdianight') }), /Refusing/);
    assert.throws(() => seed.resolveSeedDatabaseUrl({ DATABASE_URL: url('prod_db', 'db.example.com') }), /Refusing/);
    assert.throws(
      () => seed.resolveSeedDatabaseUrl({ DATABASE_URL: url('x_test', 'db.example.com') }),
      /Refusing/
    );
    assert.equal(seed.resolveSeedDatabaseUrl({ DATABASE_URL: url('t032_test') }), url('t032_test'));
    assert.equal(
      seed.resolveSeedDatabaseUrl({ DATABASE_URL: url('t032_rehearsal', '127.0.0.1') }),
      url('t032_rehearsal', '127.0.0.1')
    );
  });

  it('data files carry the provisional-coordinates and placeholder markers', () => {
    const raw = readFileSync(resolve(process.cwd(), 'scripts/data/cities.json'), 'utf8');
    assert.match(raw, /"coordinatesProvisional": true/);
    assert.match(raw, /PLACEHOLDER/);
  });
});

describe('T-032 seed-discovery against Postgres', { skip: dbTestSkipReason() }, () => {
  after(closeTestPrisma);

  it('seeds 15 genres, 8 moods and the cities, and a second run changes nothing', () =>
    withRollback(async (tx) => {
      const data = seed.loadSeedData();
      const before = await counts(tx);
      await seed.applySeed(tx, data);
      const first = await counts(tx);
      assert.equal(first.genre - before.genre <= 15, true);
      for (const g of data.filterOptions.genres) {
        const row = await tx.filterOption.findUnique({
          where: { kind_labelKey: { kind: 'GENRE', labelKey: g.labelKey } },
        });
        assert.equal(row?.label, g.label);
      }
      const genreRows = await tx.filterOption.findMany({
        where: { kind: 'GENRE', labelKey: { in: data.filterOptions.genres.map((g) => g.labelKey) } },
        orderBy: { sortOrder: 'asc' },
      });
      assert.deepEqual(genreRows.map((r) => r.label), GENRES);
      const moodRows = await tx.filterOption.findMany({
        where: { kind: 'MOOD', labelKey: { in: data.filterOptions.moods.map((g) => g.labelKey) } },
        orderBy: { sortOrder: 'asc' },
      });
      assert.deepEqual(moodRows.map((r) => r.label), MOODS);
      assert.equal(first.city - before.city, data.cities.cities.length);
      const stamp = await tx.city.findMany({ orderBy: { name: 'asc' } });

      await seed.applySeed(tx, data);
      assert.deepEqual(await counts(tx), first);
      assert.deepEqual(await tx.city.findMany({ orderBy: { name: 'asc' } }), stamp);
      assert.equal(await tx.city.count({ where: { isLaunched: true } }), 0);
    }));

  it('an edited label and edited coordinates update in place (same row ids)', () =>
    withRollback(async (tx) => {
      const data = seed.loadSeedData();
      await seed.applySeed(tx, data);
      const g0 = data.filterOptions.genres[0];
      const c0 = data.cities.cities[0];
      const gBefore = await tx.filterOption.findUniqueOrThrow({
        where: { kind_labelKey: { kind: 'GENRE', labelKey: g0.labelKey } },
      });
      const cBefore = await tx.city.findUniqueOrThrow({
        where: { name_countryCode: { name: c0.name, countryCode: c0.countryCode } },
      });
      const total = await counts(tx);

      const edited = clone(data);
      edited.filterOptions.genres[0].label = 'House (edited)';
      edited.cities.cities[0].lat = 10.5;
      await seed.applySeed(tx, edited);

      const gAfter = await tx.filterOption.findUniqueOrThrow({
        where: { kind_labelKey: { kind: 'GENRE', labelKey: g0.labelKey } },
      });
      const cAfter = await tx.city.findUniqueOrThrow({
        where: { name_countryCode: { name: c0.name, countryCode: c0.countryCode } },
      });
      assert.equal(gAfter.id, gBefore.id);
      assert.equal(gAfter.label, 'House (edited)');
      assert.equal(cAfter.id, cBefore.id);
      assert.equal(cAfter.lat, 10.5);
      assert.deepEqual(await counts(tx), total);
    }));

  it('a re-run does not re-activate a deactivated option nor deactivate a launched city', () =>
    withRollback(async (tx) => {
      const data = seed.loadSeedData();
      await seed.applySeed(tx, data);
      const g0 = data.filterOptions.genres[0];
      const c0 = data.cities.cities[0];
      await tx.filterOption.update({
        where: { kind_labelKey: { kind: 'GENRE', labelKey: g0.labelKey } },
        data: { isActive: false },
      });
      await tx.city.update({
        where: { name_countryCode: { name: c0.name, countryCode: c0.countryCode } },
        data: { isLaunched: true },
      });
      await seed.applySeed(tx, data);
      const g = await tx.filterOption.findUniqueOrThrow({
        where: { kind_labelKey: { kind: 'GENRE', labelKey: g0.labelKey } },
      });
      const c = await tx.city.findUniqueOrThrow({
        where: { name_countryCode: { name: c0.name, countryCode: c0.countryCode } },
      });
      assert.equal(g.isActive, false);
      assert.equal(c.isLaunched, true);
    }));

  it('invalid data aborts with a clear message and writes nothing', () =>
    withRollback(async (tx) => {
      const data = seed.loadSeedData();
      const before = await counts(tx);
      const bad = clone(data);
      bad.cities.cities[bad.cities.cities.length - 1].timezone = 'Not/AZone';
      await assert.rejects(() => seed.applySeed(tx, bad), /timezone.*Not\/AZone/i);
      assert.deepEqual(await counts(tx), before);

      const bad2 = clone(data);
      bad2.cities.cities[bad2.cities.cities.length - 1].lng = 500;
      await assert.rejects(() => seed.applySeed(tx, bad2), /lng/i);
      assert.deepEqual(await counts(tx), before);
    }));
});
