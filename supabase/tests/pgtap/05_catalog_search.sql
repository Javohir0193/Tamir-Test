-- Каталог қидируви (31-миграция): ҳар сўз алоҳида, кирилл/лотин, хато ёзилган сўз, тоифа, бозор, нарх бўйича тартиб.
-- search_products (эски) ўзгармаган. Охирида rollback.
begin;
\ir 00_helpers.sql
select plan(16);

create temp table t (k text primary key, v text);
grant select on t to anon;
do $$
declare ma int; mb int; s1 bigint; s2 bigint; c1 text; c2 text;
begin
  select id into c1 from public.categories order by sort, id limit 1;
  select id into c2 from public.categories order by sort desc, id desc limit 1;
  insert into public.markets (name) values ('SRCH A') returning id into ma;
  insert into public.markets (name) values ('SRCH B') returning id into mb;
  insert into public.sellers (name, role, status, shop, market_id) values ('SRCH1', 'seller', 'active', 'SRCH1', ma) returning id into s1;
  insert into public.sellers (name, role, status, shop, market_id) values ('SRCH2', 'seller', 'active', 'SRCH2', mb) returning id into s2;
  insert into public.products (id, cat, name, spec, unit, base_price) values
    (980001, c1, 'Цемент М400 Зиёкор', 'мешок 50 кг', 'мешок', 70000),
    (980002, c1, 'Цемент М500 Зиёкор', 'мешок 50 кг', 'мешок', 80000),
    (980003, c2, 'Зиёкор цемент клей', 'мешок 25 кг', 'мешок', 50000);
  insert into public.products (id, cat, name, spec, unit, active) values (980004, c1, 'Цемент М400 Зиёкор эски', '', 'мешок', false);
  insert into public.offers (seller_id, product_id, price) values (s1, 980001, 65000), (s2, 980001, 60000), (s1, 980002, 75000), (s2, 980003, 52000);
  insert into t values ('ma', ma), ('mb', mb), ('c1', c1), ('c2', c2);
end $$;
create function pg_temp.v(k text) returns text language sql as $$ select v from t where t.k = $1 $$;
create function pg_temp.ids(q text, cat text default null, mk int default null, srt text default 'rel') returns int[] language sql as $$
  select coalesce(array_agg(id order by ord), '{}') from (select id, row_number() over () ord from public.catalog_search(q, cat, mk, srt, 50) where id >= 980000) x $$;

select has_function('public', 'catalog_search', array['text', 'text', 'integer', 'text', 'integer'], 'catalog_search бор');
select ok(has_function_privilege('anon', 'public.catalog_search(text,text,integer,text,integer)', 'execute'), 'anon қидира олади (каталог очиқ)');
select has_function('public', 'search_products', array['text', 'integer'], 'эски search_products қолган');
select lives_ok($$ select pg_temp.as_anon('select count(*)::text::jsonb from public.catalog_search(''цемент'')') $$, 'anon ролида ишлайди');

-- Сўзлар алоҳида: «цемент 400» → «Цемент М400» («м400» ичида «400»)
select is(pg_temp.ids('цемент 400'), array[980001], 'цемент 400 → Цемент М400');
select is((pg_temp.ids('зиёкор цемент'))[1], 980003, 'сўзлар кетма-кет келган товар биринчи');
select is(pg_temp.ids('ziyokor sement 500'), array[980002], 'лотинча, сўз тартиби бошқа');
select is(pg_temp.ids('semnt m400'), array[980001], 'хато ёзилган сўз (semnt)');
select is(pg_temp.ids('цемент кафель'), '{}'::int[], 'ҳамма сўз бўлиши шарт');
select ok(not (980004 = any(pg_temp.ids('цемент м400 зиёкор'))), 'нофаол товар чиқмайди');

-- Тоифа ва бозор
select is(pg_temp.ids('зиёкор', pg_temp.v('c2')), array[980003], 'тоифа фильтри');
select is(pg_temp.ids('зиёкор', null, pg_temp.v('ma')::int, 'price_asc'), array[980001, 980002], 'бозор A: фақат шу бозорда нархи борлари, арзонидан');
select is((select best_price from public.catalog_search('цемент 400', null, pg_temp.v('ma')::int) where id = 980001), 65000::bigint, 'бозор A нархи (бутун бозордаги 60 000 эмас)');
select is(pg_temp.ids('зиёкор', null, null, 'price_desc'), array[980002, 980001, 980003], 'нарх бўйича камайиш');

-- Чегаралар
select is(pg_temp.ids('ц'), '{}'::int[], '1 ҳарф — бўш');
select throws_ok($$ select * from public.catalog_search('цемент', null, null, 'x') $$, 'P0001', 'bad_value', 'нотўғри тартиб');

select * from finish();
rollback;
