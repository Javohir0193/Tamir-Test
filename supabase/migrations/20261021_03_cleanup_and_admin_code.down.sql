-- Ta'mir: 20261021_03_cleanup_and_admin_code.sql ни орқага қайтариш.
-- Cron иши ўчади, admin_set_pin эски кўринишига, admin_code қиймати жойига қайтади.
-- Тозалаш билан ўчирилган эски токен ва сессиялар қайтмайди.

begin;

do $$
begin
  if exists (select 1 from pg_namespace where nspname = 'cron') then
    perform cron.unschedule('tamir-cleanup');
  end if;
exception when others then
  raise notice 'tamir-cleanup иши топилмади';
end $$;
drop function if exists ops.cleanup();

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
    if p_code is distinct from (select value from public.app_settings where key = 'admin_code') then raise exception 'wrong code' using errcode = '28000'; end if;
    select coalesce(name, phone, 'Эга') into nm from public.profiles where id = pid;
    insert into public.admin_users (profile_id, name, roles, pin_hash) values (pid, nm, array['owner'], extensions.crypt(p_pin, extensions.gen_salt('bf', 8)));
  end if;
  perform set_config('app.admin_name', coalesce(nm, a.name, ''), true);
  perform public.admin_log('set_pin', 'admin', coalesce(a.id::text, pid::text));
end $function$;

insert into public.app_settings (key, value)
select key, value from ops.setting_backup where migration = '20261021_03' and key = 'admin_code'
on conflict (key) do update set value = excluded.value;
delete from ops.setting_backup where migration = '20261021_03';

commit;
