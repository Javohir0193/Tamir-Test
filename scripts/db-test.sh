#!/usr/bin/env bash
# Бўш Postgres'да: baseline -> ҳамма миграциялар -> ҳаммасини орқага -> яна олдинга. Ҳар қадамдан кейин текширув.
# Ишлатиш: PGDATABASE=... scripts/db-test.sh   (psql уланиш PG* ўзгарувчилардан олинади)
set -euo pipefail
cd "$(dirname "$0")/.."
run() { echo "→ $1"; psql -q -v ON_ERROR_STOP=1 -f "$1" > /dev/null; }
mapfile -t UP < <(ls supabase/migrations/2*.sql | grep -v '\.down\.sql$' | grep -v '_00_baseline\.sql$' | sort)

run supabase/tests/00_supabase_stubs.sql
run supabase/migrations/20261020_00_baseline.sql
run supabase/tests/01_seed.sql
for f in "${UP[@]}"; do run "$f"; done
run supabase/tests/02_checks.sql
for ((i=${#UP[@]}-1; i>=0; i--)); do d="${UP[$i]%.sql}.down.sql"; [ -f "$d" ] && run "$d"; done
for f in "${UP[@]}"; do run "$f"; done
run supabase/tests/02_checks.sql
run supabase/ops/seed_catalog_from_js.sql
run supabase/tests/03_catalog_checks.sql
run supabase/tests/04_cart_compare_checks.sql
run supabase/tests/05_pref_shop_checks.sql
run supabase/ops/seed_catalog_from_js.sql      # қайта юклаш хавфсиз (идемпотент)
run supabase/ops/test_reset_data.sql
echo "OK: ${#UP[@]} та миграция олдинга, орқага ва яна олдинга ўтди"
