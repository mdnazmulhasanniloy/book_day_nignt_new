#!/usr/bin/env bash
set -euo pipefail

BASE="${1:-https://api.bookdianight.com}"
fail=0

check() {
  local name="$1"
  local method="$2"
  local path="$3"
  local expect="$4"
  local extra="${5:-}"
  local code body
  body=$(mktemp)
  code=$(curl -sS -o "$body" -w "%{http_code}" -X "$method" $extra "${BASE}${path}" || echo "000")
  if [[ "$code" == "$expect" ]]; then
    echo "OK  $method $path -> $code ($name)"
  else
    echo "FAIL $method $path -> $code expected $expect ($name)"
    head -c 300 "$body"; echo
    fail=1
  fi
  rm -f "$body"
}

echo "=== container health ==="
cd /opt/bookdianight-server
docker compose ps
echo

echo "=== smoke against $BASE ==="
check "health" GET /health 200
check "openapi" GET /openapi.yaml 200
check "privacy" GET /privacy 200
check "support" GET /support 200
check "marketing" GET /marketing 200
check "website" GET /website 200
check "events list" GET /event 401
check "auth me" GET /auth/me 401
check "admin health-ish" GET /admin 401

# local bind too
echo
echo "=== local bind ==="
curl -sS http://127.0.0.1:5000/health
echo
curl -sS -o /dev/null -w "admin_proxy_%{http_code}\n" -H "Host: admin.bookdianight.com" http://127.0.0.1/ || true
curl -sS -o /dev/null -w "api_proxy_%{http_code}\n" https://api.bookdianight.com/health || true

echo
echo "=== redis ping ==="
REDIS_PASS=$(grep '^REDIS_PASSWORD=' /opt/bookdianight-server/.env | sed 's/^REDIS_PASSWORD=//;s/^"//;s/"$//')
docker exec bookdianight-redis redis-cli -a "$REDIS_PASS" ping 2>/dev/null

echo "=== postgres ==="
docker exec bookdianight-postgres pg_isready -U postgres
docker exec bookdianight-postgres psql -U postgres -d bookdianight -c "SELECT COUNT(*) AS migrations FROM _prisma_migrations;"
docker exec bookdianight-postgres psql -U postgres -d bookdianight -c "\dt" | head -40

echo
if [[ $fail -eq 0 ]]; then
  echo "SMOKE_ALL_PASSED"
else
  echo "SMOKE_HAD_FAILURES"
fi
exit $fail
