-- CreateEnum
CREATE TYPE "PricingMode" AS ENUM ('SINGLE', 'TIERED', 'FREE', 'MIXED');

-- CreateEnum
CREATE TYPE "TierType" AS ENUM ('TICKET', 'PASS');

-- AlterTable (constant defaults: metadata-only, no table rewrite; existing rows read the default)
ALTER TABLE "Event" ADD COLUMN     "pricingMode" "PricingMode" NOT NULL DEFAULT 'SINGLE',
ADD COLUMN     "timezone" TEXT NOT NULL DEFAULT 'UTC';

-- AlterTable
ALTER TABLE "EventTicketTier" ADD COLUMN     "tierType" "TierType" NOT NULL DEFAULT 'TICKET';

-- Backfill pricingMode (data-model.md section 9, migration 4):
-- TIERED where the event has at least one tier; else FREE where eventPrice = 0; else SINGLE (the default).
-- Event.timezone stays 'UTC' for every existing event (no backfill from city or location: open client question).
-- EventTicketTier.tierType stays 'TICKET' for every existing tier (no name heuristic).
UPDATE "Event" e SET "pricingMode" = 'TIERED'
WHERE EXISTS (SELECT 1 FROM "EventTicketTier" t WHERE t."eventId" = e.id);

UPDATE "Event" SET "pricingMode" = 'FREE'
WHERE "pricingMode" = 'SINGLE' AND "eventPrice" = 0;
