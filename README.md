# Ta'mir

Қурилиш бозоридан материалларни буюртма қилиш ва етказиб бериш хизмати.

## Иловалар

| Саҳифа | Ким учун |
|---|---|
| `index.html` | Харидор: каталог, ҳисоблагич, сават, буюртма, тўлов |
| `admin.html` | Админ панел (Telegram орқали кириш + шахсий PIN) |
| `collector.html` | Бозордаги йиғувчи (Telegram WebApp) |
| `driver.html` | Ҳайдовчи |
| `seller.html` | Дўкон: нарх ва қолдиқ (@tamir_sotuvchi_bot ичида ёки браузерда «Telegram орқали кириш») |

Стек: статик HTML/JS (йиғиш шарт эмас), Supabase (Postgres, RPC, Auth, Edge Function `tg-bot`), Telegram, Netlify.

## Муҳитлар

`config.js` сайт манзилига қараб базани ўзи танлайди:

- `tamir-test.netlify.app` → **test** базаси
- қолган манзиллар → **prod** базаси

`config.js` да фақат очиқ (publishable) калитлар туради. Махфий калитни (secret, service_role) кодга ҳеч қачон ёзманг.

## Маҳаллий ишга тушириш

```bash
npx serve .        # кейин http://localhost:3000
```

## Текширувлар

```bash
node scripts/check-refs.mjs     # уланган файллар мавжудми
node scripts/check-inline.mjs   # HTML ичидаги скриптлар синтаксиси
```

Худди шу текширувлар ҳар бир PR'да GitHub Actions'да ишлайди (`.github/workflows/ci.yml`), қўшимча gitleaks махфий калитларни қидиради.

## База

`supabase/audit/` — Supabase SQL Editor'да ишга тушириладиган, **фақат ўқийдиган** сўровлар:

- `01_security_audit.sql` — RLS, қоидалар, ҳуқуқлар, функциялар хавфсизлиги
- `02_export_schema.sql` — жадваллар, функциялар ва қоидаларнинг тузилмаси (маълумотсиз)
- `03_preflight_order_flow.sql` — буюртма оқими синовидан олдин созламаларни текшириш

`supabase/migrations/` — базадаги ҳар бир ўзгариш. Ном: `ЙИЛОЙКУН_NN_номи.sql`, ёнида орқага қайтариш `…down.sql`.

- `20261020_00_baseline.sql` — бошланғич тузилма. **Фақат янги, бўш Supabase лойиҳада** (prod'ни нолдан қуриш учун).
- Кейин `01`, `02`, … тартиб билан. Ҳар бирининг бошида нима ўзгариши ва қаерда ишга туширилиши ёзилган.
- Supabase SQL Editor'га файлни тўлиқ қўйиб Run. Хато бўлса ҳаммаси бекор бўлади (`begin … commit`).

`supabase/ops/test_reset_data.sql` — **фақат test** базада буюртмалар ва пул ҳаракатини тозалаш (каталог, ходимлар, созламалар қолади, олдин захира олади).

`supabase/tests/` ва `scripts/db-test.sh` — CI ҳар PR'да бўш Postgres'га baseline ва ҳамма миграцияларни қўллайди, орқага қайтаради, яна қўллайди, кейин RLS, ҳуқуқлар ва `search_path` ни текширади. Маҳаллий:

```bash
createdb tamir_ci && PGDATABASE=tamir_ci scripts/db-test.sh
```

`tg-bot` Edge Function коди бу очиқ репозиторийда эмас (махфий репо).

## Ишлаш тартиби

1. Ҳар бир ўзгариш алоҳида шохчада ва PR орқали.
2. Аввал test сайтда текширилади, кейин prod.
3. Базадаги ҳар бир ўзгариш орқага қайтариш (down) скрипти билан.
