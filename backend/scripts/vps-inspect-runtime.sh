#!/usr/bin/env bash
set -euo pipefail

echo "=== server filesystem ==="
docker exec bookdianight-server sh -lc 'pwd; ls -la; ls -la dist | head; ls prisma/migrations 2>/dev/null | wc -l; ls dist/public 2>/dev/null || echo NO_PUBLIC; test -f openapi.yaml && echo HAS_OPENAPI || echo NO_OPENAPI; test -f dist/openapi.yaml && echo HAS_DIST_OPENAPI || true'

echo "=== package ==="
docker exec bookdianight-server sh -lc 'cat package.json | head -20'

echo "=== static routes in bundle? ==="
docker exec bookdianight-server sh -lc 'grep -o "privacy-policy\|/website\|sendPublicPage\|/api/v1" dist/app.js | sort | uniq -c | head'

echo "=== prisma migrations in image ==="
docker exec bookdianight-server sh -lc 'ls prisma/migrations'

echo "=== applied migrations ==="
docker exec bookdianight-postgres psql -U postgres -d bookdianight -c 'SELECT migration_name, finished_at FROM _prisma_migrations ORDER BY finished_at;'

echo "=== table count ==="
docker exec bookdianight-postgres psql -U postgres -d bookdianight -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public';"

echo "=== route probes ==="
for p in /health /api-docs /api/v1/auth/login /api/v1/explore /api/v1/event /api/v1/club /website /privacy /support /marketing /openapi.yaml; do
  code=$(curl -sS -o /tmp/body -w "%{http_code}" "https://api.bookdianight.com$p" || echo 000)
  echo "$code $p"
done

echo "=== nginx api upstream ==="
sudo nginx -T 2>/dev/null | grep -A8 'server_name api.bookdianight.com' | head -40
