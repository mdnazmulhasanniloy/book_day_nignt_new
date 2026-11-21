-- CreateEnum
CREATE TYPE "EventModuleStatus" AS ENUM ('AVAILABLE', 'LIMITED', 'SOLD_OUT', 'UNAVAILABLE');

-- CreateEnum
CREATE TYPE "QuoteStatus" AS ENUM ('NEW', 'REPLIED', 'CLOSED');

-- CreateTable
CREATE TABLE "EventModule" (
    "id" TEXT NOT NULL,
    "eventId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "image" TEXT,
    "description" TEXT,
    "maxGuests" INTEGER NOT NULL,
    "startingPrice" DECIMAL(10,2) NOT NULL,
    "minSpend" DECIMAL(10,2) NOT NULL DEFAULT 0,
    "deposit" DECIMAL(10,2) NOT NULL DEFAULT 0,
    "currency" TEXT NOT NULL,
    "quantity" INTEGER NOT NULL,
    "remaining" INTEGER NOT NULL,
    "venueArea" TEXT,
    "includedExtras" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "optionalExtras" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "status" "EventModuleStatus" NOT NULL DEFAULT 'AVAILABLE',
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "EventModule_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "EventModulePurchase" (
    "id" TEXT NOT NULL,
    "orderId" TEXT NOT NULL,
    "eventId" TEXT NOT NULL,
    "moduleId" TEXT NOT NULL,
    "status" "ClubBookingStatus" NOT NULL DEFAULT 'HOLD',
    "quantity" INTEGER NOT NULL,
    "guestCount" INTEGER NOT NULL,
    "dateTime" TIMESTAMP(3),
    "holdExpiresAt" TIMESTAMP(3) NOT NULL,
    "moduleName" TEXT NOT NULL,
    "venueArea" TEXT,
    "unitPrice" DECIMAL(10,2) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "EventModulePurchase_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Quote" (
    "id" TEXT NOT NULL,
    "eventId" TEXT NOT NULL,
    "moduleId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "phone" TEXT NOT NULL,
    "guestCount" INTEGER NOT NULL,
    "message" TEXT NOT NULL,
    "date" TIMESTAMP(3),
    "status" "QuoteStatus" NOT NULL DEFAULT 'NEW',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Quote_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "EventModule_eventId_isActive_sortOrder_idx" ON "EventModule"("eventId", "isActive", "sortOrder");
CREATE INDEX "EventModule_eventId_status_idx" ON "EventModule"("eventId", "status");
CREATE UNIQUE INDEX "EventModulePurchase_orderId_key" ON "EventModulePurchase"("orderId");
CREATE INDEX "EventModulePurchase_moduleId_status_idx" ON "EventModulePurchase"("moduleId", "status");
CREATE INDEX "EventModulePurchase_eventId_createdAt_idx" ON "EventModulePurchase"("eventId", "createdAt");
CREATE INDEX "EventModulePurchase_status_holdExpiresAt_idx" ON "EventModulePurchase"("status", "holdExpiresAt");
CREATE INDEX "Quote_eventId_status_createdAt_idx" ON "Quote"("eventId", "status", "createdAt");
CREATE INDEX "Quote_moduleId_idx" ON "Quote"("moduleId");

ALTER TABLE "EventModule" ADD CONSTRAINT "EventModule_eventId_fkey" FOREIGN KEY ("eventId") REFERENCES "Event"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "EventModulePurchase" ADD CONSTRAINT "EventModulePurchase_orderId_fkey" FOREIGN KEY ("orderId") REFERENCES "Order"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "EventModulePurchase" ADD CONSTRAINT "EventModulePurchase_eventId_fkey" FOREIGN KEY ("eventId") REFERENCES "Event"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "EventModulePurchase" ADD CONSTRAINT "EventModulePurchase_moduleId_fkey" FOREIGN KEY ("moduleId") REFERENCES "EventModule"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "Quote" ADD CONSTRAINT "Quote_eventId_fkey" FOREIGN KEY ("eventId") REFERENCES "Event"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "Quote" ADD CONSTRAINT "Quote_moduleId_fkey" FOREIGN KEY ("moduleId") REFERENCES "EventModule"("id") ON DELETE CASCADE ON UPDATE CASCADE;