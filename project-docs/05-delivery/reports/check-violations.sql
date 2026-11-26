-- check-violations.sql  (READ-ONLY, T-002)
-- SELECT only. Each row is: <GATE|INFO>|<label>|<count>. The rehearsal script fails when a GATE row has count > 0.
-- INFO rows are reported but do not fail the run (data that needs a product decision, not a migration blocker).
-- Add one query per later migration task when that migration is written.

-- Order rows that would break the NEW migration 6 CHECK rules
SELECT 'GATE', 'Order.serviceChargeAmount < 0', count(*) FROM "Order" WHERE "serviceChargeAmount" < 0;
SELECT 'GATE', 'Order.commissionAmount outside 0..grossAmount', count(*) FROM "Order"
  WHERE "commissionAmount" < 0 OR "commissionAmount" > "grossAmount";
SELECT 'GATE', 'Order.sellerEarnings <> grossAmount - commissionAmount', count(*) FROM "Order"
  WHERE "sellerEarnings" <> "grossAmount" - "commissionAmount";
SELECT 'GATE', 'Order.buyerTotal <> grossAmount + serviceChargeAmount', count(*) FROM "Order"
  WHERE "buyerTotal" <> "grossAmount" + "serviceChargeAmount";

-- Existing pricing rows that would break the PricingRule CHECKs if the seed values were applied
SELECT 'GATE', 'ServiceCharge.amount <= 0', count(*) FROM "ServiceCharge" WHERE amount <= 0;
SELECT 'GATE', 'ApplicationCharge.chargePercentage outside 0..100', count(*) FROM "ApplicationCharge"
  WHERE "chargePercentage" < 0 OR "chargePercentage" > 100;

-- Informational (needs a product decision, does not block migrations)
SELECT 'INFO', 'PromoCode with neither or both of eventId / clubId', count(*) FROM "PromoCode"
  WHERE ("eventId" IS NULL AND "clubId" IS NULL) OR ("eventId" IS NOT NULL AND "clubId" IS NOT NULL);
SELECT 'INFO', 'duplicate (eventId, groupName, tierName) tier groups', count(*) FROM (
  SELECT 1 FROM "EventTicketTier" GROUP BY "eventId", "groupName", "tierName" HAVING count(*) > 1) d;
