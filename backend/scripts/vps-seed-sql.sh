#!/usr/bin/env bash
set -euo pipefail

docker exec -i bookdianight-postgres psql -U postgres -d bookdianight <<'SQL'
INSERT INTO "LegalContent" (id, "legalContentType", content, "createdAt", "updatedAt")
SELECT gen_random_uuid()::text, v.type, v.content, NOW(), NOW()
FROM (VALUES
  ('TERMS_AND_CONDITION', 'Welcome to BookDiaNight. Placeholder Terms & Conditions.'),
  ('PRIVACY_AND_POLICY', 'BookDiaNight respects your privacy. Placeholder Privacy Policy.'),
  ('ABOUT_US', 'Welcome to BookDiaNight. Placeholder About Us.')
) AS v(type, content)
WHERE NOT EXISTS (
  SELECT 1 FROM "LegalContent" lc WHERE lc."legalContentType" = v.type
);

INSERT INTO "ApplicationCharge" (id, "serviceType", "chargePercentage", "createdAt", "updatedAt")
SELECT gen_random_uuid()::text, v.stype, v.pct, NOW(), NOW()
FROM (VALUES
  ('EVENT', 10::numeric),
  ('CLUB', 10::numeric)
) AS v(stype, pct)
WHERE NOT EXISTS (
  SELECT 1 FROM "ApplicationCharge" ac WHERE ac."serviceType" = v.stype
);

INSERT INTO "ServiceCharge" (id, amount, "createdAt", "updatedAt")
SELECT 'GLOBAL', 5.50, NOW(), NOW()
WHERE NOT EXISTS (SELECT 1 FROM "ServiceCharge" WHERE id = 'GLOBAL');

SELECT 'legal' AS kind, COUNT(*) FROM "LegalContent"
UNION ALL
SELECT 'charges', COUNT(*) FROM "ApplicationCharge"
UNION ALL
SELECT 'service', COUNT(*) FROM "ServiceCharge";
SQL

fail=0
for item in \
  "GET /health 200" \
  "GET /api-docs/ 200" \
  "GET /website 200" \
  "GET /privacy 200" \
  "GET /support 200" \
  "GET /marketing 200" \
  "GET /api/v1/explore 200" \
  "GET /api/v1/event 401" \
  "GET /api/v1/club 401" \
  "GET /api/v1/privacy 200" \
  "GET /api/v1/terms 200" \
  "GET /api/v1/about-us 200" \
  "POST /api/v1/auth/login 422"
do
  method=$(echo "$item" | awk '{print $1}')
  path=$(echo "$item" | awk '{print $2}')
  expect=$(echo "$item" | awk '{print $3}')
  code=$(curl -sS -o /tmp/b -w "%{http_code}" -X "$method" -H 'Content-Type: application/json' --data '{}' "https://api.bookdianight.com${path}" || echo 000)
  if [[ "$code" == "$expect" ]]; then
    echo "OK  $method $path -> $code"
  else
    echo "FAIL $method $path -> $code expected $expect"
    head -c 200 /tmp/b; echo
    fail=1
  fi
done

echo
docker compose -f /opt/bookdianight-server/docker-compose.yaml ps
docker logs bookdianight-worker 2>&1 | grep -E "Ready —|Failed to load|Loaded worker from module" | tail -8
docker logs bookdianight-server 2>&1 | grep -E "Server ready|error" | tail -5

if [[ $fail -eq 0 ]]; then echo ALL_CHECKS_PASSED; else echo SOME_CHECKS_FAILED; fi
exit $fail
