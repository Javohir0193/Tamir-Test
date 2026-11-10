#!/usr/bin/env bash
# e2e учун бўш Postgres базасини тайёрлайди: Supabase ўрнини босувчилар → baseline → ҳамма миграциялар → каталог → синов маълумоти.
# Ишлатиш: PGDATABASE=tamir_e2e bash e2e/setup-db.sh   (база бўш бўлиши керак; уланиш PG* ўзгарувчилардан).
# Ҳақиқий (test ёки prod) Supabase базасида ИШЛАТМАНГ: 00_supabase_stubs.sql сохта auth/vault/cron яратади.
set -euo pipefail
cd "$(dirname "$0")/.."
run() { echo "→ $1"; psql -q -v ON_ERROR_STOP=1 -f "$1" > /dev/null; }
mapfile -t UP < <(ls supabase/migrations/2*.sql | grep -v '\.down\.sql$' | grep -v '_00_baseline\.sql$' | sort)
run supabase/tests/00_supabase_stubs.sql
run supabase/migrations/20261020_00_baseline.sql
run supabase/tests/01_seed.sql
for f in "${UP[@]}"; do run "$f"; done
run supabase/ops/seed_catalog_from_js.sql
run supabase/tests/fixtures/fees.sql
run e2e/seed.sql
echo "OK: e2e базаси тайёр"
