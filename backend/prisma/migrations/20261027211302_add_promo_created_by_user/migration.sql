-- AlterTable
ALTER TABLE "PromoCode" ADD COLUMN "createdByUserId" TEXT;

-- CreateIndex
CREATE INDEX "PromoCode_createdByUserId_idx" ON "PromoCode"("createdByUserId");

-- AddForeignKey
ALTER TABLE "PromoCode" ADD CONSTRAINT "PromoCode_createdByUserId_fkey" FOREIGN KEY ("createdByUserId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;
