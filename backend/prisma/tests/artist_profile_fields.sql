-- T-043: migration 12 check. Run by scripts/rehearse-migrations.sh after the migrations, on the
-- restored dump, inside one transaction that is rolled back. Prints "ARTISTTEST|<label>|<value>";
-- "|FAIL" in a row fails the rehearsal. Existing rows must be untouched: the expected count and
-- checksum of the old Artist and EventLineup columns come in as session settings
-- (t043.artist_n, t043.artist_sum, t043.lineup_n, t043.lineup_sum), set by the script from values
-- measured BEFORE migrate deploy.
BEGIN;
DO $$
DECLARE
  n bigint; s text; cnt bigint; got text;
BEGIN
  SELECT count(*) INTO cnt FROM information_schema.columns
    WHERE table_name = 'Artist' AND ((column_name = 'bio' AND data_type = 'text' AND is_nullable = 'YES' AND column_default IS NULL)
       OR (column_name = 'socialLinks' AND data_type = 'jsonb' AND is_nullable = 'YES' AND column_default IS NULL));
  RAISE NOTICE 'ARTISTTEST|new columns present with documented types|%', cnt || CASE WHEN cnt = 2 THEN '' ELSE '|FAIL' END;

  SELECT count(*) INTO n FROM "Artist";
  RAISE NOTICE 'ARTISTTEST|Artist rows|%', n;
  SELECT count(*) INTO cnt FROM "Artist" WHERE bio IS NOT NULL OR "socialLinks" IS NOT NULL;
  RAISE NOTICE 'ARTISTTEST|existing artists with non-NULL bio or socialLinks|%', cnt || CASE WHEN cnt = 0 THEN '' ELSE '|FAIL' END;

  SELECT count(*), COALESCE(md5(string_agg(concat_ws('~', id, name, "nameKey", avatar, "audioPreviewUrl", "spotifyUrl", "soundcloudUrl", "isVerified", "followerCount", "createdAt", "updatedAt"), '|' ORDER BY id)), '') INTO n, s FROM "Artist";
  RAISE NOTICE 'ARTISTTEST|Artist count and checksum unchanged|%', n || '/' || s || CASE WHEN n::text = current_setting('t043.artist_n') AND s = current_setting('t043.artist_sum') THEN '' ELSE '|FAIL' END;

  SELECT count(*), COALESCE(md5(string_agg(concat_ws('~', id, "eventId", "artistId", "artistName", "artistAvatar", "audioPreviewUrl", "spotifyUrl", "soundcloudUrl", "isVerified", "sortOrder"), '|' ORDER BY id)), '') INTO n, s FROM "EventLineup";
  RAISE NOTICE 'ARTISTTEST|EventLineup count and checksum unchanged|%', n || '/' || s || CASE WHEN n::text = current_setting('t043.lineup_n') AND s = current_setting('t043.lineup_sum') THEN '' ELSE '|FAIL' END;

  INSERT INTO "Artist" (id, name, "nameKey", "updatedAt") VALUES ('t043-rehearsal', 't043', 't043-rehearsal', now());
  SELECT (bio IS NULL AND "socialLinks" IS NULL)::text INTO got FROM "Artist" WHERE id = 't043-rehearsal';
  RAISE NOTICE 'ARTISTTEST|new artist defaults both NULL|%', got || CASE WHEN got = 'true' THEN '' ELSE '|FAIL' END;
END $$;
ROLLBACK;
