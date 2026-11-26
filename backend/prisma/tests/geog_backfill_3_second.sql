-- after the second migration run: nothing may differ from the snapshot; then report real leftovers and roll back
SELECT 'GEOGTEST|rows changed by the second run (idempotency)|' || count(*)
  || CASE WHEN count(*) = 0 THEN '' ELSE '|FAIL' END
  FROM (SELECT 'Club' AS t, id, ST_AsText(geog::geometry) AS g FROM "Club"
        UNION ALL SELECT 'Event', id, ST_AsText(geog::geometry) FROM "Event") now_
  FULL JOIN t029_snap s USING (t, id) WHERE now_.g IS DISTINCT FROM s.g OR now_.id IS NULL OR s.id IS NULL;
-- real rows (synthetic ones excluded): valid coordinates with NULL geog must be 0 (a Club or Event
-- created after the migration by unchanged code would show up here; none exist in the dump)
SELECT 'GEOGTEST|real Club rows with NULL geog and valid lat/lng|' || count(*)
  || CASE WHEN count(*) = 0 THEN '' ELSE '|FAIL' END
  FROM "Club" WHERE geog IS NULL AND lat BETWEEN -90 AND 90 AND lng BETWEEN -180 AND 180 AND id NOT LIKE 't029-%';
SELECT 'GEOGTEST|real Event rows with NULL geog and valid lat/lng|' || count(*)
  || CASE WHEN count(*) = 0 THEN '' ELSE '|FAIL' END
  FROM "Event" WHERE geog IS NULL AND lat BETWEEN -90 AND 90 AND lng BETWEEN -180 AND 180 AND id NOT LIKE 't029-%';
SELECT 'GEOGTEST|real Club rows with NULL geog and invalid coordinates (reported, not changed)|' || count(*)
  FROM "Club" WHERE geog IS NULL AND NOT (lat BETWEEN -90 AND 90 AND lng BETWEEN -180 AND 180) AND id NOT LIKE 't029-%';
SELECT 'GEOGTEST|real Event rows with NULL geog and invalid coordinates (reported, not changed)|' || count(*)
  FROM "Event" WHERE geog IS NULL AND NOT (lat BETWEEN -90 AND 90 AND lng BETWEEN -180 AND 180) AND id NOT LIKE 't029-%';
ROLLBACK;
