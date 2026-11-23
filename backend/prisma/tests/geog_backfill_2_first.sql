-- after the first migration run: snapshot all geog values (real and synthetic) for the idempotency check
CREATE TEMP TABLE t029_snap AS
  SELECT 'Club' AS t, id, ST_AsText(geog::geometry) AS g FROM "Club"
  UNION ALL SELECT 'Event', id, ST_AsText(geog::geometry) FROM "Event";
SELECT 'GEOGTEST|club valid NULL geog filled|' || (SELECT g FROM t029_snap WHERE id = 't029-c-ok')
  || CASE WHEN (SELECT g FROM t029_snap WHERE id = 't029-c-ok') = 'POINT(12.5 41.9)' THEN '' ELSE '|FAIL' END;
SELECT 'GEOGTEST|event valid NULL geog filled|' || (SELECT g FROM t029_snap WHERE id = 't029-e-ok')
  || CASE WHEN (SELECT g FROM t029_snap WHERE id = 't029-e-ok') = 'POINT(9.19 45.46)' THEN '' ELSE '|FAIL' END;
SELECT 'GEOGTEST|invalid-coordinate rows left NULL (club lat 123, club NaN, event lng 200, event Infinity), expected 4|' || count(*)
  || CASE WHEN count(*) = 4 THEN '' ELSE '|FAIL' END
  FROM t029_snap WHERE id IN ('t029-c-lat','t029-c-nan','t029-e-lng','t029-e-inf') AND g IS NULL;
SELECT 'GEOGTEST|existing geog untouched (club POINT(1 2), event POINT(3 4))|'
  || (SELECT g FROM t029_snap WHERE id = 't029-c-set') || ',' || (SELECT g FROM t029_snap WHERE id = 't029-e-set')
  || CASE WHEN (SELECT g FROM t029_snap WHERE id = 't029-c-set') = 'POINT(1 2)'
           AND (SELECT g FROM t029_snap WHERE id = 't029-e-set') = 'POINT(3 4)' THEN '' ELSE '|FAIL' END;
