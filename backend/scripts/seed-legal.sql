INSERT INTO "LegalContent" (id, "legalContentType", content, "createdAt", "updatedAt") VALUES
  (gen_random_uuid()::text, 'TERMS_AND_CONDITION'::"LegalContentType", 'Welcome to BookDiaNight. Placeholder Terms & Conditions.', NOW(), NOW()),
  (gen_random_uuid()::text, 'PRIVACY_AND_POLICY'::"LegalContentType", 'BookDiaNight respects your privacy. Placeholder Privacy Policy.', NOW(), NOW()),
  (gen_random_uuid()::text, 'ABOUT_US'::"LegalContentType", 'Welcome to BookDiaNight. Placeholder About Us.', NOW(), NOW());

INSERT INTO "ApplicationCharge" (id, "serviceType", "chargePercentage", "createdAt", "updatedAt") VALUES
  (gen_random_uuid()::text, 'EVENT'::"Service", 10.00, NOW(), NOW()),
  (gen_random_uuid()::text, 'CLUB'::"Service", 10.00, NOW(), NOW());

SELECT COUNT(*) AS legal FROM "LegalContent";
SELECT COUNT(*) AS charges FROM "ApplicationCharge";
SELECT COUNT(*) AS service FROM "ServiceCharge";
