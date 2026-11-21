-- Optional preferred slot + party size for club waiting-list entries.
ALTER TABLE "ClubWaitingList" ADD COLUMN IF NOT EXISTS "startAt" TIMESTAMP(3);
ALTER TABLE "ClubWaitingList" ADD COLUMN IF NOT EXISTS "guestCount" INTEGER;

CREATE INDEX IF NOT EXISTS "ClubWaitingList_clubId_startAt_idx"
  ON "ClubWaitingList"("clubId", "startAt");
