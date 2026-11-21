-- CreateEnum
CREATE TYPE "WaitingListStatus" AS ENUM ('PENDING', 'NOTIFIED', 'CANCELLED');

-- CreateEnum
CREATE TYPE "ClubHostStatus" AS ENUM ('NONE', 'PENDING', 'APPROVED', 'REJECTED');

-- AlterEnum
ALTER TYPE "NotificationType" ADD VALUE 'CLUB_SEAT_AVAILABLE';

-- AlterTable
ALTER TABLE "Event" ADD COLUMN     "clubHostStatus" "ClubHostStatus" NOT NULL DEFAULT 'NONE',
ADD COLUMN     "clubId" TEXT;

-- CreateTable
CREATE TABLE "ClubWaitingList" (
    "id" TEXT NOT NULL,
    "clubId" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "status" "WaitingListStatus" NOT NULL DEFAULT 'PENDING',
    "notifiedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ClubWaitingList_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "ClubWaitingList_clubId_status_idx" ON "ClubWaitingList"("clubId", "status");

-- CreateIndex
CREATE INDEX "ClubWaitingList_userId_idx" ON "ClubWaitingList"("userId");

-- CreateIndex
CREATE UNIQUE INDEX "ClubWaitingList_userId_clubId_status_key" ON "ClubWaitingList"("userId", "clubId", "status");

-- CreateIndex
CREATE INDEX "Event_clubId_clubHostStatus_idx" ON "Event"("clubId", "clubHostStatus");

-- AddForeignKey
ALTER TABLE "Event" ADD CONSTRAINT "Event_clubId_fkey" FOREIGN KEY ("clubId") REFERENCES "Club"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ClubWaitingList" ADD CONSTRAINT "ClubWaitingList_clubId_fkey" FOREIGN KEY ("clubId") REFERENCES "Club"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ClubWaitingList" ADD CONSTRAINT "ClubWaitingList_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
