-- stock-leak.sql  (READ-ONLY report, CR-04 / BUG-B24 / data-model 8.6.3)
-- Contains SELECT statements only. No UPDATE, INSERT, DELETE or DDL. Run it on a restored copy
-- (see the migration test task in implementation-plan.md M1), never edit data from it.
--
-- WHY IT IS AN ESTIMATE: EventPurchase does not store which tier was bought (that is what migration 5
-- adds). The only link is price: purchase.services.ts sets pricePerPerson = tier.price, so a purchase
-- is matched to a tier of the same event with the same price. Where two tiers of one event share a
-- price, the purchases cannot be told apart and the row is flagged AMBIGUOUS.
-- Other reasons soldCount can differ from "sold" (the report cannot separate them):
--   * soldCount is incremented when an order is CREATED and never decremented, so orders that are
--     PAYMENT_FAILED or stuck in PENDING_PAYMENT still count (this is the leak).
--   * PUT /event/{id} recreates tiers with soldCount = 0 (BUG-B24), so soldCount can also be LOWER
--     than paid sales. "diff" is therefore positive for a leak and negative for a reset.
--   * Purchases made before a tier existed (price = eventPrice) can match a tier by coincidence.
--   * PENDING_PAYMENT orders younger than the 15-minute hold are legitimate; see pending_recent.

-- Report 1: per event tier -----------------------------------------------------------------
WITH paid AS (
  SELECT ep."eventId", ep."pricePerPerson", SUM(ep."personCount")::int AS paid_persons
  FROM "EventPurchase" ep
  JOIN "Order" o ON o.id = ep."orderId"
  WHERE o.status = 'PAID'
  GROUP BY ep."eventId", ep."pricePerPerson"
),
pending AS (
  SELECT ep."eventId", ep."pricePerPerson",
         SUM(ep."personCount")::int AS pending_persons,
         SUM(ep."personCount") FILTER (WHERE o."createdAt" > now() - interval '15 minutes')::int AS pending_recent
  FROM "EventPurchase" ep
  JOIN "Order" o ON o.id = ep."orderId"
  WHERE o.status = 'PENDING_PAYMENT'
  GROUP BY ep."eventId", ep."pricePerPerson"
),
same_price AS (
  SELECT "eventId", price, COUNT(*) AS tiers_with_price
  FROM "EventTicketTier"
  GROUP BY "eventId", price
)
SELECT
  e.id                         AS event_id,
  e."eventName"                AS event_name,
  t.id                         AS tier_id,
  t."groupName", t."tierName", t.price, t.capacity, t."isActive",
  t."soldCount"                AS sold_count_now,
  COALESCE(p.paid_persons, 0)  AS paid_persons,
  t."soldCount" - COALESCE(p.paid_persons, 0) AS diff,           -- >0 leak, <0 reset by PUT /event
  COALESCE(pe.pending_persons, 0) AS unpaid_pending_persons,
  COALESCE(pe.pending_recent, 0)  AS pending_last_15min,
  (sp.tiers_with_price > 1)    AS ambiguous_same_price
FROM "EventTicketTier" t
JOIN "Event" e ON e.id = t."eventId"
LEFT JOIN paid p          ON p."eventId" = t."eventId" AND p."pricePerPerson" = t.price
LEFT JOIN pending pe      ON pe."eventId" = t."eventId" AND pe."pricePerPerson" = t.price
JOIN same_price sp        ON sp."eventId" = t."eventId" AND sp.price = t.price
ORDER BY ABS(t."soldCount" - COALESCE(p.paid_persons, 0)) DESC, e.id, t."sortOrder";

-- Report 2: events with exactly ONE active tier: the corrected value ---------------------------
-- With one active tier there is no price ambiguity among active tiers, so the corrected soldCount is
-- the paid persons at that tier's price. Review each row by hand; this is a suggestion, not a fix.
WITH one_tier AS (
  SELECT "eventId" FROM "EventTicketTier" WHERE "isActive" GROUP BY "eventId" HAVING COUNT(*) = 1
)
SELECT
  e.id AS event_id, e."eventName", t.id AS tier_id, t."tierName", t.price, t.capacity,
  t."soldCount" AS sold_count_now,
  COALESCE(SUM(ep."personCount") FILTER (WHERE o.status = 'PAID' AND ep."pricePerPerson" = t.price), 0)::int
      AS corrected_sold_count,
  t."soldCount" - COALESCE(SUM(ep."personCount") FILTER (WHERE o.status = 'PAID' AND ep."pricePerPerson" = t.price), 0)::int
      AS diff,
  (t."soldCount" - COALESCE(SUM(ep."personCount") FILTER (WHERE o.status = 'PAID' AND ep."pricePerPerson" = t.price), 0)::int) > t.capacity
      AS impossible_value_check
FROM one_tier ot
JOIN "Event" e            ON e.id = ot."eventId"
JOIN "EventTicketTier" t  ON t."eventId" = e.id AND t."isActive"
LEFT JOIN "EventPurchase" ep ON ep."eventId" = e.id
LEFT JOIN "Order" o          ON o.id = ep."orderId"
GROUP BY e.id, e."eventName", t.id, t."tierName", t.price, t.capacity, t."soldCount"
ORDER BY diff DESC;

-- Report 3: totals for the client notice ---------------------------------------------------------
-- Total leaked persons (diff > 0) across all single-active-tier events, and how many events are affected.
-- Run Report 2 as a subquery to reuse its numbers:
WITH one_tier AS (
  SELECT "eventId" FROM "EventTicketTier" WHERE "isActive" GROUP BY "eventId" HAVING COUNT(*) = 1
), r AS (
  SELECT e.id AS event_id, t."soldCount" - COALESCE(SUM(ep."personCount") FILTER (WHERE o.status = 'PAID' AND ep."pricePerPerson" = t.price), 0)::int AS diff
  FROM one_tier ot
  JOIN "Event" e ON e.id = ot."eventId"
  JOIN "EventTicketTier" t ON t."eventId" = e.id AND t."isActive"
  LEFT JOIN "EventPurchase" ep ON ep."eventId" = e.id
  LEFT JOIN "Order" o ON o.id = ep."orderId"
  GROUP BY e.id, t.id, t."soldCount", t.price
)
SELECT COUNT(*) FILTER (WHERE diff > 0) AS events_with_leak,
       COALESCE(SUM(diff) FILTER (WHERE diff > 0), 0) AS leaked_persons,
       COUNT(*) FILTER (WHERE diff < 0) AS events_with_lower_count_than_sales
FROM r;
