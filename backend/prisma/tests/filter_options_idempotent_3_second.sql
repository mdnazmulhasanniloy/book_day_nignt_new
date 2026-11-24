SELECT 'FILTERTEST|rows added or changed by the second run (expect 0)|' || count(*) || CASE WHEN count(*) = 0 THEN '' ELSE '|FAIL' END
FROM ((SELECT * FROM "FilterOption" EXCEPT SELECT * FROM t031_snap) UNION ALL (SELECT * FROM t031_snap EXCEPT SELECT * FROM "FilterOption")) x;
SELECT 'FILTERTEST|FilterOption total rows after second run (first run had ' || (SELECT count(*) FROM t031_snap) || ')|' || count(*) FROM "FilterOption";
ROLLBACK;
