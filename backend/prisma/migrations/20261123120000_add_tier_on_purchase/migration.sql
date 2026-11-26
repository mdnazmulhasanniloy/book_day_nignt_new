-- AlterTable
ALTER TABLE "EventPurchase" ADD COLUMN     "ticketTierId" TEXT,
ADD COLUMN     "ticketTierName" TEXT;

-- CreateIndex
CREATE INDEX "EventPurchase_ticketTierId_idx" ON "EventPurchase"("ticketTierId");

-- CreateIndex
CREATE INDEX "EventTicketTier_eventId_groupName_tierName_idx" ON "EventTicketTier"("eventId", "groupName", "tierName");

-- AddForeignKey
ALTER TABLE "EventPurchase" ADD CONSTRAINT "EventPurchase_ticketTierId_fkey" FOREIGN KEY ("ticketTierId") REFERENCES "EventTicketTier"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- Extend the snapshot-immutability trigger function to the two new columns.
-- Old rows keep NULL (the tier of an old purchase was never stored).
CREATE OR REPLACE FUNCTION "prevent_event_purchase_snapshot_mutation"()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF ROW(
    OLD."orderId", OLD."eventId", OLD."personCount", OLD."eventName", OLD."eventLocation",
    OLD."eventStartAt", OLD."eventEndAt", OLD."pricePerPerson", OLD."transferEligibleAt",
    OLD."ticketTierId", OLD."ticketTierName"
  ) IS DISTINCT FROM ROW(
    NEW."orderId", NEW."eventId", NEW."personCount", NEW."eventName", NEW."eventLocation",
    NEW."eventStartAt", NEW."eventEndAt", NEW."pricePerPerson", NEW."transferEligibleAt",
    NEW."ticketTierId", NEW."ticketTierName"
  ) THEN
    RAISE EXCEPTION 'Event purchase snapshots are immutable';
  END IF;

  RETURN NEW;
END;
$$;
