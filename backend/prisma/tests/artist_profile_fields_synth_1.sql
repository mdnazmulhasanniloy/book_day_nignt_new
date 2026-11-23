-- T-043 synthetic proof, part 1 of 3 (run with the migration SQL between parts, one transaction,
-- rolled back by part 3). Puts the database in the "before migration 12" shape (drops the two new
-- columns), seeds one artist and one lineup row, and stores a checksum of their old columns.
BEGIN;
ALTER TABLE "Artist" DROP COLUMN "bio", DROP COLUMN "socialLinks";
INSERT INTO "User" (id, name, email, "phoneNumber", "updatedAt") VALUES ('t043-u', 't043', 't043-u@example.test', '+0', now());
INSERT INTO "Event" (id, "userId", "eventName", thumbnail, lat, lng, "startAt", "endAt", "dressCode", "eventPrice", currency, "updatedAt") VALUES ('t043-e', 't043-u', 't043', 'x', 1, 1, now(), now(), 'x', 0, 'EUR', now());
INSERT INTO "Artist" (id, name, "nameKey", avatar, "spotifyUrl", "followerCount", "updatedAt") VALUES ('t043-a', 'Seed', 't043-seed', 'a.png', 'https://s.test', 3, '2026-01-01');
INSERT INTO "EventLineup" (id, "eventId", "artistId", "artistName", "sortOrder", "updatedAt") VALUES ('t043-l', 't043-e', 't043-a', 'Seed', 1, now());
CREATE TEMP TABLE t043_before AS
  SELECT md5((SELECT string_agg(concat_ws('~', id, name, "nameKey", avatar, "audioPreviewUrl", "spotifyUrl", "soundcloudUrl", "isVerified", "followerCount", "createdAt", "updatedAt"), '|' ORDER BY id) FROM "Artist")) AS a,
         md5((SELECT string_agg(concat_ws('~', id, "eventId", "artistId", "artistName", "artistAvatar", "audioPreviewUrl", "spotifyUrl", "soundcloudUrl", "isVerified", "sortOrder"), '|' ORDER BY id) FROM "EventLineup")) AS l;
