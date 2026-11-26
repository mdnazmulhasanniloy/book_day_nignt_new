-- T-043 (migration 12, CR-12): expand-only. Two new nullable columns on "Artist"; nothing existing
-- is altered or dropped. No backfill: every existing artist keeps NULL bio and NULL socialLinks.
-- The API field `photo` maps to the existing "avatar" column (no rename).

-- AlterTable
ALTER TABLE "Artist" ADD COLUMN     "bio" TEXT,
ADD COLUMN     "socialLinks" JSONB;
