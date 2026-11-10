-- Товар таклифи ва модерацияси (30-миграция): id тўқнашмайди, дубликат кирилл/лотинда ҳам топилади, чекловлар,
-- рад этишда сабаб шарт ва нархлар ўчади, тасдиқлашда тузатиш, қайта ҳал қилиб бўлмайди, ҳуқуқлар. Охирида rollback.
begin;
\ir 00_helpers.sql
select plan(30);

create temp table t (k text primary key, v text);
do $$
declare s1 bigint; s2 bigint; c1 bigint; cat text;
begin
  insert into public.sellers (name, role, status, shop, tg_chat_id) values ('MOD1', 'seller', 'active', 'MOD1', 7700001) returning id into s1;
  insert into public.sellers (name, role, status, shop) values ('MOD2', 'seller', 'blocked', 'MOD2') returning id into s2;
  insert into public.sellers (name, role, status) values ('MODC', 'collector', 'active') returning id into c1;
  select id into cat from public.categories order by sort, id limit 1;
  insert into t values ('s1', s1), ('s2', s2), ('c1', c1), ('cat', cat);
end $$;
create function pg_temp.v(k text) returns text language sql as $$ select v from t where t.k = $1 $$;
create function pg_temp.prop(name text, spec text default '', price bigint default 0, who text default 's1') returns jsonb language sql as $$
  select public.product_propose(pg_temp.v(who)::bigint, null, name, spec, pg_temp.v('cat'), 'дона', price) $$;

-- 1) Ҳуқуқлар
select ok(not has_function_privilege('authenticated', 'public.product_propose(bigint,bigint,text,text,text,text,bigint)', 'execute'), 'propose: сайтга ёпиқ');
select ok(not has_function_privilege('anon',          'public.product_propose(bigint,bigint,text,text,text,text,bigint)', 'execute'), 'propose: anon га ёпиқ');
select ok(    has_function_privilege('service_role',  'public.product_propose(bigint,bigint,text,text,text,text,bigint)', 'execute'), 'propose: бот чақира олади');
select ok(not has_function_privilege('authenticated', 'public.product_decide(integer,boolean,text,jsonb,text)', 'execute'), 'decide: сайтга тўғридан-тўғри ёпиқ');
select ok(not has_function_privilege('authenticated', 'public.seller_proposals(bigint)', 'execute'), 'seller_proposals: сайтга ёпиқ');
select ok(    has_function_privilege('authenticated', 'public.admin_product_decide(text,integer,boolean,text,jsonb)', 'execute'), 'admin_product_decide (янги): панель чақиради (admin_check билан)');
select ok(not has_function_privilege('anon',          'public.admin_product_decide(text,integer,boolean,text,jsonb)', 'execute'), 'admin_product_decide (янги): anon эмас');
select has_function('public', 'admin_product_decide', array['text', 'integer', 'boolean'], 'эски 3 аргументли имзо сақланган');

-- 2) Таклиф: id 1000+, нофаол, нарх дўконга ёзилди
select ok((pg_temp.prop('Қум ювилган MOD', '1 м³', 45000) ->> 'id')::int >= 1000, 'таклиф id 1000 дан катта');
insert into t select 'p1', id from public.products where name = 'Қум ювилган MOD';
select is((select active from public.products where id = pg_temp.v('p1')::int), false, 'таклиф нофаол (каталогда кўринмайди)');
select is((select proposed_by from public.products where id = pg_temp.v('p1')::int), pg_temp.v('s1')::bigint, 'ким таклиф қилгани сақланди');
select is((select price from public.offers where seller_id = pg_temp.v('s1')::bigint and product_id = pg_temp.v('p1')::int), 45000::bigint, 'дўкон нархи ёзилди');
select isnt((pg_temp.prop('Қум ювилган MOD 2') ->> 'id')::int, pg_temp.v('p1')::int, 'кетма-кет таклифлар ҳар хил id');

-- 3) Дубликат: лотинда ёзилган кутилаётган таклиф ва каталогдаги товар
select throws_ok($$ select pg_temp.prop('Qum yuvilgan MOD', '1 м³') $$, 'P0001', 'duplicate_pending', 'лотинда ёзилган бир хил таклиф — duplicate_pending');
insert into t select 'act', name || ' ' || spec from public.products where active and id < 1000 order by id limit 1;
select throws_ok(format($$ select public.product_propose(%s, null, %L, '', %L, 'дона', 0) $$, pg_temp.v('s1'), upper(pg_temp.v('act')), pg_temp.v('cat')),
                 'P0001', 'duplicate', 'каталогда бор товар (катта ҳарфда ҳам) — duplicate');

-- 4) Текширувлар
select throws_ok($$ select public.product_propose(pg_temp.v('s1')::bigint, null, 'X MOD', '', 'yoq_toifa', 'дона', 0) $$, 'P0001', 'bad_category', 'йўқ тоифа');
select throws_ok($$ select pg_temp.prop('Нарх MOD', '', -5) $$, 'P0001', 'bad_price', 'манфий нарх');
select throws_ok($$ select pg_temp.prop('Блок MOD', '', 0, 's2') $$, 'P0001', 'unknown_key', 'блокланган дўкон таклиф қила олмайди');
select lives_ok($$ select pg_temp.prop('Йиғувчи MOD', '', 0, 'c1') $$, 'йиғувчи ҳам таклиф қила олади');
select throws_ok($$ select pg_temp.prop('Чеклов MOD ' || g) from generate_series(1, 20) g $$, 'P0001', 'too_many', 'дўконга 20 тадан ортиқ кутилаётган таклиф йўқ');

-- 5) Рад этиш: сабаб, нархлар ўчади, Telegram хабари навбатга
select throws_ok(format($$ select public.admin_product_decide('x', %s, false, '', null) $$, pg_temp.v('p1')), null, null, 'панель: сессиясиз ҳал қилиб бўлмайди');
select lives_ok(format($$ select public.product_decide(%s, false, 'Номи нотўғри', '{}', 'admin') $$, pg_temp.v('p1')), 'рад этилди');
select is((select reject_reason from public.products where id = pg_temp.v('p1')::int), 'Номи нотўғри', 'сабаб сақланди');
select is((select count(*)::int from public.offers where product_id = pg_temp.v('p1')::int), 0, 'рад этилган таклифнинг нархлари ўчди');
select throws_ok(format($$ select public.product_decide(%s, true, null, '{}', 'bot') $$, pg_temp.v('p1')), 'P0001', 'not_pending', 'ҳал қилинганини қайта ўзгартириб бўлмайди (бот ҳам)');
select is((select public.seller_proposals(pg_temp.v('s1')::bigint) -> -1 ->> 'st'), 'no', 'дўкон ўз таклифи ҳолатини кўради');

-- 6) Тасдиқлаш тузатиш билан
insert into t select 'p2', id from public.products where name = 'Қум ювилган MOD 2';
select is(public.product_decide(pg_temp.v('p2')::int, true, null, '{"name": "Қум (ювилган)", "unit": "м³"}', 'bot') ->> 'active', 'true', 'тасдиқланди');
select is((select name || '|' || unit from public.products where id = pg_temp.v('p2')::int), 'Қум (ювилган)|м³', 'тасдиқлашда номи ва ўлчови тузатилди');
select throws_ok(format($$ select public.product_decide(%s, true, null, '{"cat": "yoq"}', 'admin') $$, (pg_temp.prop('Тоифа MOD') ->> 'id')), 'P0001', 'bad_category', 'тузатишда йўқ тоифа');
select is((select count(*)::int from public.audit_log where object = 'product' and obj_id in (pg_temp.v('p1'), pg_temp.v('p2'))), 2, 'иккала қарор audit_log да');

select * from finish();
rollback;
