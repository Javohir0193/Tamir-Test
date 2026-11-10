-- Дўкон нархлари (29-миграция): seller_offers_save битта транзакцияда ёзади, нарх тарихига тушади,
-- рад этилган / йўқ товар ва нотўғри нарх ўтказиб юборилади; seller_offers_check бозор медианасидан фарқни кўрсатади.
-- Иккаласи фақат серверга (бот, service_role): сайт ва харидор чақира олмайди. Охирида rollback.
begin;
\ir 00_helpers.sql
select plan(24);

create temp table t (k text primary key, v text);
do $$
declare s1 bigint; s2 bigint; s3 bigint; pa int; pb int; pr int; pn int;
begin
  insert into public.app_settings (key, value) values ('price_dev_pct', '30') on conflict (key) do update set value = excluded.value;
  insert into public.sellers (name, role, status, shop) values ('IMP1', 'seller', 'active', 'IMP1') returning id into s1;
  insert into public.sellers (name, role, status, shop) values ('IMP2', 'seller', 'active', 'IMP2') returning id into s2;
  insert into public.sellers (name, role, status, shop) values ('IMP3', 'seller', 'blocked', 'IMP3') returning id into s3;
  select min(id) into pa from public.products where active; select max(id) into pb from public.products where active;
  insert into public.products (id, cat, name, unit, active, reviewed_at) values (990001, 'mix', 'IMP рад этилган', 'дона', false, now()) returning id into pr;
  insert into public.products (id, cat, name, unit, active) values (990002, 'mix', 'IMP таклиф', 'дона', false) returning id into pn;
  insert into public.offers (seller_id, product_id, price) values (s2, pa, 100000), (s1, pb, 5000);
  insert into t values ('s1', s1), ('s2', s2), ('s3', s3), ('pa', pa), ('pb', pb), ('pr', pr), ('pn', pn);
end $$;
create function pg_temp.v(k text) returns text language sql as $$ select v from t where t.k = $1 $$;
create function pg_temp.save(rows jsonb, src text default 'seller') returns jsonb language sql as $$
  select public.seller_offers_save(pg_temp.v('s1')::bigint, rows, src) $$;

-- 1) Ҳуқуқлар: фақат service_role
select ok(not has_function_privilege('anon',          'public.seller_offers_save(bigint,jsonb,text)', 'execute'), 'save: anon чақира олмайди');
select ok(not has_function_privilege('authenticated', 'public.seller_offers_save(bigint,jsonb,text)', 'execute'), 'save: authenticated чақира олмайди');
select ok(    has_function_privilege('service_role',  'public.seller_offers_save(bigint,jsonb,text)', 'execute'), 'save: бот (service_role) чақира олади');
select ok(not has_function_privilege('authenticated', 'public.seller_offers_check(bigint,jsonb)', 'execute'), 'check: authenticated чақира олмайди');
select ok(    has_function_privilege('service_role',  'public.seller_offers_check(bigint,jsonb)', 'execute'), 'check: бот чақира олади');

-- 2) Текшириш: бозор медианаси 100 000, 30% дан ортиқ фарқ — warn
select is((public.seller_offers_check(pg_temp.v('s1')::bigint, format('[{"product_id": %s, "price": 105000}]', pg_temp.v('pa'))::jsonb)) -> 0 ->> 'st', 'ok', 'check: медианага яқин нарх — ok');
select is((public.seller_offers_check(pg_temp.v('s1')::bigint, format('[{"product_id": %s, "price": 1000000}]', pg_temp.v('pa'))::jsonb)) -> 0 ->> 'st', 'warn', 'check: 10 баравар қиммат — warn');
select is((public.seller_offers_check(pg_temp.v('s1')::bigint, format('[{"product_id": %s, "price": 1000000}]', pg_temp.v('pa'))::jsonb)) -> 0 ->> 'dev', '900.0', 'check: фарқ фоизи');
select is((public.seller_offers_check(pg_temp.v('s1')::bigint, format('[{"product_id": %s, "price": 5000}]', pg_temp.v('pr'))::jsonb)) -> 0 ->> 'st', 'err_product', 'check: рад этилган товар — err_product');
select is((public.seller_offers_check(pg_temp.v('s1')::bigint, format('[{"product_id": %s, "price": "abc"}]', pg_temp.v('pa'))::jsonb)) -> 0 ->> 'st', 'err_price', 'check: нотўғри нарх — err_price');
select is((select count(*)::int from public.offers where seller_id = pg_temp.v('s1')::bigint and product_id = pg_temp.v('pa')::int), 0, 'check ҳеч нарса ёзмайди');

-- 3) Сақлаш: тўғри қаторлар ёзилади, нотўғрилари ўтказилади, дубликатда охиргиси олинади
select is(pg_temp.save(format('[{"product_id": %1$s, "price": 90000}, {"product_id": %1$s, "price": 95000, "in_stock": false, "src": "file"},
                               {"product_id": %2$s, "price": 7000}, {"product_id": %3$s, "price": 100}, {"product_id": %4$s, "price": 300},
                               {"product_id": 999999999, "price": 100}, {"product_id": "x", "price": 100}]',
                       pg_temp.v('pa'), pg_temp.v('pb'), pg_temp.v('pr'), pg_temp.v('pn'))::jsonb),
          '{"saved": 3, "removed": 0, "skipped": 2}'::jsonb, 'save: 3 сақланди (таклиф ҳам), рад этилган ва йўқ товар ўтказилди');
select is((select price from public.offers where seller_id = pg_temp.v('s1')::bigint and product_id = pg_temp.v('pa')::int), 95000::bigint, 'save: дубликатда охирги қатор');
select is((select in_stock from public.offers where seller_id = pg_temp.v('s1')::bigint and product_id = pg_temp.v('pa')::int), false, 'save: in_stock = false сақланди');
select is((select count(*)::int from public.offers where seller_id = pg_temp.v('s1')::bigint and product_id = pg_temp.v('pr')::int), 0, 'save: рад этилган товарга нарх йўқ');

-- 4) Нарх тарихи: манба ва эски нарх
select is((select source from public.price_history where seller_id = pg_temp.v('s1')::bigint and product_id = pg_temp.v('pa')::int order by id desc limit 1), 'seller_file', 'тарих: файлдан келган — seller_file');
select is((select old_price from public.price_history where seller_id = pg_temp.v('s1')::bigint and product_id = pg_temp.v('pb')::int order by id desc limit 1), 5000::bigint, 'тарих: эски нарх ёзилди');
select is(pg_temp.save(format('[{"product_id": %s, "price": 7000}]', pg_temp.v('pb'))::jsonb) ->> 'saved', '1', 'save: ўзгармаган нарх ҳам сақланади');
select is((select count(*)::int from public.price_history where seller_id = pg_temp.v('s1')::bigint and product_id = pg_temp.v('pb')::int), 1, 'тарих: нарх ўзгармаса янги ёзув йўқ');

-- 5) 0 — нархни ўчириш (ботдаги «save» билан бир хил)
select is(pg_temp.save(format('[{"product_id": %s, "price": 0}]', pg_temp.v('pb'))::jsonb) ->> 'removed', '1', 'save: нарх 0 — ўчирилди');

-- 6) Кириш шартлари
select throws_ok(format($$ select public.seller_offers_save(%s, '[]'::jsonb) $$, pg_temp.v('s3')), 'P0001', 'unknown_key', 'блокланган дўкон ёза олмайди');
select throws_ok($$ select pg_temp.save('{"a": 1}'::jsonb) $$, 'P0001', 'bad_value', 'массив эмас — bad_value');
select throws_ok($$ select pg_temp.save('[]'::jsonb, 'admin') $$, 'P0001', 'bad_value', 'манба фақат seller / seller_file');
select throws_ok($$ select pg_temp.save((select jsonb_agg(jsonb_build_object('product_id', 1, 'price', 1)) from generate_series(1, 2001))) $$, 'P0001', 'too_many_rows', '2000 дан ортиқ қатор йўқ');

select * from finish();
rollback;
