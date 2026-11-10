-- Ta'mir: синов тўлови (pay_test, «🧪 Тестовая оплата») production базада ҳеч қачон ишламасин.
-- Нима учун: ҳозир pay_test фақат app_settings.pay_test_mode = 'true' га қарайди. Prod базада шу созлама
--   адашиб (ёки test базадан нусха олинганда) 'true' бўлиб қолса, ҳар қандай мижоз буюртмасини пулсиз «тўланган»
--   қилади: буюртма йиғувчига чиқади, ledger'га пул ёзилади. Бу битта созламага боғлиқ бўлмаслиги керак.
-- Нима ўзгаради:
--   is_test_env() — app_settings.app_env = 'test' бўлсагина true. Созлама йўқ бўлса — false (fail-closed).
--     app_env ни панелдан ўзгартириб бўлмайди (admin_set_app рўйхатида йўқ), фақат SQL Editor'дан.
--   pay_test(no) — энди pay_test_mode = 'true' ВА app_env = 'test' бўлиши шарт, акс ҳолда {"error":"test_off"}.
--   pay_create(...) — provider = 'test' бўлса ва база test эмас бўлса {"r":"test_off"} (иккинчи қулф:
--     ким чақирса ҳам — бот, келажакдаги pay функцияси — «test» тўлов prod'да яратилмайди).
-- Нима ўзгармайди: жадваллар, бошқа тўлов функциялари, Click/Payme йўли, ҳуқуқлар (grant'лар аввалгидек).
-- МУҲИМ — TEST базада шу миграциядан кейин бир марта:  supabase/ops/mark_test_env.sql  (app_env = 'test').
--   Буни қилмасангиз test сайтда «Тестовая оплата» «test_off» қайтаради. PROD базада бу файлни ҲЕЧ ҚАЧОН ишлатманг.
-- Орқага қайтариш: 20261110_28_pay_test_lock.down.sql
-- Тартиб: 27 дан кейин. SQL Editor'га тўлиқ қўйиб Run.

begin;

create or replace function public.is_test_env()
 returns boolean
 language sql
 stable security definer
 set search_path to 'public'
as $function$
  select coalesce((select value from public.app_settings where key = 'app_env'), '') = 'test'
$function$;

CREATE OR REPLACE FUNCTION public.pay_create(p_provider text, p_trans_id text, p_no bigint, p_amount bigint, p_ext jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare pm public.payments; chk text;
begin
  if p_provider = 'test' and not public.is_test_env() then return jsonb_build_object('r', 'test_off'); end if;   -- 28: prod'да синов тўлови йўқ
  select * into pm from public.payments where provider = p_provider and provider_trans_id = p_trans_id;
  if found then
    return jsonb_build_object('r', 'ok', 'id', pm.id, 'status', pm.status, 'created_at', pm.created_at, 'ext', pm.ext, 'order_no', pm.order_no, 'amount', pm.amount, 'again', true);
  end if;
  perform 1 from public.orders where no = p_no for update;
  chk := public.pay_check(p_no, p_amount);
  if chk <> 'ok' then return jsonb_build_object('r', chk); end if;
  -- бошқа тўлов тизими/транзакция шу буюртма учун ҳозир очиқ бўлса (15 дақиқа ичида) — банд
  if exists (select 1 from public.payments where order_no = p_no and status = 'created'
             and created_at > now() - interval '15 minutes' and not (provider = p_provider and provider_trans_id = p_trans_id)) then
    return jsonb_build_object('r', 'busy');
  end if;
  insert into public.payments (order_no, provider, provider_trans_id, amount, ext)
    values (p_no, p_provider, p_trans_id, p_amount, coalesce(p_ext, '{}'::jsonb)) returning * into pm;
  return jsonb_build_object('r', 'ok', 'id', pm.id, 'status', pm.status, 'created_at', pm.created_at, 'ext', pm.ext, 'order_no', pm.order_no, 'amount', pm.amount);
end $function$;

CREATE OR REPLACE FUNCTION public.pay_test(p_no bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare o public.orders; tid text := 'T' || p_no || '-' || (extract(epoch from clock_timestamp()) * 1000)::bigint; r jsonb;
begin
  if coalesce((select value from public.app_settings where key = 'pay_test_mode'), 'false') <> 'true'
     or not public.is_test_env() then                                   -- 28: фақат test базада
    return jsonb_build_object('error', 'test_off');
  end if;
  if not public.my_order_ok(p_no) then return jsonb_build_object('error', 'not_found'); end if;
  select * into o from public.orders where no = p_no;
  r := public.pay_create('test', tid, p_no, o.pay_amount);
  if r->>'r' <> 'ok' then return jsonb_build_object('error', r->>'r'); end if;
  r := public.pay_complete('test', tid);
  return jsonb_build_object('ok', r->>'r' = 'ok', 'r', r->>'r');
end $function$;

revoke all on function public.is_test_env() from public, anon, authenticated;
grant execute on function public.is_test_env() to service_role;

commit;

-- Текшириш:
-- select public.is_test_env();                                      -- TEST: true (mark_test_env.sql дан кейин), PROD: false
-- select key, value from public.app_settings where key in ('app_env', 'pay_test_mode');
