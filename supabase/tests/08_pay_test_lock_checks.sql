-- Синов тўлови қулфи (28-миграция): pay_test фақат app_env = 'test' базада ишлайди; prod'да (app_env йўқ ёки бошқа)
-- буюртма пулсиз «тўланган» бўлмайди, payments'га «test» ёзуви тушмайди. API (pay_test имзоси ва ҳуқуқлари) ўзгармаган.
-- ledger фақат қўшилади (ўчириб бўлмайди), шунинг учун ҳаммаси битта транзакцияда ва охирида rollback.
begin;
do $$
declare u uuid := gen_random_uuid(); no1 bigint; r jsonb;
begin
  delete from public.app_settings where key = 'app_env';
  insert into public.app_settings (key, value) values ('pay_test_mode', 'true') on conflict (key) do update set value = 'true';

  insert into auth.users (id) values (u);
  perform set_config('request.jwt.claim.sub', u::text, true);
  insert into public.orders (customer_name, phone, mode, items, total, user_id) values ('CI', '+998900000001', 'car', '[]'::jsonb, 1000, u) returning no into no1;
  update public.orders set pay_status = 'unpaid', pay_amount = 1000, pay_due = now() + interval '30 minutes' where no = no1;

  -- 1) prod (app_env йўқ), pay_test_mode = true бўлса ҳам — ёпиқ
  r := public.pay_test(no1);
  if r->>'error' is distinct from 'test_off' then raise exception 'pay_test app_env йўқ базада ишлади: %', r; end if;
  if (select pay_status from public.orders where no = no1) <> 'unpaid' then raise exception 'prod: буюртма тўланган бўлиб қолди'; end if;
  if exists (select 1 from public.payments where order_no = no1) then raise exception 'prod: payments ёзуви пайдо бўлди'; end if;

  -- 2) pay_create тўғридан-тўғри (бот ёки pay функцияси) ҳам «test» ни яратмайди
  r := public.pay_create('test', 'ci-direct', no1, 1000);
  if r->>'r' is distinct from 'test_off' then raise exception 'pay_create test prod''да очиқ: %', r; end if;

  -- 3) app_env = 'prod' — ёпиқ
  insert into public.app_settings (key, value) values ('app_env', 'prod');
  r := public.pay_test(no1);
  if r->>'error' is distinct from 'test_off' then raise exception 'pay_test app_env=prod базада ишлади: %', r; end if;

  -- 4) test база, лекин pay_test_mode = false — ёпиқ
  update public.app_settings set value = 'test' where key = 'app_env';
  update public.app_settings set value = 'false' where key = 'pay_test_mode';
  r := public.pay_test(no1);
  if r->>'error' is distinct from 'test_off' then raise exception 'pay_test pay_test_mode=false да ишлади: %', r; end if;

  -- 5) test база + pay_test_mode = true — ишлайди (test сайт синови бузилмаган)
  update public.app_settings set value = 'true' where key = 'pay_test_mode';
  r := public.pay_test(no1);
  if not coalesce((r->>'ok')::boolean, false) then raise exception 'pay_test test базада ишламади: %', r; end if;
  if (select pay_status from public.orders where no = no1) <> 'paid' then raise exception 'test: буюртма тўланмади'; end if;
  perform set_config('request.jwt.claim.sub', '', true);

  -- ҳуқуқлар: pay_test API аввалгидек (authenticated), is_test_env ташқарига ёпиқ
  if not has_function_privilege('authenticated', 'public.pay_test(bigint)', 'execute') then raise exception 'pay_test authenticated''га ёпилиб қолди (API бузилди)'; end if;
  if has_function_privilege('anon', 'public.pay_test(bigint)', 'execute') then raise exception 'pay_test anon''га очиқ'; end if;
  if has_function_privilege('authenticated', 'public.pay_create(text,text,bigint,bigint,jsonb)', 'execute') then raise exception 'pay_create authenticated''га очиқ'; end if;
  if has_function_privilege('anon', 'public.is_test_env()', 'execute') or has_function_privilege('authenticated', 'public.is_test_env()', 'execute') then
    raise exception 'is_test_env ташқарига очиқ'; end if;

end $$;
rollback;
