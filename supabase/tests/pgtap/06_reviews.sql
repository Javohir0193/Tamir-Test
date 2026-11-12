-- Дўкон ва товар баҳолари (32-миграция): фақат буюртма эгаси, фақат етказилган ва бекор қилинмаган буюртма, муддат,
-- буюртмада бор дўкон/товар, ўз дўконига эмас, ҳавола/телефонли матн текширувга, админ яширгани яширин қолади. Охирида rollback.
begin;
\ir 00_helpers.sql
select plan(43);

create temp table t (k text primary key, v text);
do $$
declare mk int; s1 bigint; s2 bigint; s3 bigint; pa int; pb int; pc int; pid bigint; pid2 bigint;
        u uuid := gen_random_uuid(); u2 uuid := gen_random_uuid(); o1 bigint; o2 bigint; o3 bigint; o4 bigint; o5 bigint;
begin
  insert into public.markets (name) values ('REV market') returning id into mk;
  insert into public.sellers (name, role, status, shop, market_id, tg_chat_id) values ('REV1', 'seller', 'active', 'REV1', mk, 7800001) returning id into s1;
  insert into public.sellers (name, role, status, shop, market_id, tg_chat_id) values ('REV2', 'seller', 'active', 'REV2', mk, 7800002) returning id into s2;
  insert into public.sellers (name, role, status, shop, market_id) values ('REV3', 'seller', 'active', 'REV3', mk) returning id into s3;
  select min(id) into pa from public.products where active;
  select min(id) into pb from public.products where active and id > pa;
  select min(id) into pc from public.products where active and id > pb;
  insert into auth.users (id) values (u), (u2);
  insert into public.profiles (name, phone, tg_id) values ('Ali Valiyev', '+998901110000', 7800002) returning id into pid;
  insert into public.profiles (name, phone) values ('Begona', '+998902220000') returning id into pid2;
  insert into public.profile_devices (profile_id, uid) values (pid, u), (pid2, u2);
  -- o1: олиб кетиш, етказилган (3-босқич), иккита дўкон; o2: ҳали йиғилмоқда; o3: бекор; o4: 40 кун олдин қабул қилинган
  insert into public.orders (user_id, customer_name, phone, items, mode, total, stage, profile_id, market_id)
       values (u, 'Ali', '+998901110000', '[]', 'pickup', 100, 3, pid, mk) returning no into o1;
  insert into public.orders (user_id, customer_name, phone, items, mode, total, stage, profile_id, market_id)
       values (u, 'Ali', '+998901110000', '[]', 'pickup', 100, 1, pid, mk) returning no into o2;
  insert into public.orders (user_id, customer_name, phone, items, mode, total, stage, profile_id, market_id, cancelled_at)
       values (u, 'Ali', '+998901110000', '[]', 'pickup', 100, 3, pid, mk, now()) returning no into o3;
  insert into public.orders (user_id, customer_name, phone, items, mode, total, stage, profile_id, market_id, received_at)
       values (u, 'Ali', '+998901110000', '[]', 'delivery', 100, 4, pid, mk, now() - interval '40 days') returning no into o4;
  insert into public.orders (user_id, customer_name, phone, items, mode, total, stage, profile_id, market_id)
       values (u, 'Ali', '+998901110000', '[]', 'delivery', 100, 3, pid, mk) returning no into o5;   -- етказишда 3 = йўлда
  insert into public.order_lines (order_no, line_no, name, qty, product_id, seller_id) values
    (o1, 1, 'A', 1, pa, s1), (o1, 2, 'B', 1, pb, s2), (o2, 1, 'A', 1, pa, s1), (o3, 1, 'A', 1, pa, s1), (o4, 1, 'A', 1, pa, s1), (o5, 1, 'A', 1, pa, s1);
  insert into t values ('s1', s1), ('s2', s2), ('s3', s3), ('pa', pa), ('pb', pb), ('pc', pc), ('u', u), ('u2', u2),
                       ('o1', o1), ('o2', o2), ('o3', o3), ('o4', o4), ('o5', o5);
end $$;
create function pg_temp.v(k text) returns text language sql as $$ select v from t where t.k = $1 $$;
create function pg_temp.save(p_uid uuid, p_no text, p_items jsonb) returns jsonb language sql as $$
  select pg_temp.as_user(p_uid, format('select public.review_save(%s, %L::jsonb)', pg_temp.v(p_no), p_items)) $$;
create function pg_temp.item(kind text, k text, r numeric, body text default '') returns jsonb language sql as $$
  select jsonb_build_array(jsonb_build_object('kind', kind, 'id', pg_temp.v(k)::bigint, 'rating', r, 'body', body)) $$;
create function pg_temp.summary() returns jsonb language sql as $$ select pg_temp.as_anon('select public.ratings_summary()') $$;

-- 1) Ҳуқуқлар
select ok(    has_function_privilege('authenticated', 'public.review_save(bigint,jsonb)', 'execute'), 'review_save: кирган харидор');
select ok(not has_function_privilege('anon',          'public.review_save(bigint,jsonb)', 'execute'), 'review_save: anon эмас');
select ok(not has_function_privilege('anon',          'public.review_targets(bigint)', 'execute'), 'review_targets: anon эмас');
select ok(    has_function_privilege('anon',          'public.ratings_summary()', 'execute'), 'ratings_summary: очиқ');
select ok(    has_function_privilege('anon',          'public.shop_reviews(bigint,integer)', 'execute'), 'shop_reviews: очиқ');
select ok(not has_function_privilege('authenticated', 'public.review_moderate(bigint,text,text,text)', 'execute'), 'review_moderate: сайтга ёпиқ');
select ok(not has_function_privilege('authenticated', 'public.seller_reviews(bigint)', 'execute'), 'seller_reviews: сайтга ёпиқ');
select ok(    has_function_privilege('service_role',  'public.seller_reviews(bigint)', 'execute'), 'seller_reviews: бот чақира олади');
select ok(not has_function_privilege('anon',          'public.admin_review_set(text,bigint,text,text)', 'execute'), 'admin_review_set: anon эмас');
select ok(not has_table_privilege('authenticated', 'public.reviews', 'select'), 'reviews жадвали тўғридан-тўғри ёпиқ');
select throws_ok($$ select public.admin_reviews('x') $$, '42501', null, 'admin_reviews: админ сессиясиз ишламайди');

-- 2) Ким ва қачон баҳолай олади
select is(pg_temp.as_user(pg_temp.v('u')::uuid, format('select public.review_targets(%s)', pg_temp.v('o1'))) ->> 'why', '', 'етказилган буюртма: баҳолаш мумкин');
select is(jsonb_array_length(pg_temp.as_user(pg_temp.v('u')::uuid, format('select public.review_targets(%s)', pg_temp.v('o1'))) -> 'shops'), 2, 'буюртмадаги 2 дўкон');
select is(jsonb_array_length(pg_temp.as_user(pg_temp.v('u')::uuid, format('select public.review_targets(%s)', pg_temp.v('o1'))) -> 'products'), 2, 'буюртмадаги 2 товар');
select throws_ok(format($$ select pg_temp.as_user(%L, 'select public.review_targets(%s)') $$, pg_temp.v('u2'), pg_temp.v('o1')), 'P0001', 'not_found', 'бегона буюртмани кўра олмайди');
select throws_ok(format($$ select pg_temp.as_user(null, 'select public.review_targets(%s)') $$, pg_temp.v('o1')), '42501', 'login_required', 'кирмаган');
select throws_ok($$ select pg_temp.save(pg_temp.v('u2')::uuid, 'o1', pg_temp.item('shop', 's1', 5)) $$, 'P0001', 'not_found', 'бегона буюртмага баҳо йўқ');
select throws_ok($$ select pg_temp.save(pg_temp.v('u')::uuid, 'o2', pg_temp.item('shop', 's1', 5)) $$, 'P0001', 'not_delivered', 'етказилмаган буюртма');
select throws_ok($$ select pg_temp.save(pg_temp.v('u')::uuid, 'o5', pg_temp.item('shop', 's1', 5)) $$, 'P0001', 'not_delivered', 'етказишда 3-босқич (йўлда) ҳали эмас');
select throws_ok($$ select pg_temp.save(pg_temp.v('u')::uuid, 'o3', pg_temp.item('shop', 's1', 5)) $$, 'P0001', 'cancelled', 'бекор қилинган буюртма');
select throws_ok($$ select pg_temp.save(pg_temp.v('u')::uuid, 'o4', pg_temp.item('shop', 's1', 5)) $$, 'P0001', 'too_late', '30 кундан кейин');

-- 3) Текширувлар
select throws_ok($$ select pg_temp.save(pg_temp.v('u')::uuid, 'o1', pg_temp.item('shop', 's1', 6)) $$, 'P0001', 'bad_value', '6 юлдуз йўқ');
select throws_ok($$ select pg_temp.save(pg_temp.v('u')::uuid, 'o1', pg_temp.item('shop', 's1', 4.5)) $$, 'P0001', 'bad_value', 'каср баҳо йўқ');
select throws_ok($$ select pg_temp.save(pg_temp.v('u')::uuid, 'o1', pg_temp.item('shop', 's3', 5)) $$, 'P0001', 'not_in_order', 'буюртмада йўқ дўкон');
select throws_ok($$ select pg_temp.save(pg_temp.v('u')::uuid, 'o1', pg_temp.item('product', 'pc', 5)) $$, 'P0001', 'not_in_order', 'буюртмада йўқ товар');
select throws_ok($$ select pg_temp.save(pg_temp.v('u')::uuid, 'o1', pg_temp.item('shop', 's2', 5)) $$, 'P0001', 'own_shop', 'ўз дўконига баҳо қўйиб бўлмайди (Telegram бир хил)');

-- 4) Сақлаш ва ўртача баҳо
select is(pg_temp.save(pg_temp.v('u')::uuid, 'o1', pg_temp.item('shop', 's1', 5, 'Зўр, тез тайёрлади') || pg_temp.item('product', 'pa', 4)) ->> 'saved', '2', 'дўкон ва товар баҳоси сақланди');
select is(pg_temp.summary() -> 's' -> pg_temp.v('s1'), '[5.0, 1]'::jsonb, 'дўкон ўртача баҳоси очиқ');
select is(pg_temp.summary() -> 'p' -> pg_temp.v('pa'), '[4.0, 1]'::jsonb, 'товар ўртача баҳоси очиқ');
select lives_ok($$ select pg_temp.save(pg_temp.v('u')::uuid, 'o1', pg_temp.item('shop', 's1', 3, 'Ўртача')) $$, 'баҳони ўзгартириш мумкин');
select is((select count(*)::int from public.reviews where order_no = pg_temp.v('o1')::bigint and seller_id = pg_temp.v('s1')::bigint), 1, 'қайта ёзилганда иккинчи қатор пайдо бўлмайди');
select is(pg_temp.as_anon(format('select public.shop_reviews(%s)', pg_temp.v('s1'))) -> 'items' -> 0 ->> 'name', 'Ali V.', 'исм қисқа (фамилия ва телефон йўқ)');

-- 5) Ҳавола ёки телефонли матн текширувга
select lives_ok($$ select pg_temp.save(pg_temp.v('u')::uuid, 'o1', pg_temp.item('product', 'pb', 1, 'Арзонроғи бор: +998 90 123-45-67')) $$, 'телефонли шарҳ қабул қилинди');
select is((select status from public.reviews where order_no = pg_temp.v('o1')::bigint and product_id = pg_temp.v('pb')::int), 'pending', 'телефонли шарҳ админ кўргунча яширин');
select ok(pg_temp.summary() -> 'p' -> pg_temp.v('pb') is null, 'яширин шарҳ ўртачага кирмайди');

-- 6) Модерация
select throws_ok($$ select public.review_moderate((select id from public.reviews where seller_id = pg_temp.v('s1')::bigint), 'hidden', '', 'test') $$,
                 'P0001', 'reason_required', 'яширишда сабаб шарт');
select lives_ok($$ select public.review_moderate((select id from public.reviews where seller_id = pg_temp.v('s1')::bigint), 'hidden', 'Ҳақорат', 'test') $$, 'админ яширди');
select lives_ok($$ select pg_temp.save(pg_temp.v('u')::uuid, 'o1', pg_temp.item('shop', 's1', 5, 'Қайта ёздим')) $$, 'харидор қайта ёзди');
select is((select status from public.reviews where seller_id = pg_temp.v('s1')::bigint), 'hidden', 'админ яширгани қайта ёзилса ҳам яширин қолади');

-- 7) Матн текшируви: оддий матн ўтади, ҳавола/username/телефон ушланади, нарх ушланмайди
select ok(not public.review_needs_check('Цемент сифатли, 12 500 000 сўмга олдим'), 'оддий матн ва нарх — текширувсиз');
select ok(public.review_needs_check('Каналимиз t.me/arzon_qurilish'), 't.me ҳавола — текширувга');
select ok(public.review_needs_check('Ёзинг @arzon_dokon'), '@username — текширувга');
select ok(public.review_needs_check('сайт: arzon.uz'), 'домен — текширувга');

select * from finish();
rollback;
