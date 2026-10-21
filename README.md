# Ta'mir

Қурилиш бозоридан материалларни буюртма қилиш ва етказиб бериш хизмати.

## Иловалар

| Саҳифа | Ким учун |
|---|---|
| `index.html` | Харидор: каталог, ҳисоблагич, сават, буюртма, тўлов |
| `admin.html` | Админ панел (Telegram орқали кириш + шахсий PIN) |
| `collector.html` | Бозордаги йиғувчи (Telegram WebApp) |
| `driver.html` | Ҳайдовчи |
| `seller.html` | Дўкон: нарх ва қолдиқ (@tamir_sotuvchi_bot ичида очилади) |

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

## Ишлаш тартиби

1. Ҳар бир ўзгариш алоҳида шохчада ва PR орқали.
2. Аввал test сайтда текширилади, кейин prod.
3. Базадаги ҳар бир ўзгариш орқага қайтариш (down) скрипти билан.
