-- CreateEnum
CREATE TYPE "EventCategoryType" AS ENUM ('CLUB', 'CONCERT', 'FESTIVAL', 'OPEN_AIR', 'WAREHOUSE');

-- CreateEnum
CREATE TYPE "DiscountType" AS ENUM ('PERCENTAGE', 'FIXED_AMOUNT');

-- AlterTable
ALTER TABLE "Club" ADD COLUMN     "followerCount" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN     "rulesAndVibe" TEXT[] DEFAULT ARRAY[]::TEXT[],
ADD COLUMN     "socialLinks" JSONB,
ADD COLUMN     "website" TEXT;

-- AlterTable
ALTER TABLE "Event" ADD COLUMN     "categoryType" "EventCategoryType" NOT NULL DEFAULT 'CLUB',
ADD COLUMN     "isResaleEnabled" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "moodTags" TEXT[] DEFAULT ARRAY[]::TEXT[],
ADD COLUMN     "musicGenres" TEXT[] DEFAULT ARRAY[]::TEXT[],
ADD COLUMN     "viewCount" INTEGER NOT NULL DEFAULT 0;

-- CreateTable
CREATE TABLE "EventTicketTier" (
    "id" TEXT NOT NULL,
    "eventId" TEXT NOT NULL,
    "tierName" TEXT NOT NULL,
    "groupName" TEXT,
    "description" TEXT,
    "price" DECIMAL(10,2) NOT NULL,
    "capacity" INTEGER NOT NULL,
    "soldCount" INTEGER NOT NULL DEFAULT 0,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "startAt" TIMESTAMP(3),
    "endAt" TIMESTAMP(3),
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "EventTicketTier_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "EventLineup" (
    "id" TEXT NOT NULL,
    "eventId" TEXT NOT NULL,
    "artistName" TEXT NOT NULL,
    "artistAvatar" TEXT,
    "audioPreviewUrl" TEXT,
    "spotifyUrl" TEXT,
    "soundcloudUrl" TEXT,
    "isVerified" BOOLEAN NOT NULL DEFAULT false,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "EventLineup_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ClubFollower" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "clubId" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ClubFollower_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "PromoCode" (
    "id" TEXT NOT NULL,
    "code" TEXT NOT NULL,
    "discountType" "DiscountType" NOT NULL,
    "discountValue" DECIMAL(10,2) NOT NULL,
    "eventId" TEXT,
    "clubId" TEXT,
    "maxUses" INTEGER,
    "usedCount" INTEGER NOT NULL DEFAULT 0,
    "expiresAt" TIMESTAMP(3),
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "PromoCode_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "EventTicketTier_eventId_isActive_sortOrder_idx" ON "EventTicketTier"("eventId", "isActive", "sortOrder");

-- CreateIndex
CREATE INDEX "EventLineup_eventId_sortOrder_idx" ON "EventLineup"("eventId", "sortOrder");

-- CreateIndex
CREATE INDEX "ClubFollower_clubId_idx" ON "ClubFollower"("clubId");

-- CreateIndex
CREATE INDEX "ClubFollower_userId_idx" ON "ClubFollower"("userId");

-- CreateIndex
CREATE UNIQUE INDEX "ClubFollower_userId_clubId_key" ON "ClubFollower"("userId", "clubId");

-- CreateIndex
CREATE UNIQUE INDEX "PromoCode_code_key" ON "PromoCode"("code");

-- CreateIndex
CREATE INDEX "PromoCode_code_isActive_idx" ON "PromoCode"("code", "isActive");

-- CreateIndex
CREATE INDEX "PromoCode_eventId_idx" ON "PromoCode"("eventId");

-- CreateIndex
CREATE INDEX "PromoCode_clubId_idx" ON "PromoCode"("clubId");

-- AddForeignKey
ALTER TABLE "EventTicketTier" ADD CONSTRAINT "EventTicketTier_eventId_fkey" FOREIGN KEY ("eventId") REFERENCES "Event"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "EventLineup" ADD CONSTRAINT "EventLineup_eventId_fkey" FOREIGN KEY ("eventId") REFERENCES "Event"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ClubFollower" ADD CONSTRAINT "ClubFollower_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ClubFollower" ADD CONSTRAINT "ClubFollower_clubId_fkey" FOREIGN KEY ("clubId") REFERENCES "Club"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PromoCode" ADD CONSTRAINT "PromoCode_eventId_fkey" FOREIGN KEY ("eventId") REFERENCES "Event"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PromoCode" ADD CONSTRAINT "PromoCode_clubId_fkey" FOREIGN KEY ("clubId") REFERENCES "Club"("id") ON DELETE CASCADE ON UPDATE CASCADE;
