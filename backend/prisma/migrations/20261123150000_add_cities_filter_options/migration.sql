-- T-031 (migration 10, CR-09, CR-10): expand-only. New enum and two new tables; nothing existing
-- is changed. Event.musicGenres and Event.moodTags stay String[] with no foreign key.

-- CreateEnum
CREATE TYPE "FilterOptionKind" AS ENUM ('GENRE', 'MOOD');

-- CreateTable
CREATE TABLE "City" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "countryCode" TEXT,
    "lat" DOUBLE PRECISION NOT NULL,
    "lng" DOUBLE PRECISION NOT NULL,
    "timezone" TEXT NOT NULL DEFAULT 'UTC',
    "isLaunched" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "City_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "FilterOption" (
    "id" TEXT NOT NULL,
    "kind" "FilterOptionKind" NOT NULL,
    "label" TEXT NOT NULL,
    "labelKey" TEXT NOT NULL,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "FilterOption_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "City_isLaunched_idx" ON "City"("isLaunched");

-- CreateIndex
CREATE INDEX "City_name_idx" ON "City"("name");

-- CreateIndex
CREATE UNIQUE INDEX "City_name_countryCode_key" ON "City"("name", "countryCode");

-- CreateIndex
CREATE INDEX "FilterOption_kind_isActive_sortOrder_idx" ON "FilterOption"("kind", "isActive", "sortOrder");

-- CreateIndex
CREATE UNIQUE INDEX "FilterOption_kind_labelKey_key" ON "FilterOption"("kind", "labelKey");

-- Backfill FilterOption (data-model.md section 9, migration 10): one row per distinct value of
-- unnest(Event.musicGenres) (GENRE) and unnest(Event.moodTags) (MOOD), trimmed, de-duplicated
-- case-insensitively on labelKey (lower-case, trimmed). Empty values are skipped. Values are never
-- merged beyond case (no renaming by guesswork); near-duplicates are reported by the rehearsal.
-- label = the most frequent trimmed spelling among the case variants (ties: binary order).
-- sortOrder = alphabetical position of labelKey inside the kind, starting at 0. isActive = true.
-- City is NOT backfilled: event locations are free text, so there is no safe mapping.
-- Idempotent: ON CONFLICT DO NOTHING on (kind, labelKey), so a second run changes nothing.
INSERT INTO "FilterOption" ("id", "kind", "label", "labelKey", "sortOrder", "isActive", "createdAt", "updatedAt")
SELECT gen_random_uuid()::text, 'GENRE'::"FilterOptionKind", d.label, d.key,
       (row_number() OVER (ORDER BY d.key) - 1)::int, true, now(), now()
FROM (
  SELECT DISTINCT ON (key) label, key
  FROM (
    SELECT btrim(v) AS label, lower(btrim(v)) AS key, count(*) AS n
    FROM "Event" e, unnest(e."musicGenres") AS v
    WHERE btrim(v) <> ''
    GROUP BY btrim(v)
  ) s
  ORDER BY key, n DESC, label
) d
ON CONFLICT ("kind", "labelKey") DO NOTHING;

INSERT INTO "FilterOption" ("id", "kind", "label", "labelKey", "sortOrder", "isActive", "createdAt", "updatedAt")
SELECT gen_random_uuid()::text, 'MOOD'::"FilterOptionKind", d.label, d.key,
       (row_number() OVER (ORDER BY d.key) - 1)::int, true, now(), now()
FROM (
  SELECT DISTINCT ON (key) label, key
  FROM (
    SELECT btrim(v) AS label, lower(btrim(v)) AS key, count(*) AS n
    FROM "Event" e, unnest(e."moodTags") AS v
    WHERE btrim(v) <> ''
    GROUP BY btrim(v)
  ) s
  ORDER BY key, n DESC, label
) d
ON CONFLICT ("kind", "labelKey") DO NOTHING;
