#!/usr/bin/env bash
# =============================================================================
# Bootstrap an EMPTY AMP database to the point where AMP boots and serves login.
# =============================================================================
#
# This is NOT a substitute for a country dump. It produces a structurally
# complete but empty AMP: no activities, donors, sectors or locations. Restore a
# real dump instead whenever you can (scripts/restore.sh).
#
# Order of work:
#   1. Hibernate schema  - DigiSchemaExport, run inside the amp container
#   2. Quartz schema     - upstream Quartz 1.8.5 postgres DDL
#   3. Legacy relations  - structures the current model dropped but views still read
#   4. Helper functions  - extracted from AMP's patch tree, plus five that no patch
#                          defines and which only ever exist inside a dump
#   5. View patches      - the 437 xmlpatches/general/views patches, applied in
#                          repeated passes: they depend on each other, and AMP's
#                          own patcher aborts the entire run on the first failure
#   6. Seed data         - site, locale, currency, global settings, FM template,
#                          fiscal calendar, module instances, admin user
#
# Usage:
#   docker compose up -d
#   ./docker/bootstrap/bootstrap.sh
#   docker compose restart amp
#
# Env: AMP_SERVICE, DB_SERVICE, AMP_DB_NAME, AMP_DB_USER, VIEW_PASSES
# =============================================================================
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
SQL="$HERE/sql"
TOOLS="$HERE/tools"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

AMP_SERVICE="${AMP_SERVICE:-amp}"
DB_SERVICE="${DB_SERVICE:-db}"
AMP_DB_NAME="${AMP_DB_NAME:-amp}"
AMP_DB_USER="${AMP_DB_USER:-amp}"
VIEW_PASSES="${VIEW_PASSES:-25}"

cd "$REPO"
# Git Bash rewrites /container/paths passed to docker; disable that per-call
# rather than globally, or paths handed to python get mangled too.
dc() { MSYS_NO_PATHCONV=1 docker compose "$@"; }

psql_q() {
    dc exec -T "$DB_SERVICE" \
        psql -U "$AMP_DB_USER" -d "$AMP_DB_NAME" -tAc "$1" | tr -d '\r'
}

# psql_f <file> [extra psql args...]
psql_f() {
    local f="$1"; shift
    dc exec -T "$DB_SERVICE" \
        psql -U "$AMP_DB_USER" -d "$AMP_DB_NAME" "$@" < "$f"
}

step() { printf '\n=== %s ===\n' "$1"; }
die()  { echo "ERROR: $1" >&2; exit 1; }

# --- 1. Hibernate schema -----------------------------------------------------
step "1/6 Hibernate schema"
if [ "$(psql_q "SELECT count(*) FROM information_schema.tables WHERE table_schema='public'")" -lt 100 ]; then
    dc exec -T "$AMP_SERVICE" bash -s < "$TOOLS/run-schema-export.sh" \
        > "$WORK/schema.log" 2>&1 \
        || { tail -25 "$WORK/schema.log"; die "DigiSchemaExport failed"; }
    echo "created tables: $(psql_q "SELECT count(*) FROM information_schema.tables WHERE table_schema='public'")"
else
    echo "schema already present, skipping"
fi

# --- 2. Quartz ---------------------------------------------------------------
# The upstream script starts with unconditional DROPs, which fail on a fresh
# database; that is expected, so this one is not run with ON_ERROR_STOP.
step "2/6 Quartz schema"
psql_f "$SQL/10-quartz.sql" -q > "$WORK/quartz.log" 2>&1
echo "qrtz tables: $(psql_q "SELECT count(*) FROM information_schema.tables WHERE table_schema='public' AND table_name LIKE 'qrtz%'")"

# --- 3. Legacy relations -----------------------------------------------------
step "3/6 Legacy relations"
psql_f "$SQL/20-legacy-relations.sql" -q -v ON_ERROR_STOP=1 || die "legacy relations failed"
echo "ok"

# --- 4. Helper functions -----------------------------------------------------
step "4/6 Helper functions"
python "$TOOLS/extract_helper_functions.py" "$WORK/helpers.sql" || die "helper extraction failed"
psql_f "$WORK/helpers.sql" -q -v ON_ERROR_STOP=1 || die "helper functions failed"
for f in 30-location-functions 31-view-functions 32-drop-view-function 33-missing-views; do
    psql_f "$SQL/$f.sql" -q -v ON_ERROR_STOP=1 || die "$f failed"
done
echo "ok"

# --- 4b. Dimension tables and ETL changelog ----------------------------------
# The NiReports dimensions (ni_all_*) and the amp_etl_changelog structures live
# in versioned patches, not in general/views, but ~135 of the view patches read
# them. Apply the newest patch for each straight from AMP's own tree.
step "4b/6 Dimension tables"
python "$TOOLS/extract_patch.py" "$WORK/dims.sql" \
    "2.z10.01/AMP-18110-logging-structures-and-triggers.xml" \
    "2.z12.04/AMP-23377-ni-schema-triggers.xml" \
    "2.5.13/AMP-16239-define-translate-function.xml" \
    "3.5.00/AMP-29544-recreate-orgs-dimension.xml" \
    "3.5.00/AMP-29855-locs-merge-fixing.xml" \
    "2.z12.00/AMP-21453-define-sector-nicache-tables.xml" \
    "2.z12.00/AMP-21453-define-program-nicache-tables.xml" \
    "2.z12.00/AMP-22084-create-empty-view.xml" \
    "2.z13.00/AMP-22898-me-reports.xml" \
    || die "dimension patch extraction failed"
# run twice: the cache-refresh calls need triggers/functions the same set defines
psql_f "$WORK/dims.sql" -q > "$WORK/dims1.log" 2>&1
psql_f "$WORK/dims.sql" -q > "$WORK/dims2.log" 2>&1
echo "ni_* dimensions: $(psql_q "SELECT count(*) FROM information_schema.tables WHERE table_schema='public' AND table_name LIKE 'ni_all%'")"

# --- 4c. Patch registry ------------------------------------------------------
# Pre-record every patch so AMP's discovery inserts nothing (that first insert
# is what triggers the AmpEntityInterceptor auto-flush recursion) and so the
# versioned migrations are not replayed against a schema built from the current
# mappings. See tools/build_patch_registry.py for the full reasoning.
step "4c/6 Patch registry"
dc exec -T "$AMP_SERVICE" bash -s < "$TOOLS/list-deployed-patches.sh" \
    | tr -d '\r' > "$WORK/patches.tsv" || die "patch listing failed"
python "$TOOLS/build_patch_registry.py" "$WORK/registry.sql" < "$WORK/patches.tsv" \
    || die "patch registry build failed"
psql_f "$WORK/registry.sql" -q -v ON_ERROR_STOP=1 || die "patch registry insert failed"

# One-time Quartz job registration AMP performs on first boot. It calls
# getJobClassesByClassfullName() outside a managed Hibernate session and throws;
# a restored dump already has this row, so pre-create it.
psql_f "$SQL/40-quartz-job.sql" -q -v ON_ERROR_STOP=1 || die "quartz job seed failed"

# --- 5. View patches ---------------------------------------------------------
# Several passes are needed: the views depend on each other, and the legacy-cache
# rebuild at pass 2 CASCADE-drops ~35 dependent views that later passes restore.
step "5/6 View patches (${VIEW_PASSES} passes)"
python "$TOOLS/build_view_patches.py" "$WORK/views.sql" || die "view extraction failed"
prev_views=-1
stable=0
for i in $(seq 1 "$VIEW_PASSES"); do
    psql_f "$WORK/views.sql" -q > "$WORK/views_$i.log" 2>&1
    views="$(psql_q "SELECT count(*) FROM information_schema.views WHERE table_schema='public'")"
    errs="$(grep -c '^ERROR' "$WORK/views_$i.log")"
    printf '  pass %d: views=%s errors=%s\n' "$i" "$views" "$errs"

    # The legacy caches are built FROM views these passes create, and rebuilding
    # them CASCADE-drops ~35 dependent views that later passes restore — so do it
    # once, early, and let the loop converge afterwards.
    if [ "$i" -eq 2 ]; then
        psql_f "$SQL/21-legacy-caches.sql" -q > "$WORK/caches.log" 2>&1
        prev_views=-1
        continue
    fi

    # Stop only after several consecutive identical passes: the view count can
    # plateau for a pass or two and then resolve a few more, so a single
    # unchanged pass is not evidence that it has finished.
    sig="$views:$errs"
    if [ "$sig" = "$prev_views" ] && [ "$i" -ge "${VIEW_MIN_PASSES:-10}" ]; then
        stable=$((stable + 1))
        [ "$stable" -ge 3 ] && { echo "  converged"; break; }
    else
        stable=0
    fi
    prev_views="$sig"
done

# --- 6. Seed data ------------------------------------------------------------
step "6/6 Seed data"
psql_f "$SQL/50-core-seed.sql" -q -v ON_ERROR_STOP=1 || die "core seed failed"

# global settings AMP's own patches insert
python "$TOOLS/extract_global_settings.py" "$WORK/gs.sql" || die "settings extraction failed"
psql_f "$WORK/gs.sql" -q > "$WORK/gs.log" 2>&1

psql_f "$SQL/51-fm-and-calendar.sql" -q -v ON_ERROR_STOP=1 || die "fm/calendar failed"

# settings declared in GlobalSettingsConstants that no patch inserts
grep -oE 'public static final String [A-Z_0-9]+ *= *"[^"]+"' \
    "$REPO/amp/src/main/java/org/digijava/module/aim/helper/GlobalSettingsConstants.java" \
    | sed 's/.*= *"//; s/"$//' | sort -u > "$WORK/consts.txt"

python "$TOOLS/check_missing_settings.py" "$WORK/consts.txt" "$WORK/check.sql" || die "settings check failed"
psql_f "$WORK/check.sql" -tA | tr -d '\r' | sed '/^$/d' > "$WORK/missing.txt"
if [ -s "$WORK/missing.txt" ]; then
    python "$TOOLS/generate_setting_defaults.py" "$WORK/missing.txt" "$WORK/defaults.sql" || die "defaults failed"
    psql_f "$WORK/defaults.sql" -q > "$WORK/defaults.log" 2>&1
fi

psql_f "$SQL/53-numeric-settings.sql" -q -v ON_ERROR_STOP=1 || die "numeric settings failed"
psql_f "$SQL/54-site-wiring.sql"      -q -v ON_ERROR_STOP=1 || die "site wiring failed"
psql_f "$SQL/60-admin-user.sql"       -q -v ON_ERROR_STOP=1 || die "admin user failed"
echo "ok"

# --- summary -----------------------------------------------------------------
cat <<EOF

=============================================================================
Bootstrap complete.

  tables           $(psql_q "SELECT count(*) FROM information_schema.tables WHERE table_schema='public'")
  views            $(psql_q "SELECT count(*) FROM information_schema.views WHERE table_schema='public'")
  functions        $(psql_q "SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public'")
  global settings  $(psql_q "SELECT count(*) FROM amp_global_settings")

Next:
  docker compose restart $AMP_SERVICE
  open http://localhost:8080/

  login: admin@amp.org / admin123   (change it after first login)

This database has no activities, donors, sectors or locations. It is an empty
AMP, not a working country instance.
=============================================================================
EOF
