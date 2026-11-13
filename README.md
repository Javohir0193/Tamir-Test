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

## Дўкон кабинети: файлдан нарх юклаш

`seller.html` → «Нархлар» → «Excel / CSV файлдан нарх юклаш». Дўкон намуна файлни (ҳамма товарлари, ID ва ҳозирги нархи билан) юклаб олади,
Excel'да «Нарх» ва «Бор» устунларини тўлдиради ва .xlsx ёки .csv файлни қайта танлайди. Ўз жадвали ҳам бўлади (товар номи ва нарх устунлари).

- `.xlsx` браузернинг ўзида ўқилади (`xlsx-lite.js`, ташқи кутубхонасиз; npm'даги `xlsx@0.18.5` заифликлари туфайли).
- Бозор нархидан (бошқа дўконлар медианаси) `price_dev_pct` (одатда 30%) дан кўп фарқ қилган қатор белгиланмайди, дўкон ўзи текширади.
- Сақлаш битта транзакцияда, нарх тарихига `seller` / `seller_file` манбаси билан ёзилади (29-миграция: `seller_offers_save`, `seller_offers_check`, фақат бот чақиради).

### Янги товар таклифи ва модерация

Дўкон каталогда йўқ товарни битта-битта («➕ Каталогда йўқ товарни таклиф қилиш») ёки файлдан юклашда топилмаган қаторлардан бирданига
(«➕ Топилмаганларни таклиф қилиш», 50 тагача) таклиф қилади. Ҳолатини «📋 Менинг таклифларим» да кўради (рад этилса — сабаби билан).
Админ «Нархлар» бўлимида номи, тавсифи, ўлчови ва тоифасини тузатиб қўшади ёки сабаб ёзиб рад этади; таклиф қилганга Telegram хабари боради.
Ботдаги «✅ / ❌» тугмалари ҳам шу қоида билан (30-миграция: `product_propose`, `product_decide`, `seller_proposals`).
Дубликат кирилл/лотин бўйича аниқланади, дўконга 20 та / жами 300 та кутилаётган таклиф чеклови бор.

## Муҳитлар

`config.js` сайт манзилига қараб базани ўзи танлайди:

- `javohir0193.github.io/Tamir-Test/` (GitHub Pages, `main` дан ўзи янгиланади) ва `tamir-test.netlify.app` → **test** базаси
- қолган манзиллар → **prod** базаси

`config.js` да фақат очиқ (publishable) калитлар туради. Махфий калитни (secret, service_role) кодга ҳеч қачон ёзманг.

## Маҳаллий ишга тушириш

```bash
npx serve .        # кейин http://localhost:3000
```

## Саҳифа коди ва CSP

Ҳар саҳифанинг JavaScript коди алоҳида файлда: `index.html` → `page-index.js`, `admin.html` → `page-admin.js`
(+ `admin-frame.js`), `seller.html` → `page-seller.js`, `collector.html` → `page-collector.js`,
`driver.html` → `page-driver.js`, `register.html` → `page-register.js`. CSP `script-src`'да `'unsafe-inline'` йўқ,
шунинг учун HTML ичига `<script>…</script>` ёки `onclick="…"` ёзманг — браузер уни ишга туширмайди.
Ҳодисалар учун `addEventListener` ёки `el.onclick = …` ишлатинг.

Харидор сайтида (`index.html`) экран `paint(el, html)` билан чизилади (`dom-patch.js`): натижа `el.innerHTML = html` билан бир хил,
лекин фақат ўзгарган матн/атрибут/элемент янгиланади (саҳифа сакрамайди, скрол ва фокус жойида қолади). Янги рўйхат элементларига
калит беринг (`data-pid`, `data-ord`, `id`) — шунда тартиб ўзгарса ҳам элемент қайта яратилмайди. Харита (`data-map`) ва
`data-due` вақт ҳисоблагичига тегилмайди. Текширув: `e2e/tests/render-patch.spec.mjs`.

## Текширувлар

```bash
node scripts/check-refs.mjs     # уланган файллар мавжудми
node scripts/check-inline.mjs   # HTML'да inline <script> ва onclick="…" йўқлиги (CSP 'unsafe-inline'сиз)
node scripts/sync-csp-meta.mjs  # _headers даги CSP'ни саҳифалардаги <meta> га ёзади (GitHub Pages учун; CI --check)
node scripts/check-csp.mjs      # CSP: ҳар саҳифани браузерда очиб, блокланган манба йўқлигини текширади (Playwright керак)
```

Худди шу текширувлар ҳар бир PR'да GitHub Actions'да ишлайди (`.github/workflows/ci.yml`), қўшимча gitleaks махфий калитларни қидиради.

CI'да учта иш бор: `checks` (юқоридагилар), `db` (миграциялар + pgTAP) ва `e2e` (Playwright). `main` ҳимояси шу учаласи яшил бўлишини талаб қилади.
Dependabot (`.github/dependabot.yml`) ҳар душанба GitHub Actions ва `e2e/` кутубхоналарини текшириб PR очади.

### e2e (Playwright)

`e2e/` — харидор сайтини ҳақиқий браузерда текширади: бозор → сават → буюртма → «🧪 Тестовая оплата» → тўланди (телефон ва компьютер ўлчамида).
Сайт маҳаллий `127.0.0.1/Tamir-Test/` да очилади, Supabase сўровлари `e2e/gateway.mjs` орқали маҳаллий Postgres'даги **ҳақиқий** функцияларга (create_order, pay_test …)
anon/authenticated роли билан узатилади. Test ва prod Supabase'га ҳеч нарса кетмайди (prod'га уриниш — тест хатоси). Харидор «Telegram орқали кирган» ҳолати `e2e/seed.sql` да.

```bash
createdb tamir_e2e
cd e2e && npm ci && npx playwright install chromium
PGDATABASE=tamir_e2e npm run db && PGDATABASE=tamir_e2e npm test
```

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

`supabase/tests/` ва `scripts/db-test.sh` — CI ҳар PR'да бўш Postgres'га baseline ва ҳамма миграцияларни қўллайди, орқага қайтаради, яна қўллайди, кейин RLS, ҳуқуқлар ва `search_path` ни текширади.
`supabase/tests/pgtap/` — pgTAP тестлари: API шартномаси (сайт чақирадиган функциялар, имзо, ҳуқуқлар) ва асосий оқим (кириш шарти, текширувлар, сервер ҳисоблаган сумма, RLS, «Тестовая оплата», қайта тўлов йўқлиги). Ҳар файл ўзи `rollback` қилади. Маҳаллий учун `postgresql-16-pgtap` ва `pg_prove` керак:

```bash
createdb tamir_ci && PGDATABASE=tamir_ci scripts/db-test.sh
```

`tg-bot` Edge Function коди бу очиқ репозиторийда эмас (махфий репо).

## Ишлаш тартиби

1. Ҳар бир ўзгариш алоҳида шохчада ва PR орқали.
2. Аввал test сайтда текширилади, кейин prod.
3. Базадаги ҳар бир ўзгариш орқага қайтариш (down) скрипти билан.

## Синов тўлови (pay_test)

«🧪 Тестовая оплата» фақат **test** базада ишлайди: `app_settings.pay_test_mode = 'true'` **ва** `app_settings.app_env = 'test'` (28-миграция).
`app_env` ни фақат test базада `supabase/ops/mark_test_env.sql` билан қўйинг. Prod базада `app_env` бўлмаса синов тўлови ёпиқ.
