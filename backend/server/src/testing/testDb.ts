import { PrismaClient } from '@prisma/client';

/**
 * Throws unless the URL points at a database whose name ends in `_test` or
 * `_rehearsal`. Keeps tests away from dev, staging and production data.
 */
export const assertSafeTestDatabaseUrl = (url: string | undefined): string => {
  if (!url) throw new Error('TEST_DATABASE_URL is not set');
  let dbName = '';
  try {
    dbName = decodeURIComponent(new URL(url).pathname.replace(/^\//, ''));
  } catch {
    throw new Error('TEST_DATABASE_URL is not a valid URL');
  }
  if (!/_(test|rehearsal)$/.test(dbName)) {
    throw new Error(
      `Refusing to run: database "${dbName}" must end in _test or _rehearsal`
    );
  }
  return url;
};

/** Reason string for `{ skip }` when DB tests cannot run, else false. */
export const dbTestSkipReason = (): string | false =>
  process.env.TEST_DATABASE_URL
    ? false
    : 'TEST_DATABASE_URL not set (run `npm run test:db` with a *_test or *_rehearsal database)';

let client: PrismaClient | null = null;

/** Prisma client bound to TEST_DATABASE_URL (validated on first use). */
export const getTestPrisma = (): PrismaClient => {
  if (!client) {
    client = new PrismaClient({
      datasourceUrl: assertSafeTestDatabaseUrl(process.env.TEST_DATABASE_URL),
    });
  }
  return client;
};

export const closeTestPrisma = async (): Promise<void> => {
  if (client) await client.$disconnect();
  client = null;
};

class Rollback extends Error {}

/**
 * Runs `fn` inside a transaction that is always rolled back, so a test leaves
 * no rows behind. Chosen over truncate-per-test because it is fast and works
 * with the ClubBooking EXCLUDE constraint and triggers (they fire normally).
 * Caveat: deferred constraints and sequences are not rolled back.
 */
export const withRollback = async <T>(
  fn: (tx: Parameters<Parameters<PrismaClient['$transaction']>[0]>[0]) => Promise<T>
): Promise<T> => {
  let result!: T;
  try {
    await getTestPrisma().$transaction(
      async (tx) => {
        result = await fn(tx);
        throw new Rollback();
      },
      { timeout: 30000 }
    );
  } catch (e) {
    if (!(e instanceof Rollback)) throw e;
  }
  return result;
};
