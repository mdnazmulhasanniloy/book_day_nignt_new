#!/usr/bin/env bash
set -euo pipefail

echo "=== worker error detail ==="
docker logs bookdianight-worker 2>&1 | tail -80

echo
echo "=== compose ps ==="
cd /opt/bookdianight-server
docker compose ps -a

echo
echo "=== route probes ==="
for p in \
  /health \
  /api-docs/ \
  /website \
  /privacy \
  /support \
  /marketing \
  /api/v1/explore \
  /api/v1/event \
  /api/v1/club \
  /api/v1/auth/login \
  /api/v1/legal/privacy
do
  code=$(curl -sS -o /tmp/b -w "%{http_code}" "https://api.bookdianight.com${p}" || echo 000)
  ctype=$(head -c 80 /tmp/b | tr '\n' ' ')
  echo "$code $p :: $ctype"
done

echo
echo "=== db ==="
docker exec bookdianight-postgres psql -U postgres -d bookdianight -c "SELECT COUNT(*) AS migrations FROM _prisma_migrations;"
docker exec bookdianight-postgres psql -U postgres -d bookdianight -c "SELECT COUNT(*) AS public_tables FROM information_schema.tables WHERE table_schema='public';"
docker exec bookdianight-postgres psql -U postgres -d bookdianight -c "\dt" | head -60

echo
echo "=== missing module inside worker ==="
docker exec bookdianight-worker sh -lc 'node -e "try{require(\"./dist/app/utils/s3.utils.js\")}catch(e){console.error(e.code,e.message)}" 2>&1 | head -40' || true
docker exec bookdianight-worker sh -lc 'ls node_modules/mime-types 2>/dev/null || echo NO_MIME; ls node_modules/@aws-sdk/client-s3 2>/dev/null | head -3 || echo NO_S3'
