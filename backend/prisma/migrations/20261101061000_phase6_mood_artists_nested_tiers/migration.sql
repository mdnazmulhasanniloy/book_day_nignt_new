ALTER TABLE "EventTicketTier" ADD COLUMN "parentId" TEXT;
CREATE INDEX "EventTicketTier_parentId_idx" ON "EventTicketTier"("parentId");
ALTER TABLE "EventTicketTier" ADD CONSTRAINT "EventTicketTier_parentId_fkey" FOREIGN KEY ("parentId") REFERENCES "EventTicketTier"("id") ON DELETE CASCADE ON UPDATE CASCADE;

CREATE TABLE "Artist" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "nameKey" TEXT NOT NULL,
    "avatar" TEXT,
    "audioPreviewUrl" TEXT,
    "spotifyUrl" TEXT,
    "soundcloudUrl" TEXT,
    "isVerified" BOOLEAN NOT NULL DEFAULT false,
    "followerCount" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "Artist_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "Artist_nameKey_key" ON "Artist"("nameKey");
CREATE INDEX "Artist_name_idx" ON "Artist"("name");

CREATE TABLE "ArtistFollower" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "artistId" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "ArtistFollower_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "ArtistFollower_userId_artistId_key" ON "ArtistFollower"("userId", "artistId");
CREATE INDEX "ArtistFollower_artistId_idx" ON "ArtistFollower"("artistId");
CREATE INDEX "ArtistFollower_userId_idx" ON "ArtistFollower"("userId");

ALTER TABLE "ArtistFollower" ADD CONSTRAINT "ArtistFollower_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "ArtistFollower" ADD CONSTRAINT "ArtistFollower_artistId_fkey" FOREIGN KEY ("artistId") REFERENCES "Artist"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "EventLineup" ADD COLUMN "artistId" TEXT;
CREATE INDEX "EventLineup_artistId_idx" ON "EventLineup"("artistId");
ALTER TABLE "EventLineup" ADD CONSTRAINT "EventLineup_artistId_fkey" FOREIGN KEY ("artistId") REFERENCES "Artist"("id") ON DELETE SET NULL ON UPDATE CASCADE;