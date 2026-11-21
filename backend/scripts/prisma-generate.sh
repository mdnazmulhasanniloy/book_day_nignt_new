#!/bin/bash
set -euo pipefail

# Generate the local Prisma client
npx prisma generate "$@"

# ---------------------------------------------------------
# Monorepo IDE Fix:
# Copy the generated Prisma client into each service's
# node_modules so that VS Code and TypeScript can find
# the exported types instead of looking at empty stubs.
#
# npm/yarn: node_modules/.prisma
# pnpm:     node_modules/.pnpm/@prisma+client@.../node_modules/.prisma
# ---------------------------------------------------------

echo "Copying generated Prisma client to microservices for IDE support..."

resolve_prisma_client_dir() {
  if [ -d "node_modules/.prisma/client" ]; then
    echo "node_modules/.prisma"
    return 0
  fi

  local pnpm_client
  pnpm_client="$(find node_modules/.pnpm -type d -path '*/node_modules/.prisma/client' 2>/dev/null | head -n 1 || true)"
  if [ -n "$pnpm_client" ]; then
    dirname "$pnpm_client"
    return 0
  fi

  return 1
}

PRISMA_DIR="$(resolve_prisma_client_dir)" || {
  echo "ERROR: generated Prisma client not found under node_modules/.prisma or pnpm store"
  exit 1
}

echo "Using Prisma client from: $PRISMA_DIR"

# Keep a stable root copy for tools that expect node_modules/.prisma
if [ "$PRISMA_DIR" != "node_modules/.prisma" ]; then
  mkdir -p node_modules/.prisma
  rm -rf node_modules/.prisma/client
  cp -R "$PRISMA_DIR/client" node_modules/.prisma/client
fi

copy_to_service() {
  local service="$1"
  mkdir -p "$service/node_modules"
  rm -rf "$service/node_modules/.prisma"
  cp -R node_modules/.prisma "$service/node_modules/"
  # Prefer existing service @prisma/client; only seed if missing
  if [ ! -d "$service/node_modules/@prisma/client" ] && [ -d "node_modules/@prisma" ]; then
    mkdir -p "$service/node_modules/@prisma"
    cp -R node_modules/@prisma/client "$service/node_modules/@prisma/" 2>/dev/null || true
  fi
}

copy_to_service server
copy_to_service worker
copy_to_service scheduler

echo "Prisma generation complete!"
