#!/usr/bin/env bash
set -euo pipefail

cd /opt/bookdianight-server

TS=$(date +%Y%m%d%H%M%S)
cp -a .env ".env.bak.${TS}"
cp -a docker-compose.yaml "docker-compose.yaml.bak.${TS}"

PG_PASS=$(openssl rand -base64 24 | tr -d '/+=' | cut -c1-24)
REDIS_PASS=$(openssl rand -base64 24 | tr -d '/+=' | cut -c1-24)

python3 - "$PG_PASS" "$REDIS_PASS" <<'PY'
from pathlib import Path
import re
import sys

pg, rd = sys.argv[1], sys.argv[2]
p = Path("/opt/bookdianight-server/.env")
text = p.read_text(encoding="utf-8")

def sub(key, value, text):
    pattern = rf"^{key}=.*$"
    line = f'{key}="{value}"'
    if re.search(pattern, text, flags=re.M):
        return re.sub(pattern, line, text, flags=re.M)
    return text.rstrip() + "\n" + line + "\n"

text = sub(
    "DATABASE_URL",
    f"postgresql://postgres:{pg}@postgres:5432/bookdianight?schema=public",
    text,
)
text = sub("REDIS_HOST", "redis", text)
text = sub("REDIS_PASSWORD", rd, text)
text = sub("REDIS_PORT", "6379", text)
if not re.search(r"^SERVER_URL=", text, flags=re.M):
    text = text.rstrip() + '\nSERVER_URL="https://api.bookdianight.com"\n'
if not re.search(r"^NODE_ENV=", text, flags=re.M):
    text = text.rstrip() + '\nNODE_ENV="production"\n'
else:
    text = re.sub(r"^NODE_ENV=.*$", 'NODE_ENV="production"', text, flags=re.M)

p.write_text(text, encoding="utf-8")
print("Updated .env database/redis endpoints")
PY

cat > docker-compose.yaml <<EOF
services:
  postgres:
    image: postgis/postgis:16-3.4
    container_name: bookdianight-postgres
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: "${PG_PASS}"
      POSTGRES_DB: bookdianight
    volumes:
      - bookdianight-postgres-volume:/var/lib/postgresql/data
    networks:
      - bookdianight-network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 5s
      retries: 30
    restart: unless-stopped

  redis:
    image: redis:7
    container_name: bookdianight-redis
    command: ["redis-server", "--requirepass", "${REDIS_PASS}"]
    volumes:
      - bookdianight-redis-volume:/data
    networks:
      - bookdianight-network
    healthcheck:
      test: ["CMD", "redis-cli", "-a", "${REDIS_PASS}", "ping"]
      interval: 5s
      timeout: 5s
      retries: 30
    restart: unless-stopped

  db-migrator:
    image: \${DOCKER_USERNAME}/bookdianight-server:\${IMAGE_TAG:-latest}
    container_name: bookdianight-db-migrator
    env_file: .env
    command: ["npx", "prisma", "migrate", "deploy"]
    networks:
      - bookdianight-network
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    restart: "no"

  scheduler:
    image: \${DOCKER_USERNAME}/bookdianight-scheduler:\${IMAGE_TAG:-latest}
    container_name: bookdianight-scheduler
    env_file: .env
    networks:
      - bookdianight-network
    depends_on:
      db-migrator:
        condition: service_completed_successfully
    healthcheck:
      test: ["CMD-SHELL", "pidof node > /dev/null || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 20s
    restart: unless-stopped

  worker:
    image: \${DOCKER_USERNAME}/bookdianight-worker:\${IMAGE_TAG:-latest}
    container_name: bookdianight-worker
    env_file: .env
    networks:
      - bookdianight-network
    depends_on:
      db-migrator:
        condition: service_completed_successfully
    healthcheck:
      test: ["CMD-SHELL", "pidof node > /dev/null || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 20s
    restart: unless-stopped

  server:
    image: \${DOCKER_USERNAME}/bookdianight-server:\${IMAGE_TAG:-latest}
    container_name: bookdianight-server
    env_file: .env
    ports:
      - "5000:5000"
    networks:
      - bookdianight-network
    depends_on:
      db-migrator:
        condition: service_completed_successfully
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://127.0.0.1:5000/health"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 25s
    restart: unless-stopped

networks:
  bookdianight-network:
    driver: bridge

volumes:
  bookdianight-postgres-volume:
  bookdianight-redis-volume:
EOF

export DOCKER_USERNAME=registry.digitalocean.com/bookdianight-registry
export IMAGE_TAG=latest

docker compose down --remove-orphans || true
docker compose pull postgres redis || true
docker compose up -d

echo "Waiting for services..."
for i in $(seq 1 60); do
  if curl -fsS http://127.0.0.1:5000/health >/dev/null 2>&1; then
    echo "LOCAL_HEALTH_OK"
    break
  fi
  sleep 3
done

docker compose ps
docker logs bookdianight-db-migrator 2>&1 | tail -40 || true
curl -sS http://127.0.0.1:5000/health || true
echo
curl -sS -o /tmp/api-health.json -w "PUBLIC_HTTP_%{http_code}\n" https://api.bookdianight.com/health || true
cat /tmp/api-health.json 2>/dev/null || true
echo
