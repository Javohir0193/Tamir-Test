-- Асосий оқим: кирган харидор буюртма беради → сумма серверда ҳисобланади → «Тестовая оплата» → тўланди.
-- Ҳаммаси битта транзакцияда, охирида rollback (ledger ва payments ўчирилмайди, шунинг учун бошқа йўл йўқ).
begin;
\ir 00_helpers.sql
\ir ../fixtures/fees.sql
select plan(24);

-- Синов маълумоти: бозор, 2 дўкон, 2 товар, кирган харидор (профиль + қурилма) ва бегона харидор
create temp table t (k text primary key, v text);
grant select on t to authenticated;   -- as_user ичидан ўқиш учун (фақат шу транзакцияда)
do $$
declare mk int; s1 bigint; s2 bigint; pa int; pb int; pid bigint; u uuid := gen_random_uuid(); u2 uuid := gen_random_uuid();
begin
  insert into public.app_settings (key, value) values ('payments_on', 'true'), ('pay_test_mode', 'true'), ('app_env', 'test'),
         ('require_login', 'true'), ('reserve_pct', '5')
    on conflict (key) do update set value = excluded.value;
  insert into public.markets (name) values ('TAP market') returning id into mk;
  insert into public.sellers (name, role, status, shop, market_id) values ('TAP1', 'seller', 'active', 'TAP1', mk) returning id into s1;
  insert into public.sellers (name, role, status, shop, market_id) values ('TAP2', 'seller', 'active', 'TAP2', mk) returning id into s2;
  select min(id) into pa from public.products where active; select max(id) into pb from public.products where active;
  insert into public.offers (seller_id, product_id, price) values (s1, pa, 150000), (s1, pb, 90000), (s2, pa, 120000);
  insert into auth.users (id) values (u), (u2);
  insert into public.profiles (name, phone) values ('TAP харидор', '+998901234567') returning id into pid;
  insert into public.profile_devices (profile_id, uid) values (pid, u);
  insert into t values ('mk', mk), ('pa', pa), ('pb', pb), ('u', u), ('u2', u2), ('s2', s2);
end $$;

create function pg_temp.v(k text) returns text language sql as $$ select v from t where t.k = $1 $$;
create function pg_temp.order_json(extra jsonb default '{}') returns text language sql as $$
  select (jsonb_build_object('mode', 'pickup', 'market_id', pg_temp.v('mk')::int, 'name', 'TAP', 'phone', '+998 90 123 45 67',
          'items', jsonb_build_array(jsonb_build_object('id', pg_temp.v('pa')::int, 'q', 2), jsonb_build_object('id', pg_temp.v('pb')::int, 'q', 1)))
          || extra)::text
$$;
create function pg_temp.create_as(p_uid uuid, p jsonb) returns jsonb language sql as $$
  select pg_temp.as_user(p_uid, format('select to_jsonb(public.create_order(%L::jsonb))', p))
$$;

-- 1) Кириш шарти
select throws_ok(format($$ select pg_temp.create_as(null, %L) $$, pg_temp.order_json()), '28000', 'no_session', 'сессиясиз буюртма йўқ');
select throws_ok(format($$ select pg_temp.create_as(%L, %L) $$, pg_temp.v('u2'), pg_temp.order_json()), '28000', 'login_required', 'Telegram орқали кирмаган буюртма бера олмайди');

-- 2) Текширувлар (хабар матни сайтдаги ORDER_ERR калитлари билан бир хил)
select throws_ok(format($$ select pg_temp.create_as(%L, %L) $$, pg_temp.v('u'), pg_temp.order_json('{"items": []}')), 'P0001', 'empty_cart', 'бўш сават');
select throws_ok(format($$ select pg_temp.create_as(%L, %L) $$, pg_temp.v('u'), pg_temp.order_json('{"phone": "123"}')), 'P0001', 'phone_required', 'телефонсиз');
select throws_ok(format($$ select pg_temp.create_as(%L, %L) $$, pg_temp.v('u'), pg_temp.order_json('{"name": "  "}')), 'P0001', 'name_required', 'исмсиз');
select throws_ok(format($$ select pg_temp.create_as(%L, %L) $$, pg_temp.v('u'), pg_temp.order_json('{"market_id": null}')), 'P0001', 'market_required', 'бозорсиз');
select throws_ok(format($$ select pg_temp.create_as(%L, %L) $$, pg_temp.v('u'), pg_temp.order_json('{"mode": "delivery"}')), 'P0001', 'address_required', 'етказишда манзилсиз');
select throws_ok(format($$ select pg_temp.create_as(%L, %L) $$, pg_temp.v('u'),
  pg_temp.order_json('{"items": [{"id": -1, "q": 1}]}')), 'P0001', 'unknown_product -1', 'каталогда йўқ товар');

-- 3) Тўғри буюртма: нархни сервер ҳисоблайди, харидор юборган «price» эътиборга олинмайди
select lives_ok(format($$ insert into t select 'o1', pg_temp.create_as(%L, %L)::text $$, pg_temp.v('u'),
  pg_temp.order_json(jsonb_build_object('items', jsonb_build_array(
    jsonb_build_object('id', pg_temp.v('pa')::int, 'q', 2, 'price', 1),
    jsonb_build_object('id', pg_temp.v('pb')::int, 'q', 1, 'price', 1))))), 'кирган харидор буюртма бера олади');
create function pg_temp.o1() returns jsonb language sql as $$ select v::jsonb from t where k = 'o1' $$;
select is((pg_temp.o1()->>'goods_sum')::bigint, 2 * 120000 + 90000::bigint, 'товарлар суммаси: энг арзон дўкон нархи × миқдор (харидор нархи эмас)');
select is(pg_temp.o1()->>'pay_status', 'unpaid', 'payments_on: буюртма тўлов кутмоқда');
select is((pg_temp.o1()->>'pay_amount')::bigint, (pg_temp.o1()->>'total')::bigint + round((pg_temp.o1()->>'goods_sum')::numeric * 5 / 100)::bigint,
          'тўлов суммаси = жами + 5% нарх запаси');
select ok((pg_temp.o1()->>'pay_due')::timestamptz > now(), 'тўлов муддати келажакда');
select is(pg_temp.o1()->>'phone', '+998 90 123 45 67', 'телефон сақланди');

-- 4) Кўриниш (RLS): ўзиники кўринади, бегонага кўринмайди
select is(pg_temp.as_user(pg_temp.v('u')::uuid, format('select count(*)::text::jsonb from public.orders where no = %s', pg_temp.o1()->>'no')), '1'::jsonb, 'эгаси ўз буюртмасини кўради');
select is(pg_temp.as_user(pg_temp.v('u2')::uuid, format('select count(*)::text::jsonb from public.orders where no = %s', pg_temp.o1()->>'no')), '0'::jsonb, 'бегона буюртмани кўрмайди');

-- 5) Бегона «Тестовая оплата» қила олмайди
select is(pg_temp.as_user(pg_temp.v('u2')::uuid, format('select public.pay_test(%s)', pg_temp.o1()->>'no'))->>'error', 'not_found', 'бегона буюртмасини тўлай олмайди');
select is((select pay_status from public.orders where no = (pg_temp.o1()->>'no')::bigint), 'unpaid', '... ва буюртма тўланмаган бўлиб қолди');

-- 6) «Тестовая оплата»: эгаси тўлайди
select is(pg_temp.as_user(pg_temp.v('u')::uuid, format('select public.pay_test(%s)', pg_temp.o1()->>'no'))->>'ok', 'true', 'pay_test: ok');
select is((select pay_status from public.orders where no = (pg_temp.o1()->>'no')::bigint), 'paid', 'буюртма тўланди');
select is((select count(*)::int from public.payments where order_no = (pg_temp.o1()->>'no')::bigint and provider = 'test'), 1, 'payments: битта «test» ёзуви');
select is((select amount from public.payments where order_no = (pg_temp.o1()->>'no')::bigint), (pg_temp.o1()->>'pay_amount')::bigint, 'тўланган сумма = pay_amount');

-- 7) Иккинчи марта тўлаб бўлмайди
select isnt(pg_temp.as_user(pg_temp.v('u')::uuid, format('select public.pay_test(%s)', pg_temp.o1()->>'no'))->>'ok', 'true', 'қайта тўлов ўтмайди');
select is((select count(*)::int from public.payments where order_no = (pg_temp.o1()->>'no')::bigint and status <> 'cancelled'), 1, '... ва иккинчи тўлов ёзилмади');

select * from finish();
rollback;
