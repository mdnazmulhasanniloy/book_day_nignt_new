#!/usr/bin/env python3
"""Merge missing keys from a source .env into the VPS .env without overwriting existing values."""
from pathlib import Path
import re
import sys

def parse_env(text: str) -> dict[str, str]:
    out = {}
    for raw in text.splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        if line == '"':
            continue
        key, val = line.split("=", 1)
        key = key.strip()
        if not re.match(r"^[A-Za-z_][A-Za-z0-9_]*$", key):
            continue
        out[key] = val
    return out

src = Path(sys.argv[1]).read_text(encoding="utf-8")
dst_path = Path(sys.argv[2])
dst = dst_path.read_text(encoding="utf-8")
src_map = parse_env(src)
dst_map = parse_env(dst)

# Never overwrite these operational keys already set for local docker network
preserve = {
    "DATABASE_URL",
    "REDIS_HOST",
    "REDIS_PASSWORD",
    "REDIS_PORT",
    "REDIS_TLS",
    "POSTGRES_PASSWORD",
    "NODE_ENV",
    "SERVER_URL",
    "PORT",
}

missing = []
for k, v in src_map.items():
    if k in preserve:
        continue
    if k not in dst_map or dst_map[k] in ("", '""', "''"):
        missing.append(k)
        # append
        dst = dst.rstrip() + f"\n{k}={v}\n"

# Ensure required runtime flags
for k, v in {
    "REDIS_TLS": '"false"',
    "SERVER_URL": '"https://api.bookdianight.com"',
    "NODE_ENV": '"production"',
}.items():
    if k not in parse_env(dst):
        dst = dst.rstrip() + f"\n{k}={v}\n"
        missing.append(k)

dst_path.write_text(dst if dst.endswith("\n") else dst + "\n", encoding="utf-8")
print("added_or_filled:", ",".join(missing) if missing else "(none)")
print("dst_keys:", len(parse_env(dst)))
