#!/usr/bin/env bash
# T-002: repeatable migration rehearsal against a LOCAL throwaway database.
# Restores a dump, applies the repo's migrations, runs read-only checks, writes a report.
# It never targets staging or production: host allow-list + database name must end in _rehearsal.
#
# Env (defaults): DUMP_FILE=backend/bookdianight.dump  REHEARSAL_DB=bookdia_rehearsal
#   PGHOST=localhost PGPORT=5441 PGUSER=postgres PGPASSWORD=rehearsal_local_only (throwaway container)
#   REHEARSAL_CONTAINER=bookdia-rehearsal-pg  (psql/pg_restore run inside it, so no local client is needed)
set -uo pipefail
export MSYS_NO_PATHCONV=1   # Git Bash on Windows must not rewrite /tmp/... paths passed to docker

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DUMP_FILE="${DUMP_FILE:-$ROOT/backend/bookdianight.dump}"
REHEARSAL_DB="${REHEARSAL_DB:-bookdia_rehearsal}"
PGHOST="${PGHOST:-localhost}"
PGPORT="${PGPORT:-5441}"
PGUSER="${PGUSER:-postgres}"
PGPASSWORD="${PGPASSWORD:-rehearsal_local_only}"
CONTAINER="${REHEARSAL_CONTAINER:-bookdia-rehearsal-pg}"
REPORTS="$ROOT/project-docs/05-delivery/reports"
CHECKS_FILE="${CHECKS_FILE:-$REPORTS/check-violations.sql}"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="$REPORTS/rehearsal-$STAMP.md"

die() { echo "ERROR: $*" >&2; exit 2; }

# ---- safety: refuse before touching anything ----
case "$PGHOST" in
  localhost|127.0.0.1|::1) ;;
  *) die "PGHOST '$PGHOST' is not on the allow-list (localhost, 127.0.0.1)" ;;
esac
[[ "$REHEARSAL_DB" =~ ^[a-z0-9_]+_rehearsal$ ]] || die "REHEARSAL_DB '$REHEARSAL_DB' must match *_rehearsal"
[[ -f "$DUMP_FILE" ]] || die "dump not found: $DUMP_FILE"
docker inspect -f '{{.State.Running}}' "$CONTAINER" 2>/dev/null | grep -q true \
  || die "container '$CONTAINER' is not running"
HOSTPORT="$(docker port "$CONTAINER" 5432/tcp 2>/dev/null | head -1 | sed 's/.*://')"
[[ "$HOSTPORT" == "$PGPORT" ]] || die "container publishes port '$HOSTPORT', not PGPORT=$PGPORT (refusing to guess)"

psqlc() { docker exec -i -e PGPASSWORD="$PGPASSWORD" "$CONTAINER" psql -U "$PGUSER" -v ON_ERROR_STOP=1 "$@"; }
now_s() { date +%s; }
FAILS=()
fail() { FAILS+=("$1"); }
say() { echo "$*" | tee -a "$OUT"; }

{
  echo "# Migration rehearsal $STAMP"
  echo
  echo "Database \`$REHEARSAL_DB\` on $PGHOST:$PGPORT (container $CONTAINER). Dump: \`$(basename "$DUMP_FILE")\`."
  echo
} > "$OUT"

# 1. recreate the database
say "## 1. Recreate database"
psqlc -d postgres -c "DROP DATABASE IF EXISTS \"$REHEARSAL_DB\" WITH (FORCE);" >/dev/null || die "drop failed"
psqlc -d postgres -c "CREATE DATABASE \"$REHEARSAL_DB\";" >/dev/null || die "create failed"
psqlc -d "$REHEARSAL_DB" -c "CREATE EXTENSION IF NOT EXISTS postgis; CREATE EXTENSION IF NOT EXISTS btree_gist;" >/dev/null \
  || die "extensions failed"
say "- recreated with postgis, btree_gist"

# 2. restore
say; say "## 2. Restore dump"
DUMP_NATIVE="$DUMP_FILE"; command -v cygpath >/dev/null 2>&1 && DUMP_NATIVE="$(cygpath -w "$DUMP_FILE")"
docker cp "$DUMP_NATIVE" "$CONTAINER:/tmp/rehearsal.dump" >/dev/null || die "docker cp failed"
t0=$(now_s)
RESTORE_LOG="$(docker exec -e PGPASSWORD="$PGPASSWORD" "$CONTAINER" pg_restore -U "$PGUSER" -d "$REHEARSAL_DB" \
  --no-owner --no-privileges /tmp/rehearsal.dump 2>&1)"
rc=$?
docker exec "$CONTAINER" rm -f /tmp/rehearsal.dump >/dev/null 2>&1
# pg_restore warns that extensions already exist; only count other errors
ERRS="$(echo "$RESTORE_LOG" | grep -E "^pg_restore: error" | grep -v "already exists" || true)"
NERR=0; [[ -n "$ERRS" ]] && NERR="$(echo "$ERRS" | wc -l)"
if [[ $NERR -gt 0 ]]; then fail "restore reported $NERR error(s)"; echo "$ERRS" | head -5 | tee -a "$OUT"; fi
say "- restore took $(( $(now_s) - t0 ))s (exit $rc, errors other than 'already exists': $NERR)"

# 2b. T-005 baseline: purchase count and SUM(soldCount) before migrations (tables exist in the dump)
BEFORE_SOLD="$(psqlc -d "$REHEARSAL_DB" -At -c "SELECT COALESCE(SUM(\"soldCount\"),0) FROM \"EventTicketTier\";" 2>/dev/null || echo n/a)"
BEFORE_PUR="$(psqlc -d "$REHEARSAL_DB" -At -c "SELECT count(*) FROM \"EventPurchase\";" 2>/dev/null || echo n/a)"

# 3. migrate deploy (never `migrate dev`)
say; say "## 3. prisma migrate deploy"
export DATABASE_URL="postgresql://$PGUSER:$PGPASSWORD@$PGHOST:$PGPORT/$REHEARSAL_DB?schema=public"
cd "$ROOT/backend" || die "cd backend"
t0=$(now_s)
MIG_LOG="$(npx prisma migrate deploy 2>&1)"; rc=$?
say '```'
echo "$MIG_LOG" | grep -vE "^\s*$|injected env|dotenv" | tail -40 | tee -a "$OUT"
say '```'
[[ $rc -eq 0 ]] || fail "prisma migrate deploy failed (exit $rc)"
say "- migrate deploy took $(( $(now_s) - t0 ))s"
say; say "Last 15 migrations with duration (the dump was behind the repo, so the newest ones ran in this rehearsal):"
say '```'
psqlc -d "$REHEARSAL_DB" -At -F ' | ' -c "SELECT migration_name, round(extract(epoch FROM (finished_at - started_at))::numeric, 3) AS secs FROM _prisma_migrations ORDER BY started_at DESC, migration_name DESC LIMIT 15;" | tee -a "$OUT"
say '```'
BAD="$(psqlc -d "$REHEARSAL_DB" -At -c "SELECT count(*) FROM _prisma_migrations WHERE finished_at IS NULL OR rolled_back_at IS NOT NULL;")"
[[ "$BAD" == "0" ]] || fail "$BAD migration(s) unfinished or rolled back"

# 3b. drift
say; say "## 3b. Schema drift vs schema.prisma"
DRIFT="$(npx prisma migrate diff --from-url "$DATABASE_URL" --to-schema-datamodel prisma/schema.prisma --script 2>&1)"
UNEXPECTED="$(echo "$DRIFT" | grep -vE '^\s*$|^--|btree_gist|No difference|injected env|dotenv|Loaded Prisma config' || true)"
if [[ -n "$UNEXPECTED" ]]; then
  fail "unexpected schema drift"
  say '```'; echo "$DRIFT" | head -30 | tee -a "$OUT"; say '```'
else
  say "- no drift beyond the known btree_gist item (BUG-B04)"
fi

# 3c. T-005 tier-on-purchase checks
say; say "## 3c. Tier on purchase (T-005)"
AFTER_SOLD="$(psqlc -d "$REHEARSAL_DB" -At -c "SELECT COALESCE(SUM(\"soldCount\"),0) FROM \"EventTicketTier\";")"
AFTER_PUR="$(psqlc -d "$REHEARSAL_DB" -At -c "SELECT count(*) FROM \"EventPurchase\";")"
NULLTIER="$(psqlc -d "$REHEARSAL_DB" -At -c "SELECT count(*) FROM \"EventPurchase\" WHERE \"ticketTierId\" IS NULL AND \"ticketTierName\" IS NULL;")"
say "- SUM(soldCount) before=$BEFORE_SOLD after=$AFTER_SOLD; EventPurchase rows before=$BEFORE_PUR after=$AFTER_PUR; rows with NULL tier columns=$NULLTIER"
[[ "$BEFORE_SOLD" == "$AFTER_SOLD" ]] || fail "SUM(soldCount) changed across migrations ($BEFORE_SOLD -> $AFTER_SOLD)"
[[ "$AFTER_PUR" == "$NULLTIER" ]] || fail "EventPurchase rows with non-NULL tier columns after migrate"
TT="$(psqlc -d "$REHEARSAL_DB" < "$ROOT/backend/prisma/tests/tier_on_purchase.sql" 2>&1)" || fail "tier_on_purchase.sql errored"
echo "$TT" | grep -E "TIERTEST" | tee -a "$OUT"
echo "$TT" | grep -q "|FAIL" && fail "tier_on_purchase.sql reported FAIL"
echo "$TT" | grep -q "TIERTEST" || fail "tier_on_purchase.sql produced no result"

# 4. violation checks
say; say "## 4. Violation checks (GATE rows must be 0)"
say '```'
CHECKS="$(psqlc -d "$REHEARSAL_DB" -At -F '|' < "$CHECKS_FILE" 2>&1)" || fail "check-violations.sql errored"
echo "$CHECKS" | tee -a "$OUT"
say '```'
while IFS='|' read -r kind label count; do
  if [[ "$kind" == "GATE" && "$count" != "0" ]]; then fail "violation: $label ($count rows)"; fi
done <<< "$CHECKS"

# 5. stock leak (report only)
say; say "## 5. Stock-leak report (read-only, informational, first 60 lines)"
say '```'
psqlc -d "$REHEARSAL_DB" < "$REPORTS/stock-leak.sql" 2>&1 | head -60 | tee -a "$OUT"
say '```'

say; say "## 6. Migration 4 (T-015): backfill counts and review query"
PT="$(psqlc -d "$REHEARSAL_DB" -At < "$ROOT/backend/prisma/tests/event_pricing_mode.sql" 2>&1)" || fail "event_pricing_mode.sql errored"
say '```'
echo "$PT" | tee -a "$OUT"
say '```'
echo "$PT" | grep -q "|FAIL" && fail "event_pricing_mode.sql reported FAIL"
echo "$PT" | grep -q "PRICETEST" || fail "event_pricing_mode.sql produced no result"
say "Review query (tiers whose name or group contains pass; the product owner decides which become PASS by hand):"
say '```'
psqlc -d "$REHEARSAL_DB" < "$ROOT/backend/prisma/tests/event_pricing_mode_review.sql" 2>&1 | head -60 | tee -a "$OUT"
say '```'

say; say "## Summary"
if [[ ${#FAILS[@]} -eq 0 ]]; then
  say "RESULT: PASS"
else
  say "RESULT: FAIL"
  for f in "${FAILS[@]}"; do say "- $f"; done
fi
echo "report: $OUT"
[[ ${#FAILS[@]} -eq 0 ]]
