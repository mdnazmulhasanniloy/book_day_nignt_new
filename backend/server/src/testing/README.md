# Backend test harness (T-003)

Runner: `tsx --test` with `node:test`. No extra framework.

- `npm test` runs every `src/**/*.test.ts` and needs no database. DB tests (`*.db.test.ts`) skip themselves with a message when `TEST_DATABASE_URL` is unset.
- `npm run test:db` runs only `*.db.test.ts`. It aborts before connecting unless `TEST_DATABASE_URL` names a database ending in `_test` or `_rehearsal`.
  Local: `TEST_DATABASE_URL=postgresql://postgres:rehearsal_local_only@localhost:5441/bookdia_rehearsal?schema=public` (run `backend/scripts/rehearse-migrations.sh` first so it is migrated).
- Tests load `server/.env` like the existing ones (REDIS_*, JWT secrets). No test opens a real Redis or Stripe connection.

## Pieces
- `testing/testDb.ts`: URL guard, `getTestPrisma()`, `withRollback(fn)`.
  Isolation choice: each DB test runs in a transaction that is always rolled back (fast; triggers and the ClubBooking EXCLUDE constraint fire normally). Deferred constraints and sequences are not rolled back.
- `testing/fixtures.ts`: `createUser/Club/Event/Tier/Order` (required columns only; extend per task).
- `testing/fakes.ts`: `installFakeRedis()` (overrides methods on the lazy real client; the module export itself cannot be mocked), `FakeQueue` (records `add()`), `signStripePayload()`, `startTestServer(app)`.
- Templates: `testing/examples/` (pure function, route + fake Redis, queue/Stripe fakes, DB-backed).

Keep `*.db.test.ts` names for anything that needs Postgres.
