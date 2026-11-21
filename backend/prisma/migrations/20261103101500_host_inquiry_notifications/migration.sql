-- AlterEnum
ALTER TYPE "NotificationType" ADD VALUE IF NOT EXISTS 'HOST_INQUIRY';

-- AlterTable
ALTER TABLE "HostContact" ADD COLUMN "eventId" TEXT;

-- CreateIndex
CREATE INDEX "HostContact_eventId_createdAt_idx" ON "HostContact"("eventId", "createdAt");

-- AddForeignKey
ALTER TABLE "HostContact" ADD CONSTRAINT "HostContact_eventId_fkey" FOREIGN KEY ("eventId") REFERENCES "Event"("id") ON DELETE SET NULL ON UPDATE CASCADE;
