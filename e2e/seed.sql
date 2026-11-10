-- e2e синов маълумоти (фақат CI/маҳаллий бўш база). Ҳақиқий маълумот эмас.
-- Харидор «Telegram орқали кирган» деб ҳисобланади: унинг қурилмаси (uid) профилга аввалдан боғланган.
-- uid gateway.mjs даги E2E_UID билан бир хил бўлиши керак.
begin;
insert into public.app_settings (key, value) values
  ('payments_on', 'true'), ('pay_test_mode', 'true'), ('app_env', 'test'), ('require_login', 'true'), ('reserve_pct', '5'),
  ('orders_per_hour', '1000')   -- маҳаллий қайта-қайта ишга туширишда «too_many» бўлмасин
on conflict (key) do update set value = excluded.value;

insert into public.markets (id, name, name_uz, sort) overriding system value values (901, 'E2E бозор', 'E2E bozor', 1);
insert into public.sellers (id, name, role, status, shop, market_id) overriding system value values
  (9001, 'E2E дўкон 1', 'seller', 'active', 'E2E-1', 901),
  (9002, 'E2E дўкон 2', 'seller', 'active', 'E2E-2', 901);
-- 200 «Бетон М200», 201 «Щебень» (catalog.js ва seed_catalog_from_js.sql дан). Энг арзон: 200 → дўкон 2, 201 → дўкон 1.
insert into public.offers (seller_id, product_id, price) values (9001, 200, 700000), (9002, 200, 690000), (9001, 201, 15000);
-- Дўкон кабинети (seller-import.spec): 204 «Пескобетон» нинг бозор нархи (дўкон 2) — файлдаги 10 баравар қимматни огоҳлантириш учун.
insert into public.offers (seller_id, product_id, price) values (9002, 204, 100000);

insert into auth.users (id) values ('00000000-0000-4000-8000-00000000e2e0');
insert into public.profiles (id, name, phone) overriding system value values (9001, 'E2E Харидор', '+998901112233');
insert into public.profile_devices (profile_id, uid) values (9001, '00000000-0000-4000-8000-00000000e2e0');
commit;
