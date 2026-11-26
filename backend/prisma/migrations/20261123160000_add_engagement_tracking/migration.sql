-- T-039 (migration 11, CR-11): expand-only. Three new tables; nothing existing is changed.
-- No backfill: the history does not exist. The tables stay empty until T-040 and T-041 write to them.

-- CreateTable
CREATE TABLE "EventInterest" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "eventId" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "EventInterest_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "UserRecentEventView" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "eventId" TEXT NOT NULL,
    "lastViewedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "UserRecentEventView_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "EventViewDaily" (
    "eventId" TEXT NOT NULL,
    "day" DATE NOT NULL,
    "views" INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT "EventViewDaily_pkey" PRIMARY KEY ("eventId","day")
);

-- CreateIndex
CREATE INDEX "EventInterest_eventId_createdAt_idx" ON "EventInterest"("eventId", "createdAt");

-- CreateIndex
CREATE UNIQUE INDEX "EventInterest_userId_eventId_key" ON "EventInterest"("userId", "eventId");

-- CreateIndex
CREATE INDEX "UserRecentEventView_userId_lastViewedAt_idx" ON "UserRecentEventView"("userId", "lastViewedAt" DESC);

-- CreateIndex
CREATE UNIQUE INDEX "UserRecentEventView_userId_eventId_key" ON "UserRecentEventView"("userId", "eventId");

-- AddForeignKey
ALTER TABLE "EventInterest" ADD CONSTRAINT "EventInterest_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "EventInterest" ADD CONSTRAINT "EventInterest_eventId_fkey" FOREIGN KEY ("eventId") REFERENCES "Event"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "UserRecentEventView" ADD CONSTRAINT "UserRecentEventView_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "UserRecentEventView" ADD CONSTRAINT "UserRecentEventView_eventId_fkey" FOREIGN KEY ("eventId") REFERENCES "Event"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "EventViewDaily" ADD CONSTRAINT "EventViewDaily_eventId_fkey" FOREIGN KEY ("eventId") REFERENCES "Event"("id") ON DELETE CASCADE ON UPDATE CASCADE;

