-- T-029: synthetic proof of the geog backfill. Three files run in ONE psql session by
-- scripts/rehearse-migrations.sh, everything inside a transaction that is rolled back:
--   1_seed.sql -> migration.sql -> 2_first.sql -> migration.sql -> 3_second.sql
-- Prints "GEOGTEST|<label>|<value>"; "|FAIL" in a row fails the rehearsal.
BEGIN;
INSERT INTO "User" (id, name, email, "phoneNumber", "updatedAt")
VALUES ('t029-user', 'T029', 't029@example.test', '+15550000029', now());

INSERT INTO "Club" (id, "userId", name, thumbnail, "dressCode", lat, lng, "updatedAt") VALUES
 ('t029-c-ok',   't029-user', 'ok',   'x', 'x', 41.9, 12.5, now()),
 ('t029-c-lat',  't029-user', 'lat',  'x', 'x', 123,  12.5, now()),
 ('t029-c-nan',  't029-user', 'nan',  'x', 'x', 'NaN'::float8, 12.5, now()),
 ('t029-c-set',  't029-user', 'set',  'x', 'x', 10,   10,   now());
INSERT INTO "Event" (id, "userId", "eventName", thumbnail, lat, lng, "startAt", "endAt", "dressCode", "eventPrice", currency, "updatedAt") VALUES
 ('t029-e-ok',  't029-user', 'ok',  'x', 45.46, 9.19, now(), now(), 'x', 0, 'EUR', now()),
 ('t029-e-lng', 't029-user', 'lng', 'x', 10, 200,      now(), now(), 'x', 0, 'EUR', now()),
 ('t029-e-inf', 't029-user', 'inf', 'x', 10, 'Infinity'::float8, now(), now(), 'x', 0, 'EUR', now()),
 ('t029-e-set', 't029-user', 'set', 'x', 20, 20,      now(), now(), 'x', 0, 'EUR', now());
-- existing geog that disagrees with lat/lng: must survive
UPDATE "Club"  SET geog = ST_SetSRID(ST_MakePoint(1, 2), 4326)::geography WHERE id = 't029-c-set';
UPDATE "Event" SET geog = ST_SetSRID(ST_MakePoint(3, 4), 4326)::geography WHERE id = 't029-e-set';
