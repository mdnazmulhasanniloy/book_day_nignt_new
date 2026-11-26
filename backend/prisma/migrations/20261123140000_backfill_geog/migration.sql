-- T-029 (migration 3, CR-09, BUG-B02, BUG-B25): data only, no schema change.
-- Fill "geog" from lat/lng for rows where it is NULL. Rows that already have a geog are never
-- touched. Rows whose lat/lng are not finite or are out of range (lat -90..90, lng -180..180)
-- stay NULL (reported by the rehearsal, fixed by hand). In PostgreSQL NaN sorts above every
-- number, so BETWEEN also excludes NaN and Infinity. Safe to run twice.

UPDATE "Club"
SET "geog" = ST_SetSRID(ST_MakePoint("lng", "lat"), 4326)::geography
WHERE "geog" IS NULL
  AND "lat" BETWEEN -90 AND 90
  AND "lng" BETWEEN -180 AND 180;

UPDATE "Event"
SET "geog" = ST_SetSRID(ST_MakePoint("lng", "lat"), 4326)::geography
WHERE "geog" IS NULL
  AND "lat" BETWEEN -90 AND 90
  AND "lng" BETWEEN -180 AND 180;
