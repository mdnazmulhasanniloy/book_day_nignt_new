-- T-031: migration 10 backfill check. Read-only. Run by scripts/rehearse-migrations.sh right after
-- the migrations on the restored dump. Prints "FILTERTEST|<label>|<value>"; "|FAIL" in a row fails
-- the rehearsal. Expected: one FilterOption per distinct lower-cased trimmed non-empty value of
-- Event.musicGenres (GENRE) and Event.moodTags (MOOD); City stays empty.
WITH g AS (
  SELECT btrim(v) AS t FROM "Event" e, unnest(e."musicGenres") v WHERE btrim(v) <> ''
), m AS (
  SELECT btrim(v) AS t FROM "Event" e, unnest(e."moodTags") v WHERE btrim(v) <> ''
)
SELECT 'FILTERTEST|distinct trimmed genre values on events|' || count(DISTINCT t) FROM g
UNION ALL SELECT 'FILTERTEST|distinct trimmed mood values on events|' || count(DISTINCT t) FROM m
UNION ALL SELECT 'FILTERTEST|GENRE rows created|' || count(*) FROM "FilterOption" WHERE kind = 'GENRE'
UNION ALL SELECT 'FILTERTEST|MOOD rows created|' || count(*) FROM "FilterOption" WHERE kind = 'MOOD'
UNION ALL SELECT 'FILTERTEST|GENRE case-variant duplicates collapsed|' || ((SELECT count(DISTINCT t) FROM g) - (SELECT count(*) FROM "FilterOption" WHERE kind = 'GENRE'))
UNION ALL SELECT 'FILTERTEST|MOOD case-variant duplicates collapsed|' || ((SELECT count(DISTINCT t) FROM m) - (SELECT count(*) FROM "FilterOption" WHERE kind = 'MOOD'))
UNION ALL SELECT 'FILTERTEST|GENRE rows differing from distinct lower-cased values|' || count(*) || CASE WHEN count(*) = 0 THEN '' ELSE '|FAIL' END
  FROM ((SELECT lower(t) FROM g EXCEPT SELECT "labelKey" FROM "FilterOption" WHERE kind = 'GENRE')
        UNION ALL (SELECT "labelKey" FROM "FilterOption" WHERE kind = 'GENRE' EXCEPT SELECT lower(t) FROM g)) x
UNION ALL SELECT 'FILTERTEST|MOOD rows differing from distinct lower-cased values|' || count(*) || CASE WHEN count(*) = 0 THEN '' ELSE '|FAIL' END
  FROM ((SELECT lower(t) FROM m EXCEPT SELECT "labelKey" FROM "FilterOption" WHERE kind = 'MOOD')
        UNION ALL (SELECT "labelKey" FROM "FilterOption" WHERE kind = 'MOOD' EXCEPT SELECT lower(t) FROM m)) x
UNION ALL SELECT 'FILTERTEST|rows inactive, untrimmed, empty, or labelKey not lower(label)|' || count(*) || CASE WHEN count(*) = 0 THEN '' ELSE '|FAIL' END
  FROM "FilterOption" WHERE NOT "isActive" OR label <> btrim(label) OR label = '' OR "labelKey" <> lower(label)
UNION ALL SELECT 'FILTERTEST|rows whose sortOrder is not the alphabetical rank of labelKey in its kind|' || count(*) || CASE WHEN count(*) = 0 THEN '' ELSE '|FAIL' END
  FROM (SELECT "sortOrder", row_number() OVER (PARTITION BY kind ORDER BY "labelKey") - 1 AS r FROM "FilterOption") x WHERE "sortOrder" <> r
UNION ALL SELECT 'FILTERTEST|City rows (must be 0)|' || count(*) || CASE WHEN count(*) = 0 THEN '' ELSE '|FAIL' END FROM "City";

-- Near-duplicates that were NOT merged (same letters and digits once punctuation and spaces are
-- ignored). Reported for the product owner to decide; nothing is merged automatically.
SELECT 'FILTERTEST|near-duplicate groups ' || kind || '|' || count(*)
FROM (SELECT kind, regexp_replace("labelKey", '[^a-z0-9]', '', 'g') AS k
      FROM "FilterOption" GROUP BY 1, 2 HAVING count(*) > 1) x GROUP BY kind;
SELECT 'FILTERTEST|near-duplicate ' || kind || '|' || string_agg(label, ' / ' ORDER BY label)
FROM "FilterOption" GROUP BY kind, regexp_replace("labelKey", '[^a-z0-9]', '', 'g') HAVING count(*) > 1;
