#!/usr/bin/env bash
set -euo pipefail
cd /opt/bookdianight-server

echo "=== loading images ==="
docker load -i /tmp/bookdianight-images.tar

echo "=== updating .env for local redis/postgres ==="
python3 <<'PY'
from pathlib import Path
import re
p = Path("/opt/bookdianight-server/.env")
text = p.read_text(encoding="utf-8")
# drop stray quote-only lines
lines = [ln for ln in text.splitlines() if ln.strip() != '"']
text = "\n".join(lines) + "\n"

def upsert(key, value, quoted=True):
    global text
    line = f'{key}="{value}"' if quoted else f"{key}={value}"
    if re.search(rf"^{key}=", text, flags=re.M):
        text = re.sub(rf"^{key}=.*$", line, text, flags=re.M)
    else:
        text = text.rstrip() + "\n" + line + "\n"

# Keep existing DATABASE_URL/REDIS if already local; force known-good values from compose
# Extract redis password currently in .env
m = re.search(r'^REDIS_PASSWORD="?([^"\n]+)"?', text, flags=re.M)
redis_pass = m.group(1) if m else "changeme"
m2 = re.search(r'^DATABASE_URL="postgresql://postgres:([^@]+)@', text, flags=re.M)
pg_pass = m2.group(1) if m2 else redis_pass

upsert("DATABASE_URL", f"postgresql://postgres:{pg_pass}@postgres:5432/bookdianight?schema=public")
upsert("REDIS_HOST", "redis")
upsert("REDIS_PASSWORD", redis_pass)
upsert("REDIS_PORT", "6379")
upsert("REDIS_TLS", "false")
upsert("SERVER_URL", "https://api.bookdianight.com")
upsert("NODE_ENV", "production")
# compose interpolation for postgres service
upsert("POSTGRES_PASSWORD", pg_pass)

Path("/opt/bookdianight-server/.env").write_text(text, encoding="utf-8")
Path("/opt/bookdianight-server/.env.postgres").write_text(
    f"POSTGRES_PASSWORD={pg_pass}\nREDIS_PASSWORD={redis_pass}\n", encoding="utf-8"
)
print(f"env ready pg_pass_len={len(pg_pass)} redis_pass_len={len(redis_pass)}")
PY

cp /tmp/vps-compose.localdb.yaml /opt/bookdianight-server/docker-compose.yaml

# Export passwords for compose variable substitution
set -a
# shellcheck disable=SC1091
source /opt/bookdianight-server/.env.postgres
set +a

echo "=== recreate stack with fresh DB volume (old migration history incompatible) ==="
docker compose down --remove-orphans || true
# Remove only app postgres volume so new migrations apply cleanly
vol=$(docker volume ls -q | grep -E 'bookdianight.*postgres' || true)
if [[ -n "$vol" ]]; then
  echo "Removing volume(s): $vol"
  docker volume rm $vol || true
fi

docker compose up -d

echo "Waiting for health..."
ok=0
for i in $(seq 1 90); do
  if curl -fsS http://127.0.0.1:5000/health >/dev/null 2>&1; then
    echo LOCAL_HEALTH_OK
    ok=1
    break
  fi
  sleep 3
done

docker compose ps -a
echo "=== migrator ==="
docker logs bookdianight-db-migrator 2>&1 | tail -80 || true
echo "=== server ==="
docker logs bookdianight-server 2>&1 | tail -50 || true
echo "=== worker ==="
docker logs bookdianight-worker 2>&1 | tail -30 || true
echo "=== scheduler ==="
docker logs bookdianight-scheduler 2>&1 | tail -20 || true

echo "=== probes ==="
for p in /health /api-docs /website /privacy /support /marketing /api/v1/explore /api/v1/event /api/v1/club /api/v1/auth/login; do
  code=$(curl -sS -o /tmp/body -w "%{http_code}" "https://api.bookdianight.com$p" || echo 000)
  echo "$code $p"
done
curl -sS http://127.0.0.1:5000/health; echo
curl -sS -w "\nPUBLIC_%{http_code}\n" https://api.bookdianight.com/health || true

docker exec bookdianight-postgres psql -U postgres -d bookdianight -c "SELECT COUNT(*) AS migrations FROM _prisma_migrations;"
docker exec bookdianight-postgres psql -U postgres -d bookdianight -c "SELECT COUNT(*) AS public_tables FROM information_schema.tables WHERE table_schema='public';"

exit $((1-ok))
