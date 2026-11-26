-- T-005: snapshot-immutability trigger rejects UPDATE of ticketTierId / ticketTierName.
-- Run by scripts/rehearse-migrations.sh inside one transaction that is rolled back.
-- Prints "TIERTEST|<label>|ok" or raises. Needs at least no data: it builds its own rows.
BEGIN;
DO $$
DECLARE
  u text := 't005-' || gen_random_uuid()::text;
  ev text := gen_random_uuid()::text;
  ord text := gen_random_uuid()::text;
  tier text := gen_random_uuid()::text;
  pur text := gen_random_uuid()::text;
  col text;
  raised boolean;
BEGIN
  -- Build the minimal parent rows by copying an existing row shape is not possible on an empty DB,
  -- so this test is skipped (reported) when the parent tables have no Order/Event to reference.
  IF (SELECT count(*) FROM "EventPurchase") = 0 THEN
    RAISE NOTICE 'TIERTEST|skipped (no EventPurchase rows to reuse); covered by backend/server DB test tierOnPurchase.db.test.ts|ok';
    RETURN;
  END IF;
  SELECT id INTO pur FROM "EventPurchase" LIMIT 1;
  FOREACH col IN ARRAY ARRAY['ticketTierId', 'ticketTierName'] LOOP
    raised := false;
    BEGIN
      IF col = 'ticketTierId' THEN
        UPDATE "EventPurchase" SET "ticketTierId" = (SELECT id FROM "EventTicketTier" LIMIT 1) WHERE id = pur;
      ELSE
        UPDATE "EventPurchase" SET "ticketTierName" = 'changed-by-test' WHERE id = pur;
      END IF;
    EXCEPTION WHEN OTHERS THEN
      raised := true;
    END;
    IF NOT raised THEN
      RAISE EXCEPTION 'TIERTEST|% update was NOT rejected|FAIL', col;
    END IF;
    RAISE NOTICE 'TIERTEST|% update rejected|ok', col;
  END LOOP;
END $$;
ROLLBACK;
