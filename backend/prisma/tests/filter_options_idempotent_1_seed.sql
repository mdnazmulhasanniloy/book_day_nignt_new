-- T-031: synthetic idempotency proof of the FilterOption backfill. Three files run in ONE psql
-- session by scripts/rehearse-migrations.sh, all inside a transaction that is rolled back:
--   1_seed.sql -> backfill -> 2_first.sql -> backfill -> 3_second.sql
-- Prints "FILTERTEST|<label>|<value>"; "|FAIL" in a row fails the rehearsal.
BEGIN;
INSERT INTO "User" (id, name, email, "phoneNumber", "updatedAt")
VALUES ('t031-user', 'T031', 't031@example.test', '+15550000031', now());
INSERT INTO "Event" (id, "userId", "eventName", thumbnail, lat, lng, "startAt", "endAt", "dressCode", "eventPrice", currency, "musicGenres", "moodTags", "updatedAt") VALUES
 ('t031-e1', 't031-user', 'a', 'x', 1, 1, now(), now(), 'x', 0, 'EUR', ARRAY['t031 Techno', '  t031 techno ', 't031 House', '', '   '], ARRAY['t031 Chill', 'T031 CHILL'], now()),
 ('t031-e2', 't031-user', 'b', 'x', 1, 1, now(), now(), 'x', 0, 'EUR', ARRAY['t031 Techno', 't031 hip-hop', 't031 hiphop'], ARRAY['t031 Wild'], now());
