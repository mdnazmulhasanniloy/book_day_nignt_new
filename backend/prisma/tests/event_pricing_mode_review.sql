-- T-015: migration 4 review query (data-model.md section 9). Read-only.
-- Lists tiers whose name or group contains "pass" so the product owner can decide which become PASS.
SELECT t.id, t."eventId", e."eventName", t."groupName", t."tierName", t.price, t."tierType", t."soldCount"
FROM "EventTicketTier" t
JOIN "Event" e ON e.id = t."eventId"
WHERE t."tierName" ILIKE '%pass%' OR t."groupName" ILIKE '%pass%'
ORDER BY e."eventName", t."groupName", t."sortOrder";
