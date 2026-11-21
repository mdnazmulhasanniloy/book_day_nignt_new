#!/usr/bin/env bash
set -euo pipefail
cd /opt/bookdianight-server
docker load -i /tmp/bookdianight-worker.tar
set -a
# shellcheck disable=SC1091
source .env.postgres
set +a
docker compose up -d --force-recreate worker
sleep 6
docker compose ps worker
docker logs bookdianight-worker 2>&1 | tail -40
docker exec bookdianight-worker sh -lc 'node -e "require(\"mime-types\"); console.log(\"mime-types OK\")"'
curl -sS https://api.bookdianight.com/health; echo
curl -sS -X POST https://api.bookdianight.com/api/v1/auth/login -H 'Content-Type: application/json' -d '{}' -w "\nlogin_post_%{http_code}\n" | tail -5
curl -sS https://api.bookdianight.com/api/v1/privacy -w "\nprivacy_%{http_code}\n" | tail -3
