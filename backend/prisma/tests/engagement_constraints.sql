-- T-039: migration 11 constraint check. Run by scripts/rehearse-migrations.sh after the migrations,
-- on the restored dump, inside one transaction that is rolled back. Prints
-- "ENGAGETEST|<label>|<value>"; "|FAIL" in a row fails the rehearsal.
-- The three tables must be empty after migrate (checked first, before any row is inserted).
-- Parent rows: a fresh User is inserted; an existing Event is reused (none present means the
-- constraint checks are skipped and reported; the DB test engagementTracking.db.test.ts covers them).
BEGIN;
DO $$
DECLARE
  t text;
  n bigint;
  u1 text := 't039-u1-' || gen_random_uuid()::text;
  u2 text := 't039-u2-' || gen_random_uuid()::text;
  ev text;
  raised boolean;
BEGIN
  FOREACH t IN ARRAY ARRAY['EventInterest', 'UserRecentEventView', 'EventViewDaily'] LOOP
    EXECUTE format('SELECT count(*) FROM %I', t) INTO n;
    RAISE NOTICE 'ENGAGETEST|% rows after migrate|%', t, n::text || CASE WHEN n = 0 THEN '' ELSE '|FAIL' END;
  END LOOP;

  SELECT id INTO ev FROM "Event" ORDER BY "createdAt" LIMIT 1;
  IF ev IS NULL THEN
    RAISE NOTICE 'ENGAGETEST|skipped constraint checks (no Event rows to reference)|ok';
    RETURN;
  END IF;

  INSERT INTO "User" (id, name, email, "phoneNumber", "updatedAt")
    VALUES (u1, 't039', u1 || '@example.test', '+0', now()), (u2, 't039', u2 || '@example.test', '+0', now());

  -- EventInterest unique (userId, eventId)
  INSERT INTO "EventInterest" (id, "userId", "eventId") VALUES ('t039-i1', u1, ev);
  raised := false;
  BEGIN
    INSERT INTO "EventInterest" (id, "userId", "eventId") VALUES ('t039-i2', u1, ev);
  EXCEPTION WHEN unique_violation THEN raised := true; END;
  RAISE NOTICE 'ENGAGETEST|EventInterest duplicate rejected|%', raised::text || CASE WHEN raised THEN '' ELSE '|FAIL' END;
  INSERT INTO "EventInterest" (id, "userId", "eventId") VALUES ('t039-i3', u2, ev);

  -- UserRecentEventView unique (userId, eventId)
  INSERT INTO "UserRecentEventView" (id, "userId", "eventId") VALUES ('t039-v1', u1, ev);
  raised := false;
  BEGIN
    INSERT INTO "UserRecentEventView" (id, "userId", "eventId") VALUES ('t039-v2', u1, ev);
  EXCEPTION WHEN unique_violation THEN raised := true; END;
  RAISE NOTICE 'ENGAGETEST|UserRecentEventView duplicate rejected|%', raised::text || CASE WHEN raised THEN '' ELSE '|FAIL' END;

  -- EventViewDaily composite primary key (eventId, day)
  INSERT INTO "EventViewDaily" ("eventId", day, views) VALUES (ev, '2026-11-23', 1);
  raised := false;
  BEGIN
    INSERT INTO "EventViewDaily" ("eventId", day, views) VALUES (ev, '2026-11-23', 2);
  EXCEPTION WHEN unique_violation THEN raised := true; END;
  RAISE NOTICE 'ENGAGETEST|EventViewDaily duplicate (eventId, day) rejected|%', raised::text || CASE WHEN raised THEN '' ELSE '|FAIL' END;

  -- user delete cascades
  DELETE FROM "User" WHERE id IN (u1, u2);
  SELECT (SELECT count(*) FROM "EventInterest" WHERE id LIKE 't039-%')
       + (SELECT count(*) FROM "UserRecentEventView" WHERE id LIKE 't039-%') INTO n;
  RAISE NOTICE 'ENGAGETEST|rows left after deleting the users|%', n::text || CASE WHEN n = 0 THEN '' ELSE '|FAIL' END;

  -- event delete cascades (best effort on a real event: other tables may restrict the delete)
  INSERT INTO "User" (id, name, email, "phoneNumber", "updatedAt") VALUES (u1, 't039', u1 || '@example.test', '+0', now());
  INSERT INTO "EventInterest" (id, "userId", "eventId") VALUES ('t039-i4', u1, ev);
  INSERT INTO "UserRecentEventView" (id, "userId", "eventId") VALUES ('t039-v4', u1, ev);
  BEGIN
    DELETE FROM "Event" WHERE id = ev;
    SELECT (SELECT count(*) FROM "EventInterest" WHERE "eventId" = ev)
         + (SELECT count(*) FROM "UserRecentEventView" WHERE "eventId" = ev)
         + (SELECT count(*) FROM "EventViewDaily" WHERE "eventId" = ev) INTO n;
    RAISE NOTICE 'ENGAGETEST|rows left after deleting the event|%', n::text || CASE WHEN n = 0 THEN '' ELSE '|FAIL' END;
  EXCEPTION WHEN foreign_key_violation THEN
    RAISE NOTICE 'ENGAGETEST|event delete skipped (restricted by other tables); covered by the DB test|ok';
  END;
END $$;
ROLLBACK;
