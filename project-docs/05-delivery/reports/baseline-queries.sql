-- baseline-queries.sql  (READ-ONLY, T-001)
-- SELECT statements only: no INSERT, UPDATE, DELETE or DDL. Counts only, no personal data.
-- Run on a LOCAL restored copy of the dump, never on staging or production.
--   psql "$DATABASE_URL" -f baseline-queries.sql

\echo '== Row counts =='
SELECT 'User' AS table_name, count(*) FROM "User"
UNION ALL SELECT 'Club', count(*) FROM "Club"
UNION ALL SELECT 'Event', count(*) FROM "Event"
UNION ALL SELECT 'EventTicketTier', count(*) FROM "EventTicketTier"
UNION ALL SELECT 'Order', count(*) FROM "Order"
UNION ALL SELECT 'EventPurchase', count(*) FROM "EventPurchase"
UNION ALL SELECT 'EventModulePurchase', count(*) FROM "EventModulePurchase"
UNION ALL SELECT 'Refund', count(*) FROM "Refund";

\echo '== Order count by status =='
SELECT status, count(*) FROM "Order" GROUP BY status ORDER BY status;

\echo '== EventTicketTier soldCount totals =='
SELECT count(*) AS tiers, COALESCE(sum("soldCount"), 0) AS sold_total FROM "EventTicketTier";

\echo '== Event rows with geog IS NULL =='
SELECT count(*) FILTER (WHERE geog IS NULL) AS geog_null, count(*) AS events FROM "Event";

\echo '== Duplicate (eventId, groupName, tierName) tier rows =='
SELECT count(*) AS duplicate_groups FROM (
  SELECT 1 FROM "EventTicketTier"
  GROUP BY "eventId", "groupName", "tierName" HAVING count(*) > 1
) d;

\echo '== Order rows that break the NEW migration 6 rules (expected 0) =='
SELECT
  count(*) FILTER (WHERE "serviceChargeAmount" < 0) AS service_charge_negative,
  count(*) FILTER (WHERE "commissionAmount" < 0 OR "commissionAmount" > "grossAmount") AS commission_out_of_range,
  count(*) FILTER (WHERE "sellerEarnings" <> "grossAmount" - "commissionAmount") AS seller_earnings_mismatch,
  count(*) FILTER (WHERE "buyerTotal" <> "grossAmount" + "serviceChargeAmount") AS buyer_total_mismatch
FROM "Order";

\echo '== PromoCode with neither or both of eventId / clubId (expected 0) =='
SELECT count(*) FROM "PromoCode"
WHERE ("eventId" IS NULL AND "clubId" IS NULL) OR ("eventId" IS NOT NULL AND "clubId" IS NOT NULL);
