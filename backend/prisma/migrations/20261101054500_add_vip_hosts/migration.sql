CREATE TABLE "VipHost" (
    "id" TEXT NOT NULL,
    "ownerUserId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "role" TEXT NOT NULL,
    "isVerified" BOOLEAN NOT NULL DEFAULT false,
    "photo" TEXT,
    "whatsapp" TEXT,
    "phone" TEXT,
    "email" TEXT,
    "bio" TEXT,
    "officialPricesNote" TEXT,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "VipHost_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "EventVipHost" (
    "id" TEXT NOT NULL,
    "eventId" TEXT NOT NULL,
    "hostId" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "EventVipHost_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "ClubVipHost" (
    "id" TEXT NOT NULL,
    "clubId" TEXT NOT NULL,
    "hostId" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "ClubVipHost_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "HostContact" (
    "id" TEXT NOT NULL,
    "hostId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "phone" TEXT NOT NULL,
    "message" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "HostContact_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "VipHost_ownerUserId_isActive_idx" ON "VipHost"("ownerUserId", "isActive");
CREATE UNIQUE INDEX "EventVipHost_eventId_hostId_key" ON "EventVipHost"("eventId", "hostId");
CREATE INDEX "EventVipHost_hostId_idx" ON "EventVipHost"("hostId");
CREATE UNIQUE INDEX "ClubVipHost_clubId_hostId_key" ON "ClubVipHost"("clubId", "hostId");
CREATE INDEX "ClubVipHost_hostId_idx" ON "ClubVipHost"("hostId");
CREATE INDEX "HostContact_hostId_createdAt_idx" ON "HostContact"("hostId", "createdAt");

ALTER TABLE "VipHost" ADD CONSTRAINT "VipHost_ownerUserId_fkey" FOREIGN KEY ("ownerUserId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "EventVipHost" ADD CONSTRAINT "EventVipHost_eventId_fkey" FOREIGN KEY ("eventId") REFERENCES "Event"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "EventVipHost" ADD CONSTRAINT "EventVipHost_hostId_fkey" FOREIGN KEY ("hostId") REFERENCES "VipHost"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "ClubVipHost" ADD CONSTRAINT "ClubVipHost_clubId_fkey" FOREIGN KEY ("clubId") REFERENCES "Club"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "ClubVipHost" ADD CONSTRAINT "ClubVipHost_hostId_fkey" FOREIGN KEY ("hostId") REFERENCES "VipHost"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "HostContact" ADD CONSTRAINT "HostContact_hostId_fkey" FOREIGN KEY ("hostId") REFERENCES "VipHost"("id") ON DELETE CASCADE ON UPDATE CASCADE;