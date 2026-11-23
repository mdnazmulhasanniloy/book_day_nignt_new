/**
 * T-032: idempotent seed of the discovery starter data.
 *  - FilterOption rows (GENRE, MOOD) upserted by (kind, labelKey) from scripts/data/filter-options.json
 *  - City rows upserted by (name, countryCode) from scripts/data/cities.json
 *
 * Safety: refuses to run unless DATABASE_URL points at a LOCAL database whose name ends in `_test`
 * or `_rehearsal`. The explicit override flag below exists for the release step only; never set it
 * from a script, a task or a test.
 *
 * Usage (from backend/server):
 *   DATABASE_URL=postgresql://...@localhost:5441/<name>_test npx tsx scripts/seed-discovery.ts
 *
 * Re-running changes nothing (unchanged rows are not even rewritten). On existing rows it updates label and sortOrder (filter options) and
 * lat, lng, timezone (cities). It never touches FilterOption.isActive or City.isLaunched, so an
 * admin's later edits and the activation of a city are not reverted. The whole file set is
 * validated first (first error aborts, nothing is written), then everything is written in one
 * transaction.
 */
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { Prisma, PrismaClient } from '@prisma/client';

export const ALLOW_NON_TEST_DB_FLAG = 'SEED_DISCOVERY_I_UNDERSTAND_THIS_IS_NOT_A_LOCAL_TEST_DATABASE';

export type FilterItem = { labelKey: string; label: string; labelIt: string };
export type CityItem = {
  name: string;
  countryCode: string;
  lat: number;
  lng: number;
  timezone: string;
  isLaunched: boolean;
};
export type FilterData = { genres: FilterItem[]; moods: FilterItem[] };
export type CityData = { cities: CityItem[] };
export type SeedData = { filterOptions: FilterData; cities: CityData };

const DATA_DIR = resolve(__dirname, 'data');

export const loadSeedData = (): SeedData => ({
  filterOptions: JSON.parse(readFileSync(resolve(DATA_DIR, 'filter-options.json'), 'utf8')),
  cities: JSON.parse(readFileSync(resolve(DATA_DIR, 'cities.json'), 'utf8')),
});

const isValidTimezone = (tz: unknown): boolean => {
  if (typeof tz !== 'string' || tz.trim() === '' || !tz.includes('/')) return false;
  try {
    new Intl.DateTimeFormat('en-US', { timeZone: tz });
    return true;
  } catch {
    return false;
  }
};

const fail = (message: string): never => {
  throw new Error(`seed-discovery: invalid data: ${message}`);
};

const validateFilterList = (kind: string, items: FilterItem[]): void => {
  if (!Array.isArray(items) || items.length === 0) fail(`${kind} list is empty or missing`);
  const seen = new Set<string>();
  items.forEach((it, i) => {
    const where = `${kind}[${i}]`;
    if (typeof it.label !== 'string' || it.label.trim() === '') fail(`${where} has an empty label`);
    if (typeof it.labelKey !== 'string' || it.labelKey.trim() === '') fail(`${where} has an empty labelKey`);
    if (it.labelKey !== it.labelKey.trim()) fail(`${where} labelKey has surrounding spaces`);
    if (seen.has(it.labelKey)) fail(`${where} duplicate labelKey "${it.labelKey}"`);
    seen.add(it.labelKey);
  });
};

/** Validates every file; throws on the first problem. Pure: no database access. */
export const validateSeedData = (data: SeedData): void => {
  validateFilterList('genres', data.filterOptions.genres);
  validateFilterList('moods', data.filterOptions.moods);
  const { cities } = data.cities;
  if (!Array.isArray(cities) || cities.length === 0) fail('cities list is empty or missing');
  const seen = new Set<string>();
  cities.forEach((c, i) => {
    const where = `cities[${i}] (${c.name})`;
    if (typeof c.name !== 'string' || c.name.trim() === '') fail(`${where} has an empty name`);
    if (typeof c.countryCode !== 'string' || !/^[A-Z]{2}$/.test(c.countryCode)) {
      fail(`${where} countryCode must be two upper-case letters, got "${c.countryCode}"`);
    }
    if (!Number.isFinite(c.lat) || c.lat < -90 || c.lat > 90) fail(`${where} lat out of range: ${c.lat}`);
    if (!Number.isFinite(c.lng) || c.lng < -180 || c.lng > 180) fail(`${where} lng out of range: ${c.lng}`);
    if (!isValidTimezone(c.timezone)) fail(`${where} timezone is not a valid IANA zone: "${c.timezone}"`);
    if (typeof c.isLaunched !== 'boolean') fail(`${where} isLaunched must be a boolean`);
    const key = `${c.name}|${c.countryCode}`;
    if (seen.has(key)) fail(`${where} duplicate city ${key}`);
    seen.add(key);
  });
};

/** Validates, then upserts. `tx` must be a transaction (or any client the caller controls). */
export const applySeed = async (tx: Prisma.TransactionClient, data: SeedData): Promise<void> => {
  validateSeedData(data);
  const lists = [
    ['GENRE', data.filterOptions.genres],
    ['MOOD', data.filterOptions.moods],
  ] as const;
  // Only rows that are new or differ are written, so a re-run leaves updatedAt untouched too.
  for (const [kind, items] of lists) {
    for (const [index, it] of items.entries()) {
      const where = { kind_labelKey: { kind, labelKey: it.labelKey } };
      const existing = await tx.filterOption.findUnique({ where });
      if (!existing) {
        await tx.filterOption.create({
          data: { kind, labelKey: it.labelKey, label: it.label, sortOrder: index },
        });
      } else if (existing.label !== it.label || existing.sortOrder !== index) {
        await tx.filterOption.update({ where, data: { label: it.label, sortOrder: index } });
      }
    }
  }
  for (const c of data.cities.cities) {
    const where = { name_countryCode: { name: c.name, countryCode: c.countryCode } };
    const existing = await tx.city.findUnique({ where });
    if (!existing) {
      await tx.city.create({
        data: {
          name: c.name,
          countryCode: c.countryCode,
          lat: c.lat,
          lng: c.lng,
          timezone: c.timezone,
          isLaunched: c.isLaunched,
        },
      });
    } else if (existing.lat !== c.lat || existing.lng !== c.lng || existing.timezone !== c.timezone) {
      await tx.city.update({ where, data: { lat: c.lat, lng: c.lng, timezone: c.timezone } });
    }
  }
};

/** Validates first (nothing written on error), then writes everything in one transaction. */
export const seedDiscovery = async (prisma: PrismaClient, data: SeedData): Promise<void> => {
  validateSeedData(data);
  await prisma.$transaction((tx) => applySeed(tx, data), { timeout: 60000 });
};

/** Returns DATABASE_URL if it is a local *_test or *_rehearsal database, else throws. */
export const resolveSeedDatabaseUrl = (env: Record<string, string | undefined>): string => {
  const url = env.DATABASE_URL;
  if (!url) throw new Error('seed-discovery: DATABASE_URL is not set');
  if (env[ALLOW_NON_TEST_DB_FLAG] === 'yes') return url;
  let dbName = '';
  let host = '';
  try {
    const parsed = new URL(url);
    dbName = decodeURIComponent(parsed.pathname.replace(/^\//, ''));
    host = parsed.hostname;
  } catch {
    throw new Error('seed-discovery: DATABASE_URL is not a valid URL');
  }
  if (!/_(test|rehearsal)$/.test(dbName)) {
    throw new Error(`Refusing to run: database "${dbName}" must end in _test or _rehearsal`);
  }
  if (!['localhost', '127.0.0.1', '::1', '[::1]'].includes(host)) {
    throw new Error(`Refusing to run: host "${host}" is not local`);
  }
  return url;
};

const main = async (): Promise<void> => {
  const url = resolveSeedDatabaseUrl(process.env);
  const data = loadSeedData();
  validateSeedData(data);
  const prisma = new PrismaClient({ datasourceUrl: url });
  try {
    await seedDiscovery(prisma, data);
    const [genres, moods, cities, launched] = await Promise.all([
      prisma.filterOption.count({ where: { kind: 'GENRE' } }),
      prisma.filterOption.count({ where: { kind: 'MOOD' } }),
      prisma.city.count(),
      prisma.city.count({ where: { isLaunched: true } }),
    ]);
    console.log(`seed-discovery done: GENRE=${genres} MOOD=${moods} City=${cities} (launched=${launched})`);
  } finally {
    await prisma.$disconnect();
  }
};

if (require.main === module) {
  main().catch((e: unknown) => {
    console.error(e instanceof Error ? e.message : e);
    process.exit(1);
  });
}
