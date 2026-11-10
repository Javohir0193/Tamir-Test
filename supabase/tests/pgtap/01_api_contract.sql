-- API шартномаси: сайт ва бот чақирадиган функциялар бор, имзоси ўзгармаган, ҳуқуқлари тўғри.
-- Мақсад: миграция ишлаётган API'ни билмасдан бузиб қўймасин (лойиҳа қоидаси).
begin;
\ir 00_helpers.sql
select plan(35);

-- 1) Харидор сайти (index.html) чақирадиган функциялар ва имзолари
select has_function('public', 'create_order',     array['jsonb'],           'create_order(jsonb) бор');
select has_function('public', 'quote_order',      array['jsonb'],           'quote_order(jsonb) бор');
select has_function('public', 'cart_compare',     array['jsonb'],           'cart_compare(jsonb) бор');
select has_function('public', 'pay_options',      array['bigint'],          'pay_options(bigint) бор');
select has_function('public', 'pay_start',        array['bigint', 'text'],  'pay_start(bigint, text) бор');
select has_function('public', 'pay_test',         array['bigint'],          'pay_test(bigint) бор');
select has_function('public', 'public_settings',  array[]::text[],          'public_settings() бор');
select has_function('public', 'my_profile',       array[]::text[],          'my_profile() бор');
select has_function('public', 'login_start',      array['boolean'],         'login_start(boolean) бор');
select has_function('public', 'customer_ack',     array['bigint', 'boolean', 'text'], 'customer_ack(bigint, boolean, text) бор');
select has_function('public', 'log_event',        array['text', 'text', 'jsonb'],     'log_event(text, text, jsonb) бор');

-- 2) Қайтариладиган тур (сайт шунга таянади)
select function_returns('public', 'create_order', array['jsonb'],  'orders', 'create_order буюртма қаторини қайтаради');
select function_returns('public', 'pay_test',     array['bigint'], 'jsonb',  'pay_test jsonb қайтаради');
select function_returns('public', 'quote_order',  array['jsonb'],  'jsonb',  'quote_order jsonb қайтаради');

-- 3) Ҳуқуқлар: буюртма ва тўлов фақат сессияли (authenticated) фойдаланувчига
select ok(    has_function_privilege('authenticated', 'public.create_order(jsonb)', 'execute'), 'create_order: authenticated чақира олади');
select ok(not has_function_privilege('anon',          'public.create_order(jsonb)', 'execute'), 'create_order: anon чақира олмайди');
select ok(    has_function_privilege('authenticated', 'public.pay_test(bigint)', 'execute'),    'pay_test: authenticated чақира олади');
select ok(not has_function_privilege('anon',          'public.pay_test(bigint)', 'execute'),    'pay_test: anon чақира олмайди');
select ok(not has_function_privilege('anon',          'public.pay_start(bigint,text)', 'execute'), 'pay_start: anon чақира олмайди');
select ok(    has_function_privilege('anon',          'public.quote_order(jsonb)', 'execute'),  'quote_order: anon ҳам ҳисоблай олади (каталог очиқ)');
select ok(not has_function_privilege('authenticated', 'public.pay_complete(text,text,boolean,jsonb)', 'execute'), 'pay_complete: фақат сервер (authenticated эмас)');
select ok(not has_function_privilege('anon',          'public.pay_complete(text,text,boolean,jsonb)', 'execute'), 'pay_complete: фақат сервер (anon эмас)');
select ok(not has_function_privilege('authenticated', 'public.pay_create(text,text,bigint,bigint,jsonb)', 'execute'), 'pay_create: фақат сервер');

-- 4) Жадваллар: харидор фақат ўз буюртмасини ўқийди, ёза олмайди
select ok(    has_table_privilege('authenticated', 'public.orders', 'select'), 'orders: authenticated ўқий олади (RLS билан)');
select ok(not has_table_privilege('authenticated', 'public.orders', 'insert'), 'orders: authenticated тўғридан-тўғри ёза олмайди');
select ok(not has_table_privilege('authenticated', 'public.orders', 'update'), 'orders: authenticated ўзгартира олмайди');
select ok(not has_table_privilege('anon',          'public.orders', 'select'), 'orders: anon ўқий олмайди');
select ok(not has_table_privilege('authenticated', 'public.payments', 'select'), 'payments: харидорга ёпиқ');
select ok(not has_table_privilege('authenticated', 'public.ledger', 'select'),   'ledger: харидорга ёпиқ');
select ok(not has_table_privilege('authenticated', 'public.app_settings', 'select'), 'app_settings: харидорга ёпиқ (сирлар шу ерда)');
select policies_are('public', 'orders', array['orders: own select'], 'orders: фақат битта «ўзиники» қоидаси');

-- 5) Очиқ view'лар anon учун ишлайди (каталог кирмасдан кўринади)
select lives_ok($$ select pg_temp.as_anon('select count(*)::text::jsonb from public.catalog_public') $$, 'anon catalog_public ни ўқий олади');
select lives_ok($$ select pg_temp.as_anon('select count(*)::text::jsonb from public.markets_public') $$, 'anon markets_public ни ўқий олади');
select throws_ok($$ select pg_temp.as_anon('select count(*)::text::jsonb from public.orders') $$, '42501', null, 'anon orders ни ўқий олмайди');

-- 6) is_test_env ташқарига ёпиқ (28-миграция)
select ok(not has_function_privilege('authenticated', 'public.is_test_env()', 'execute'), 'is_test_env: ташқарига ёпиқ');

select * from finish();
rollback;
