-- Ta'mir: тозалаш (cron) ва эски admin_code нинг охирги изини олиб ташлаш.
-- Нима ўзгаради ва нима учун:
--   1. Ҳар куни 03:30 UTC (Тошкентда 08:30) ops.cleanup() ишлайди: муддати ўтган кириш токенлари, тугаган
--      сессиялар ўчади. Жадваллар ортиқча катталашмайди, эски токенлар базада ётмайди. events, audit_log тегилмайди
--      (аналитика ва аудит учун керак).
--   2. admin_set_pin эндиги «умумий код» билан биринчи эгани яратмайди (ҳали admin_users'да йўқ одам учун
--      'owner_not_found' беради). Биринчи эгани фақат SQL Editor орқали қўшиш мумкин. Мавжуд эгалар PIN'ини
--      алмаштира олади, ўзгармайди.
--   3. app_settings'даги admin_code қиймати ўчади (ops.setting_backup'га сақланади, орқага қайтарилса тикланади).
-- Нима ўзгармайди: админга PIN билан кириш, сайт функциялари, бошқа маълумотлар.
-- Орқага қайтариш: 20261021_03_cleanup_and_admin_code.down.sql. Ўчирилган эски токен/сессиялар қайтмайди (керак эмас).
-- Тартиб: ФАҚАТ test базада, 02 дан кейин. SQL Editor'га тўлиқ қўйиб Run.

begin;

create schema if not exists ops;
revoke all on schema ops from public, anon, authenticated;
create table if not exists ops.setting_backup (
  migration text not null,
  key text not null,
  value text,
  saved_at timestamptz not null default now(),
  primary key (migration, key)
);

-- 1. Тозалаш функцияси (ops схемаси API орқали кўринмайди)
create or replace function ops.cleanup() returns jsonb
language plpgsql security definer set search_path to 'public' as $$
declare a int; b int; c int; d int; e int;
begin
  delete from public.login_tokens      where created_at < now() - interval '7 days';          get diagnostics a = row_count;
  delete from public.driver_login      where created_at < now() - interval '7 days';          get diagnostics b = row_count;
  delete from public.collector_login   where created_at < now() - interval '7 days';          get diagnostics c = row_count;
  delete from public.driver_sessions   where expires_at < now() - interval '7 days';
  delete from public.collector_sessions where expires_at < now() - interval '7 days';          get diagnostics d = row_count;
  delete from public.admin_sessions    where coalesce(ended_at, expires_at) < now() - interval '30 days'; get diagnostics e = row_count;
  return jsonb_build_object('login_tokens', a, 'driver_login', b, 'collector_login', c, 'collector_sessions', d, 'admin_sessions', e);
end $$;
revoke all on function ops.cleanup() from public, anon, authenticated;

do $$
begin
  if exists (select 1 from pg_namespace where nspname = 'cron') then
    perform cron.schedule('tamir-cleanup', '30 3 * * *', 'select ops.cleanup()');
  else
    raise notice 'pg_cron йўқ: тозалаш режаланмади, ops.cleanup() ни қўлда ишга туширинг';
  end if;
end $$;

-- 2. admin_set_pin: «умумий код» билан эга яратиш йўқ
CREATE OR REPLACE FUNCTION public.admin_set_pin(p_code text, p_pin text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare a public.admin_users; pid bigint := public.my_profile_id(); nm text;
begin
  if pid is null or not public.is_admin() then raise exception 'admin_login_required' using errcode = '42501'; end if;
  if p_pin is null or p_pin !~ '^[0-9]{6,12}$' then raise exception 'bad_pin'; end if;
  select * into a from public.admin_users where profile_id = pid;
  if found and a.pin_hash is null then
    update public.admin_users set pin_hash = extensions.crypt(p_pin, extensions.gen_salt('bf', 8)) where id = a.id;
  elsif found then
    perform public.admin_check(p_code);                                   -- PIN алмаштириш: жорий сессия керак
    update public.admin_users set pin_hash = extensions.crypt(p_pin, extensions.gen_salt('bf', 8)) where id = a.id;
  else
    raise exception 'owner_not_found' using errcode = '42501';   -- биринчи эгани фақат SQL орқали қўшиш мумкин
  end if;
  perform set_config('app.admin_name', coalesce(nm, a.name, ''), true);
  perform public.admin_log('set_pin', 'admin', coalesce(a.id::text, pid::text));
end $function$;

-- 3. admin_code ни ўчириш
insert into ops.setting_backup (migration, key, value)
select '20261021_03', key, value from public.app_settings where key = 'admin_code'
on conflict (migration, key) do nothing;
delete from public.app_settings where key = 'admin_code';

commit;

-- Текшириш (алоҳида ишга туширинг):
-- select count(*) from public.app_settings where key = 'admin_code';   -- 0
-- select jobname, schedule from cron.job where jobname = 'tamir-cleanup';   -- 1 қатор
-- select ops.cleanup();   -- натижада рақамлар чиқади (ўчирилганлар сони)
-- Кейин админ сайтига ўз PIN'ингиз билан кириб кўринг.
