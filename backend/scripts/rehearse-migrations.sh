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
# 2c. T-029 baseline: rows with NULL geog, split by valid / invalid coordinates, before migrations
geog_counts() {
  psqlc -d "$REHEARSAL_DB" -At -F ' ' -c "SELECT
    (SELECT count(*) FROM \"$1\"),
    (SELECT count(*) FROM \"$1\" WHERE geog IS NULL AND lat BETWEEN -90 AND 90 AND lng BETWEEN -180 AND 180),
    (SELECT count(*) FROM \"$1\" WHERE geog IS NULL AND NOT (lat BETWEEN -90 AND 90 AND lng BETWEEN -180 AND 180));" 2>/dev/null || echo "n/a n/a n/a"
}
read -r CLUB_TOTAL_B CLUB_FILL_B CLUB_BAD_B <<< "$(geog_counts Club | tr '|' ' ')"
read -r EVENT_TOTAL_B EVENT_FILL_B EVENT_BAD_B <<< "$(geog_counts Event | tr '|' ' ')"

# 2d. T-043 baseline: count and checksum of existing Artist and EventLineup rows before migrations
ART_Q="SELECT count(*) || '|' || COALESCE(md5(string_agg(concat_ws('~', id, name, \"nameKey\", avatar, \"audioPreviewUrl\", \"spotifyUrl\", \"soundcloudUrl\", \"isVerified\", \"followerCount\", \"createdAt\", \"updatedAt\"), '|' ORDER BY id)), '') FROM \"Artist\";"
LIN_Q="SELECT count(*) || '|' || COALESCE(md5(string_agg(concat_ws('~', id, \"eventId\", \"artistId\", \"artistName\", \"artistAvatar\", \"audioPreviewUrl\", \"spotifyUrl\", \"soundcloudUrl\", \"isVerified\", \"sortOrder\"), '|' ORDER BY id)), '') FROM \"EventLineup\";"
ART_B="$(psqlc -d "$REHEARSAL_DB" -At -c "$ART_Q" 2>/dev/null || echo "n/a|n/a")"
LIN_B="$(psqlc -d "$REHEARSAL_DB" -At -c "$LIN_Q" 2>/dev/null || echo "n/a|n/a")"

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

say; say "## 7. Migration 3 (T-029): geog backfill counts and synthetic proof"
read -r CLUB_TOTAL_A CLUB_FILL_A CLUB_BAD_A <<< "$(geog_counts Club | tr '|' ' ')"
read -r EVENT_TOTAL_A EVENT_FILL_A EVENT_BAD_A <<< "$(geog_counts Event | tr '|' ' ')"
say "- Club rows=$CLUB_TOTAL_B; NULL geog with valid lat/lng: before=$CLUB_FILL_B after=$CLUB_FILL_A; NULL geog with invalid coordinates (reported, untouched): before=$CLUB_BAD_B after=$CLUB_BAD_A"
say "- Event rows=$EVENT_TOTAL_B; NULL geog with valid lat/lng: before=$EVENT_FILL_B after=$EVENT_FILL_A; NULL geog with invalid coordinates (reported, untouched): before=$EVENT_BAD_B after=$EVENT_BAD_A"
[[ "$CLUB_FILL_A" == "0" && "$EVENT_FILL_A" == "0" ]] || fail "rows with NULL geog and valid lat/lng remain after migrate"
[[ "$CLUB_BAD_B" == "$CLUB_BAD_A" && "$EVENT_BAD_B" == "$EVENT_BAD_A" ]] || fail "rows with invalid coordinates changed across migrations"
GEOG_MIG="$ROOT/backend/prisma/migrations/20261123140000_backfill_geog/migration.sql"
GT="$(cat "$ROOT/backend/prisma/tests/geog_backfill_1_seed.sql" "$GEOG_MIG" \
  "$ROOT/backend/prisma/tests/geog_backfill_2_first.sql" "$GEOG_MIG" \
  "$ROOT/backend/prisma/tests/geog_backfill_3_second.sql" | psqlc -d "$REHEARSAL_DB" -At 2>&1)" || fail "geog_backfill sql errored"
say '```'
echo "$GT" | grep -E "GEOGTEST|ERROR" | tee -a "$OUT"
say '```'
echo "$GT" | grep -q "|FAIL" && fail "geog_backfill sql reported FAIL"
echo "$GT" | grep -q "GEOGTEST" || fail "geog_backfill sql produced no result"

say; say "## 8. Migration 10 (T-031): cities and filter options backfill, near-duplicates, synthetic idempotency"
FT="$(psqlc -d "$REHEARSAL_DB" -At < "$ROOT/backend/prisma/tests/filter_options_backfill.sql" 2>&1)" || fail "filter_options_backfill.sql errored"
say '```'
echo "$FT" | tee -a "$OUT"
say '```'
echo "$FT" | grep -q "|FAIL" && fail "filter_options_backfill.sql reported FAIL"
echo "$FT" | grep -q "FILTERTEST" || fail "filter_options_backfill.sql produced no result"
FILTER_MIG="$ROOT/backend/prisma/migrations/20261123150000_add_cities_filter_options/migration.sql"
FILTER_BACKFILL="$(sed -n '/^INSERT INTO "FilterOption"/,$p' "$FILTER_MIG")"
FI="$( { cat "$ROOT/backend/prisma/tests/filter_options_idempotent_1_seed.sql"; echo "$FILTER_BACKFILL"; \
  cat "$ROOT/backend/prisma/tests/filter_options_idempotent_2_first.sql"; echo "$FILTER_BACKFILL"; \
  cat "$ROOT/backend/prisma/tests/filter_options_idempotent_3_second.sql"; } | psqlc -d "$REHEARSAL_DB" -At 2>&1)" || fail "filter_options idempotency sql errored"
say '```'
echo "$FI" | grep -E "FILTERTEST|ERROR" | tee -a "$OUT"
say '```'
echo "$FI" | grep -q "|FAIL" && fail "filter_options idempotency sql reported FAIL"
echo "$FI" | grep -q "ERROR" && fail "filter_options idempotency sql raised an error"
echo "$FI" | grep -q "FILTERTEST" || fail "filter_options idempotency sql produced no result"

say; say "## 9. Migration 11 (T-039): engagement tables empty, unique and primary key constraints, cascades"
for T in EventInterest UserRecentEventView EventViewDaily; do
  say "- $T rows after migrate: $(psqlc -d "$REHEARSAL_DB" -At -c "SELECT count(*) FROM \"$T\";")"
done
ET="$(psqlc -d "$REHEARSAL_DB" -At < "$ROOT/backend/prisma/tests/engagement_constraints.sql" 2>&1)" || fail "engagement_constraints.sql errored"
say '```'
echo "$ET" | grep -E "ENGAGETEST|ERROR" | tee -a "$OUT"
say '```'
echo "$ET" | grep -q "|FAIL" && fail "engagement_constraints.sql reported FAIL"
echo "$ET" | grep -q "ERROR" && fail "engagement_constraints.sql raised an error"
echo "$ET" | grep -q "ENGAGETEST" || fail "engagement_constraints.sql produced no result"

say; say "## 10. Migration 12 (T-043): artist bio and socialLinks, existing artists and lineups untouched"
say "- Artist before (count|checksum): $ART_B; EventLineup before: $LIN_B"
AT="$( { echo "SET t043.artist_n = '${ART_B%%|*}'; SET t043.artist_sum = '${ART_B#*|}'; SET t043.lineup_n = '${LIN_B%%|*}'; SET t043.lineup_sum = '${LIN_B#*|}';"; cat "$ROOT/backend/prisma/tests/artist_profile_fields.sql"; } | psqlc -d "$REHEARSAL_DB" -At 2>&1)" || fail "artist_profile_fields.sql errored"
say '```'
echo "$AT" | grep -E "ARTISTTEST|ERROR" | tee -a "$OUT"
say '```'
echo "$AT" | grep -q "|FAIL" && fail "artist_profile_fields.sql reported FAIL"
echo "$AT" | grep -q "ERROR" && fail "artist_profile_fields.sql raised an error"
echo "$AT" | grep -q "ARTISTTEST" || fail "artist_profile_fields.sql produced no result"

AMIG="$ROOT/backend/prisma/migrations/20261123170000_add_artist_profile_fields/migration.sql"
AS="$(cat "$ROOT/backend/prisma/tests/artist_profile_fields_synth_1.sql" "$AMIG" "$ROOT/backend/prisma/tests/artist_profile_fields_synth_3.sql" | psqlc -d "$REHEARSAL_DB" -At 2>&1)" || fail "artist_profile_fields synthetic sql errored"
say '```'
echo "$AS" | grep -E "ARTISTTEST|ERROR" | tee -a "$OUT"
say '```'
echo "$AS" | grep -q "|FAIL" && fail "artist_profile_fields synthetic sql reported FAIL"
echo "$AS" | grep -q "ERROR" && fail "artist_profile_fields synthetic sql raised an error"
echo "$AS" | grep -q "ARTISTTEST" || fail "artist_profile_fields synthetic sql produced no result"

say; say "## Summary"
if [[ ${#FAILS[@]} -eq 0 ]]; then
  say "RESULT: PASS"
else
  say "RESULT: FAIL"
  for f in "${FAILS[@]}"; do say "- $f"; done
fi
echo "report: $OUT"
[[ ${#FAILS[@]} -eq 0 ]]
