#!/usr/bin/env bash
set -euo pipefail
cd /opt/bookdianight-server

patch_image() {
  local src="$1"
  local dst="$2"
  local name="$3"
  echo "Patching $src -> $dst"
  docker rm -f "$name" >/dev/null 2>&1 || true
  docker create --name "$name" "$src" >/dev/null
  # Find compiled redis config files
  mapfile -t files < <(docker export "$name" | tar -t | grep -E 'redis\.configs\.js$' || true)
  if [[ ${#files[@]} -eq 0 ]]; then
    echo "ERROR: redis.configs.js not found in $src"
    docker rm -f "$name" >/dev/null
    exit 1
  fi
  mkdir -p "/tmp/${name}-patch"
  for f in "${files[@]}"; do
    docker cp "$name:/$f" "/tmp/${name}-patch/$(basename "$f").bak"
    docker cp "$name:/$f" "/tmp/${name}-patch/$(basename "$f")"
    # Force tls: undefined regardless of NODE_ENV
    python3 - <<PY
from pathlib import Path
p = Path("/tmp/${name}-patch/$(basename "$f")")
text = p.read_text(encoding="utf-8")
old = text
# common compiled forms
replacements = [
    ("tls: env.NODE_ENV === 'production' ? {} : undefined", "tls: undefined"),
    ('tls: env.NODE_ENV === "production" ? {} : undefined', "tls: undefined"),
    ("tls: env.NODE_ENV === 'production' ? {} : void 0", "tls: undefined"),
    ("(0, env_1.env).NODE_ENV === 'production' ? {} : undefined", "undefined"),
]
changed = False
for a,b in replacements:
    if a in text:
        text = text.replace(a, b)
        changed = True
# broader fallback: any tls: <ternary with production>
import re
text2 = re.sub(
    r"tls:\s*[^,\n]+NODE_ENV[^,\n]+undefined",
    "tls: undefined",
    text,
)
if text2 != text:
    text = text2
    changed = True
if not changed and "tls:" not in text:
    raise SystemExit(f"no tls setting found in {p}")
p.write_text(text, encoding="utf-8")
print(f"patched {p.name} changed={changed or text!=old}")
# show surrounding tls lines
for i, line in enumerate(text.splitlines(), 1):
    if "tls" in line.lower() or "REDIS" in line:
        print(f"  {i}: {line.strip()[:120]}")
PY
    docker cp "/tmp/${name}-patch/$(basename "$f")" "$name:/$f"
  done
  docker commit "$name" "$dst" >/dev/null
  docker rm -f "$name" >/dev/null
  echo "Created $dst"
}

REG=registry.digitalocean.com/bookdianight-registry
patch_image "$REG/bookdianight-server:latest" "bookdianight-server:local-notls" patch-server
patch_image "$REG/bookdianight-worker:latest" "bookdianight-worker:local-notls" patch-worker
patch_image "$REG/bookdianight-scheduler:latest" "bookdianight-scheduler:local-notls" patch-scheduler

# Point compose at local patched images
python3 <<'PY'
from pathlib import Path
p = Path("/opt/bookdianight-server/docker-compose.yaml")
text = p.read_text(encoding="utf-8")
# Replace image lines for app services only
text = text.replace(
    "${DOCKER_USERNAME}/bookdianight-server:${IMAGE_TAG:-latest}",
    "bookdianight-server:local-notls",
)
text = text.replace(
    "${DOCKER_USERNAME}/bookdianight-worker:${IMAGE_TAG:-latest}",
    "bookdianight-worker:local-notls",
)
text = text.replace(
    "${DOCKER_USERNAME}/bookdianight-scheduler:${IMAGE_TAG:-latest}",
    "bookdianight-scheduler:local-notls",
)
p.write_text(text, encoding="utf-8")
print("compose updated to local-notls images")
PY

# Also set REDIS_TLS hint unused; ensure NODE_ENV stays production for cookies
grep -q '^REDIS_HOST=' .env

export DOCKER_USERNAME=registry.digitalocean.com/bookdianight-registry
export IMAGE_TAG=latest
docker compose up -d --force-recreate db-migrator server worker scheduler

echo "Waiting for health..."
ok=0
for i in $(seq 1 60); do
  if curl -fsS http://127.0.0.1:5000/health >/dev/null 2>&1; then
    echo LOCAL_HEALTH_OK
    ok=1
    break
  fi
  sleep 3
done

docker compose ps -a
echo "=== server ==="
docker logs bookdianight-server 2>&1 | tail -40
echo "=== worker ==="
docker logs bookdianight-worker 2>&1 | tail -25
echo "=== scheduler ==="
docker logs bookdianight-scheduler 2>&1 | tail -20
echo "=== local health ==="
curl -sS http://127.0.0.1:5000/health || true
echo
echo "=== public health ==="
curl -sS -w "\nPUBLIC_HTTP_%{http_code}\n" https://api.bookdianight.com/health || true
echo "=== public docs/root ==="
curl -sS -o /dev/null -w "ROOT_%{http_code}\n" https://api.bookdianight.com/ || true
exit $((1-ok))
