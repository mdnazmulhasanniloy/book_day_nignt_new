#!/usr/bin/env bash
set -euo pipefail
cd /opt/bookdianight-server

python3 <<'PY'
from pathlib import Path
p = Path("/opt/bookdianight-server/.env")
lines = p.read_text(encoding="utf-8").splitlines()
fixed = [ln for ln in lines if ln.strip() != '"']
# Ensure critical keys exist / are correct from last known passwords in file
text = "\n".join(fixed) + "\n"
p.write_text(text, encoding="utf-8")
print("cleaned stray quotes")
for i, ln in enumerate(fixed[:20], 1):
    if ln.startswith("DATABASE_URL=") or ln.startswith("REDIS_"):
        print(f"{i}: {ln[:80]}")
PY

# Validate compose can parse env
export DOCKER_USERNAME=registry.digitalocean.com/bookdianight-registry
export IMAGE_TAG=latest

docker compose config >/tmp/compose.validated.yaml
echo "compose config OK"

docker compose down --remove-orphans || true
docker compose up -d

echo "Waiting for health..."
ok=0
for i in $(seq 1 80); do
  if curl -fsS http://127.0.0.1:5000/health >/dev/null 2>&1; then
    echo LOCAL_HEALTH_OK
    ok=1
    break
  fi
  sleep 3
done

echo "=== compose ps ==="
docker compose ps -a
echo "=== migrator ==="
docker logs bookdianight-db-migrator 2>&1 | tail -60 || true
echo "=== server ==="
docker logs bookdianight-server 2>&1 | tail -50 || true
echo "=== worker ==="
docker logs bookdianight-worker 2>&1 | tail -30 || true
echo "=== scheduler ==="
docker logs bookdianight-scheduler 2>&1 | tail -20 || true
echo "=== local ==="
curl -sS http://127.0.0.1:5000/health || true
echo
echo "=== public ==="
curl -sS -w "\nPUBLIC_HTTP_%{http_code}\n" https://api.bookdianight.com/health || true
exit $((1-ok))
