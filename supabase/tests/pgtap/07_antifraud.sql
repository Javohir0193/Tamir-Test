-- Антифрод (33-миграция): ҳар қоида шубҳали ҳолатни белгилайди, оддий харидорни белгиламайди, бир ҳолат қайта белгиланмайди,
-- қарор сабаб билан, «фирибгар + блок» → buyurtma ва баҳо бериб бўлмайди, ҳуқуқлар. Охирида rollback.
begin;
\ir 00_helpers.sql
select plan(26);

create temp table t (k text primary key, v text);
do $$
declare mk int; s1 bigint; pa int; good bigint; fast bigint; payless bigint; whiner bigint; big bigint; dev bigint;
        ph1 bigint; ph2 bigint; ph3 bigint; u uuid := gen_random_uuid(); i int; o bigint;
begin
  delete from public.fraud_flags;
  insert into public.markets (name) values ('FR market') returning id into mk;
  insert into public.sellers (name, role, status, shop, market_id) values ('FR1', 'seller', 'active', 'FR1', mk) returning id into s1;
  select min(id) into pa from public.products where active;
  insert into auth.users (id) values (u);
  insert into public.profiles (name, phone) values ('Good', '+998901000001') returning id into good;
  insert into public.profiles (name, phone) values ('Fast', '+998901000002') returning id into fast;
  insert into public.profiles (name, phone) values ('Payless', '+998901000003') returning id into payless;
  insert into public.profiles (name, phone) values ('Whiner', '+998901000004') returning id into whiner;
  insert into public.profiles (name, phone) values ('Big', '+998901000005') returning id into big;
  insert into public.profiles (name, phone) values ('Dev', '+998901000006') returning id into dev;
  insert into public.profiles (name, phone) values ('Ph1', '+998901000007') returning id into ph1;
  insert into public.profiles (name, phone) values ('Ph2', '+998901000008') returning id into ph2;
  insert into public.profiles (name, phone) values ('Ph3', '+998901000009') returning id into ph3;
  -- оддий харидор: 2 та буюртма, тўланган
  insert into public.orders (user_id, customer_name, phone, items, mode, total, profile_id, market_id)
    select u, 'Good', '+998901000001', '[]', 'pickup', 100000, good, mk from generate_series(1, 2);
  update public.orders set pay_status = 'paid' where profile_id = good;
  -- velocity: 1 соатда 5 та
  insert into public.orders (user_id, customer_name, phone, items, mode, total, profile_id, market_id)
    select u, 'Fast', '+998901000002', '[]', 'pickup', 100000, fast, mk from generate_series(1, 5);
  update public.orders set pay_status = 'paid' where profile_id = fast;
  -- unpaid: 3 та муддати ўтган
  insert into public.orders (user_id, customer_name, phone, items, mode, total, profile_id, market_id)
    select u, 'Payless', '+998901000003', '[]', 'pickup', 100000, payless, mk from generate_series(1, 3);
  update public.orders set pay_status = 'expired' where profile_id = payless;
  -- complain: 3 марта «олмадим»
  insert into public.orders (user_id, customer_name, phone, items, mode, total, profile_id, market_id, received_at, received_ok, created_at)
    select u, 'Whiner', '+998901000004', '[]', 'delivery', 100000, whiner, mk, now() - interval '1 day', false, now() - interval '3 days' from generate_series(1, 3);
  update public.orders set pay_status = 'paid' where profile_id = whiner;
  -- bigfirst: биринчи буюртма 25 млн, тўланмаган
  insert into public.orders (user_id, customer_name, phone, items, mode, total, profile_id, market_id)
    values (u, 'Big', '+998901000005', '[]', 'pickup', 25000000, big, mk) returning no into o;
  insert into t values ('big_no', o);
  -- phone: бир телефон 3 профилда (бошқа қоидаларга тушмаслиги учун 2 кун олдин ва тўланган)
  insert into public.orders (user_id, customer_name, phone, items, mode, total, profile_id, market_id, created_at)
    values (u, 'Ph', '90 777 66 55', '[]', 'pickup', 100000, ph1, mk, now() - interval '2 days'),
           (u, 'Ph', '+998 (90) 777-66-55', '[]', 'pickup', 100000, ph2, mk, now() - interval '2 days'),
           (u, 'Ph', '998907776655', '[]', 'pickup', 100000, ph3, mk, now() - interval '2 days');
  update public.orders set pay_status = 'paid' where profile_id in (ph1, ph2, ph3);
  -- devices: 5 та янги қурилма
  for i in 1..5 loop insert into public.profile_devices (profile_id, uid) values (dev, gen_random_uuid()); end loop;
  insert into t values ('good', good), ('fast', fast), ('payless', payless), ('whiner', whiner), ('big', big), ('dev', dev), ('s1', s1), ('u', u), ('mk', mk);
end $$;
create function pg_temp.v(k text) returns text language sql as $$ select v from t where t.k = $1 $$;
create function pg_temp.has(p_rule text, p_profile text default null) returns boolean language sql as $$
  select exists (select 1 from public.fraud_flags where rule = p_rule and (p_profile is null or profile_id = pg_temp.v(p_profile)::bigint)) $$;

-- 1) Ҳуқуқлар
select ok(not has_function_privilege('authenticated', 'public.fraud_scan()', 'execute'), 'fraud_scan: сайтга ёпиқ');
select ok(not has_function_privilege('anon',          'public.fraud_scan()', 'execute'), 'fraud_scan: anon га ёпиқ');
select ok(not has_function_privilege('authenticated', 'public.fraud_decide(bigint,text,text,boolean,text)', 'execute'), 'fraud_decide: сайтга тўғридан-тўғри ёпиқ');
select ok(not has_function_privilege('anon',          'public.admin_fraud(text,text,integer)', 'execute'), 'admin_fraud: anon эмас');
select ok(not has_table_privilege('authenticated', 'public.fraud_flags', 'select'), 'fraud_flags жадвали ёпиқ');
select throws_ok($$ select public.admin_fraud('x') $$, '42501', null, 'admin_fraud: админ сессиясиз ишламайди');

-- 2) Қоидалар
select ok(public.fraud_scan() >= 6, 'сканер шубҳали ҳолатларни топди');
select ok(pg_temp.has('velocity', 'fast'), 'velocity: 1 соатда 5 буюртма');
select ok(pg_temp.has('unpaid', 'payless'), 'unpaid: 3 та тўланмаган');
select ok(pg_temp.has('complain', 'whiner'), 'complain: 3 марта «олмадим»');
select ok(pg_temp.has('bigfirst', 'big'), 'bigfirst: катта биринчи буюртма тўланмаган');
select ok(pg_temp.has('devices', 'dev'), 'devices: 24 соатда 5 қурилма');
select ok(exists (select 1 from public.fraud_flags where key = 'phone:907776655'), 'phone: ҳар хил ёзилган бир телефон 3 профилда');
select ok(not exists (select 1 from public.fraud_flags where profile_id = pg_temp.v('good')::bigint), 'оддий харидор белгиланмади');
select is(public.fraud_scan(), 0, 'қайта сканерлашда янги белги йўқ (такрорланмайди)');

-- 3) Баҳо портлаши
do $$
declare i int; p bigint; o bigint;
begin
  for i in 1..5 loop
    insert into public.profiles (name) values ('Rv' || i) returning id into p;
    insert into public.orders (user_id, customer_name, phone, items, mode, total, stage, profile_id, market_id, created_at)
      values (pg_temp.v('u')::uuid, 'Rv', '+99890100' || (1000 + i), '[]', 'pickup', 1, 3, p, pg_temp.v('mk')::int, now() - interval '5 days') returning no into o;
    insert into public.reviews (order_no, profile_id, seller_id, rating) values (o, p, pg_temp.v('s1')::bigint, 5);
  end loop;
end $$;
select is(public.fraud_scan(), 1, 'review_burst: дўконга 24 соатда 5 баҳо');
select ok(exists (select 1 from public.fraud_flags where rule = 'review_burst' and seller_id = pg_temp.v('s1')::bigint), 'белги дўконга боғланган');

-- 4) Қарор
create function pg_temp.fid(p_rule text) returns bigint language sql as $$ select id from public.fraud_flags where rule = p_rule order by id limit 1 $$;
select throws_ok($$ select public.fraud_decide(pg_temp.fid('unpaid'), 'fraud', '', true, 'test') $$, 'P0001', 'reason_required', 'фирибгар деб белгилашда сабаб шарт');
select throws_ok($$ select public.fraud_decide(pg_temp.fid('unpaid'), 'maybe', null, false, 'test') $$, 'P0001', 'bad_value', 'нотўғри қарор');
select is(public.fraud_decide(pg_temp.fid('devices'), 'ok', null, false, 'test') ->> 'blocked', 'false', '«асоссиз» — блок йўқ');
select is(public.fraud_decide(pg_temp.fid('unpaid'), 'fraud', 'Тўламайди, сохта буюртмалар', true, 'test') ->> 'blocked', 'true', '«фирибгар» + блок');
select ok((select 'blacklist' = any(tags) from public.profiles where id = pg_temp.v('payless')::bigint), 'профилга blacklist қўйилди');
select throws_ok($$ select public.fraud_decide(pg_temp.fid('unpaid'), 'ok', null, false, 'test') $$, 'P0001', 'already_decided', 'қарорни қайта ўзгартириб бўлмайди');

-- 5) Блокланган профил
select throws_ok($$ insert into public.orders (user_id, customer_name, phone, items, mode, total, profile_id)
                   values (pg_temp.v('u')::uuid, 'X', '+998901000003', '[]', 'pickup', 1, pg_temp.v('payless')::bigint) $$,
                 '42501', 'account_blocked', 'блокланган профил буюртма бера олмайди');
select lives_ok($$ insert into public.orders (user_id, customer_name, phone, items, mode, total, profile_id)
                   values (pg_temp.v('u')::uuid, 'X', '+998901000001', '[]', 'pickup', 1, pg_temp.v('good')::bigint) $$, 'оддий харидор бера олади');
select is((select count(*)::int from public.audit_log where action in ('fraud_ok', 'fraud_fraud')), 2, 'қарорлар аудит журналида');

select * from finish();
rollback;
