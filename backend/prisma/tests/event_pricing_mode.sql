-- T-015: migration 4 backfill check. Read-only. Run by scripts/rehearse-migrations.sh right after
-- the migrations on the restored dump (where no event has been created since the migration).
-- Prints "PRICETEST|<label>|<value>" rows; "|FAIL" in a row fails the rehearsal.
-- Expected derivation: TIERED if the event has a tier; else FREE if eventPrice = 0; else SINGLE.
WITH expected AS (
  SELECT e.id,
         CASE WHEN EXISTS (SELECT 1 FROM "EventTicketTier" t WHERE t."eventId" = e.id) THEN 'TIERED'
              WHEN e."eventPrice" = 0 THEN 'FREE'
              ELSE 'SINGLE' END AS mode
  FROM "Event" e
)
SELECT 'PRICETEST|events with pricingMode TIERED|' || count(*) FROM "Event" WHERE "pricingMode" = 'TIERED'
UNION ALL SELECT 'PRICETEST|events with pricingMode FREE|' || count(*) FROM "Event" WHERE "pricingMode" = 'FREE'
UNION ALL SELECT 'PRICETEST|events with pricingMode SINGLE|' || count(*) FROM "Event" WHERE "pricingMode" = 'SINGLE'
UNION ALL SELECT 'PRICETEST|events with pricingMode MIXED|' || count(*) FROM "Event" WHERE "pricingMode" = 'MIXED'
UNION ALL SELECT 'PRICETEST|events whose pricingMode differs from the derivation|' || count(*)
  || CASE WHEN count(*) = 0 THEN '' ELSE '|FAIL' END
  FROM expected x JOIN "Event" e ON e.id = x.id WHERE e."pricingMode"::text <> x.mode
UNION ALL SELECT 'PRICETEST|events with timezone other than UTC|' || count(*)
  || CASE WHEN count(*) = 0 THEN '' ELSE '|FAIL' END
  FROM "Event" WHERE "timezone" <> 'UTC'
UNION ALL SELECT 'PRICETEST|tiers with tierType other than TICKET|' || count(*)
  || CASE WHEN count(*) = 0 THEN '' ELSE '|FAIL' END
  FROM "EventTicketTier" WHERE "tierType" <> 'TICKET'
UNION ALL SELECT 'PRICETEST|tiers matching the review query (name or group contains pass)|' || count(*)
  FROM "EventTicketTier" t
  WHERE t."tierName" ILIKE '%pass%' OR t."groupName" ILIKE '%pass%';
