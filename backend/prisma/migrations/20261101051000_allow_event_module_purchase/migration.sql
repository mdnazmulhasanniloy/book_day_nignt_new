CREATE OR REPLACE FUNCTION "enforce_order_purchase_type"()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  order_service_type "Service";
BEGIN
  SELECT "serviceType"
  INTO order_service_type
  FROM "Order"
  WHERE "id" = NEW."orderId";

  IF TG_TABLE_NAME = 'ClubBooking' THEN
    IF order_service_type <> 'CLUB'::"Service"
      OR EXISTS (SELECT 1 FROM "EventPurchase" WHERE "orderId" = NEW."orderId")
      OR EXISTS (SELECT 1 FROM "EventModulePurchase" WHERE "orderId" = NEW."orderId") THEN
      RAISE EXCEPTION 'Order % must have exactly one CLUB purchase', NEW."orderId";
    END IF;
  ELSIF TG_TABLE_NAME = 'EventPurchase' THEN
    IF order_service_type <> 'EVENT'::"Service"
      OR EXISTS (SELECT 1 FROM "ClubBooking" WHERE "orderId" = NEW."orderId")
      OR EXISTS (SELECT 1 FROM "EventModulePurchase" WHERE "orderId" = NEW."orderId") THEN
      RAISE EXCEPTION 'Order % must have exactly one EVENT purchase', NEW."orderId";
    END IF;
  ELSIF TG_TABLE_NAME = 'EventModulePurchase' THEN
    IF order_service_type <> 'EVENT'::"Service"
      OR EXISTS (SELECT 1 FROM "ClubBooking" WHERE "orderId" = NEW."orderId")
      OR EXISTS (SELECT 1 FROM "EventPurchase" WHERE "orderId" = NEW."orderId") THEN
      RAISE EXCEPTION 'Order % must have exactly one EVENT module purchase', NEW."orderId";
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION "validate_order_purchase"()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  target_order_id TEXT;
  order_service_type "Service";
  club_purchase_count INTEGER;
  event_purchase_count INTEGER;
  module_purchase_count INTEGER;
BEGIN
  IF TG_TABLE_NAME = 'Order' THEN
    target_order_id := NEW."id";
  ELSIF TG_OP = 'DELETE' THEN
    target_order_id := OLD."orderId";
  ELSE
    target_order_id := NEW."orderId";
  END IF;

  SELECT "serviceType"
  INTO order_service_type
  FROM "Order"
  WHERE "id" = target_order_id;

  IF order_service_type IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT COUNT(*) INTO club_purchase_count
  FROM "ClubBooking"
  WHERE "orderId" = target_order_id;

  SELECT COUNT(*) INTO event_purchase_count
  FROM "EventPurchase"
  WHERE "orderId" = target_order_id;

  SELECT COUNT(*) INTO module_purchase_count
  FROM "EventModulePurchase"
  WHERE "orderId" = target_order_id;

  IF club_purchase_count + event_purchase_count + module_purchase_count <> 1
    OR (order_service_type = 'CLUB'::"Service" AND club_purchase_count <> 1)
    OR (order_service_type = 'EVENT'::"Service" AND event_purchase_count + module_purchase_count <> 1) THEN
    RAISE EXCEPTION 'Order % must have exactly one matching purchase record', target_order_id;
  END IF;

  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS "EventModulePurchase_enforce_order_purchase_type_trigger" ON "EventModulePurchase";
CREATE TRIGGER "EventModulePurchase_enforce_order_purchase_type_trigger"
BEFORE INSERT OR UPDATE OF "orderId" ON "EventModulePurchase"
FOR EACH ROW
EXECUTE FUNCTION "enforce_order_purchase_type"();

DROP TRIGGER IF EXISTS "EventModulePurchase_validate_order_trigger" ON "EventModulePurchase";
CREATE CONSTRAINT TRIGGER "EventModulePurchase_validate_order_trigger"
AFTER INSERT OR UPDATE OR DELETE ON "EventModulePurchase"
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION "validate_order_purchase"();