CREATE TYPE "GuestListEntryStatus" AS ENUM ('PENDING', 'CONFIRMED', 'REJECTED');
CREATE TYPE "GuestListFallbackType" AS ENUM ('TICKET_TIER', 'MODULE', 'CLUB_PACKAGE', 'WAITING_LIST');

CREATE TABLE "EventGuestList" (
    "id" TEXT NOT NULL,
    "eventId" TEXT NOT NULL,
    "isEnabled" BOOLEAN NOT NULL DEFAULT false,
    "daysBefore" INTEGER,
    "cutoffAt" TIMESTAMP(3),
    "arrivalTimes" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "maleCap" INTEGER,
    "femaleCap" INTEGER,
    "freeSpots" INTEGER,
    "dressCode" TEXT,
    "idRequired" BOOLEAN NOT NULL DEFAULT false,
    "notes" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "EventGuestList_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "EventGuestListFallback" (
    "id" TEXT NOT NULL,
    "guestListId" TEXT NOT NULL,
    "type" "GuestListFallbackType" NOT NULL,
    "targetId" TEXT NOT NULL,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "EventGuestListFallback_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "EventGuestListEntry" (
    "id" TEXT NOT NULL,
    "guestListId" TEXT NOT NULL,
    "userId" TEXT,
    "name" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "phone" TEXT NOT NULL,
    "menCount" INTEGER NOT NULL DEFAULT 0,
    "womenCount" INTEGER NOT NULL DEFAULT 0,
    "arrivalTime" TEXT NOT NULL,
    "status" "GuestListEntryStatus" NOT NULL DEFAULT 'PENDING',
    "acceptedTerms" BOOLEAN NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "EventGuestListEntry_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "EventGuestList_eventId_key" ON "EventGuestList"("eventId");
CREATE INDEX "EventGuestListFallback_guestListId_sortOrder_idx" ON "EventGuestListFallback"("guestListId", "sortOrder");
CREATE INDEX "EventGuestListEntry_guestListId_status_createdAt_idx" ON "EventGuestListEntry"("guestListId", "status", "createdAt");
CREATE INDEX "EventGuestListEntry_email_idx" ON "EventGuestListEntry"("email");

ALTER TABLE "EventGuestList" ADD CONSTRAINT "EventGuestList_eventId_fkey" FOREIGN KEY ("eventId") REFERENCES "Event"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "EventGuestListFallback" ADD CONSTRAINT "EventGuestListFallback_guestListId_fkey" FOREIGN KEY ("guestListId") REFERENCES "EventGuestList"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "EventGuestListEntry" ADD CONSTRAINT "EventGuestListEntry_guestListId_fkey" FOREIGN KEY ("guestListId") REFERENCES "EventGuestList"("id") ON DELETE CASCADE ON UPDATE CASCADE;