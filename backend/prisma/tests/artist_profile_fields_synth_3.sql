-- T-043 synthetic proof, part 3 of 3: after the migration SQL ran on the seeded rows, the old
-- columns are byte-identical and both new columns are NULL for the pre-existing artist.
DO $$
DECLARE ok boolean; nul boolean;
BEGIN
  SELECT (md5((SELECT string_agg(concat_ws('~', id, name, "nameKey", avatar, "audioPreviewUrl", "spotifyUrl", "soundcloudUrl", "isVerified", "followerCount", "createdAt", "updatedAt"), '|' ORDER BY id) FROM "Artist")) = a
      AND md5((SELECT string_agg(concat_ws('~', id, "eventId", "artistId", "artistName", "artistAvatar", "audioPreviewUrl", "spotifyUrl", "soundcloudUrl", "isVerified", "sortOrder"), '|' ORDER BY id) FROM "EventLineup")) = l)
    INTO ok FROM t043_before;
  SELECT (bio IS NULL AND "socialLinks" IS NULL) INTO nul FROM "Artist" WHERE id = 't043-a';
  RAISE NOTICE 'ARTISTTEST|synthetic: old Artist and EventLineup data identical after migration SQL|%', ok::text || CASE WHEN ok THEN '' ELSE '|FAIL' END;
  RAISE NOTICE 'ARTISTTEST|synthetic: pre-existing artist has NULL bio and socialLinks|%', nul::text || CASE WHEN nul THEN '' ELSE '|FAIL' END;
END $$;
ROLLBACK;
