#!/usr/bin/env bash
set -euo pipefail
cd /opt/bookdianight-server

echo "=== seed legal + commission ==="
docker exec bookdianight-server node scripts/feed-legal.js
docker exec bookdianight-server node scripts/feed-commission.js

echo "=== final status ==="
docker compose ps -a

echo "=== probes ==="
declare -a checks=(
  "GET /health 200"
  "GET /api-docs/ 200"
  "GET /website 200"
  "GET /privacy 200"
  "GET /support 200"
  "GET /marketing 200"
  "GET /api/v1/explore 200"
  "GET /api/v1/event 401"
  "GET /api/v1/club 401"
  "GET /api/v1/privacy 200"
  "POST /api/v1/auth/login 422"
)

fail=0
for item in "${checks[@]}"; do
  method=$(echo "$item" | awk '{print $1}')
  path=$(echo "$item" | awk '{print $2}')
  expect=$(echo "$item" | awk '{print $3}')
  code=$(curl -sS -o /tmp/b -w "%{http_code}" -X "$method" -H 'Content-Type: application/json' -d '{}' "https://api.bookdianight.com${path}" || echo 000)
  if [[ "$code" == "$expect" ]]; then
    echo "OK  $method $path -> $code"
  else
    echo "FAIL $method $path -> $code expected $expect"
    head -c 160 /tmp/b; echo
    fail=1
  fi
done

echo
echo "=== workers loaded ==="
docker logs bookdianight-worker 2>&1 | grep -E "Ready —|Failed to load|Loaded worker" | tail -10
echo "=== scheduler ==="
docker logs bookdianight-scheduler 2>&1 | grep -E "Ready|Failed" | tail -5
echo "=== db counts ==="
docker exec bookdianight-postgres psql -U postgres -d bookdianight -c "SELECT COUNT(*) AS migrations FROM _prisma_migrations; SELECT COUNT(*) AS legal FROM \"LegalContent\"; SELECT COUNT(*) AS charges FROM \"ApplicationCharge\";"

if [[ $fail -eq 0 ]]; then
  echo "ALL_CHECKS_PASSED"
else
  echo "SOME_CHECKS_FAILED"
fi
exit $fail
