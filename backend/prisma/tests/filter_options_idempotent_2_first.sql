CREATE TEMP TABLE t031_snap AS SELECT * FROM "FilterOption";
SELECT 'FILTERTEST|synthetic GENRE rows after first run (expect 4)|' || count(*) || CASE WHEN count(*) = 4 THEN '' ELSE '|FAIL' END FROM "FilterOption" WHERE kind = 'GENRE' AND "labelKey" LIKE 't031 %';
SELECT 'FILTERTEST|synthetic MOOD rows after first run (expect 2)|' || count(*) || CASE WHEN count(*) = 2 THEN '' ELSE '|FAIL' END FROM "FilterOption" WHERE kind = 'MOOD' AND "labelKey" LIKE 't031 %';
SELECT 'FILTERTEST|empty labels (expect 0)|' || count(*) || CASE WHEN count(*) = 0 THEN '' ELSE '|FAIL' END FROM "FilterOption" WHERE label = '';
