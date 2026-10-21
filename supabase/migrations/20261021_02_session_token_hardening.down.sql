-- Ta'mir: 20261021_02_session_token_hardening.sql ни орқага қайтариш.
-- Функциялар, устун default'лари, сессия муддатлари, bot_secret ва default ҳуқуқлар аввалги ҳолига қайтади.

begin;

do $$
begin
  if not exists (select 1 from ops.acl_backup where migration = '20261021_02') then
    raise exception 'ops.acl_backup''да 20261021_02 йўқ: миграция ишга туширилмаган ёки аллақачон қайтарилган';
  end if;
end $$;

-- 1. Сессия муддати
alter table public.driver_sessions alter column expires_at set default (now() + '365 days'::interval);
alter table public.collector_sessions alter column expires_at set default (now() + '365 days'::interval);
update public.driver_sessions s set expires_at = b.expires_at
  from ops.session_backup b where b.migration = '20261021_02' and b.tbl = 'driver_sessions' and b.token_hash = s.token_hash;
update public.collector_sessions s set expires_at = b.expires_at
  from ops.session_backup b where b.migration = '20261021_02' and b.tbl = 'collector_sessions' and b.token_hash = s.token_hash;
delete from ops.session_backup where migration = '20261021_02';

CREATE OR REPLACE FUNCTION public.drv_auth(p_session text)
 RETURNS sellers
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare d public.sellers; h text := encode(digest(coalesce(p_session, ''), 'sha256'), 'hex');
begin
  select s.* into d from public.driver_sessions ss join public.sellers s on s.id = ss.seller_id
   where ss.token_hash = h and ss.expires_at > now() and s.role = 'driver' and s.status = 'active';
  if not found then raise exception 'not_authorized'; end if;
  update public.driver_sessions set last_seen = now(), expires_at = greatest(expires_at, now() + interval '365 days') where token_hash = h;
  return d;
end $function$;

-- 2. Токенлар
CREATE OR REPLACE FUNCTION public.login_start(p_consent boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare t text;
begin
  if auth.uid() is null then raise exception 'no_session'; end if;
  if (select count(*) from public.login_tokens where uid = auth.uid() and created_at > now() - interval '1 hour') >= 10 then
    raise exception 'too_many' using errcode = '54000';
  end if;
  t := substr(md5(random()::text || clock_timestamp()::text || auth.uid()::text), 1, 24);
  insert into public.login_tokens (token, uid, consent) values (t, auth.uid(), coalesce(p_consent, false));
  return jsonb_build_object('token', t, 'bot', (select value from public.app_settings where key = 'bot_username'));
end $function$;

alter table public.sellers alter column code set default substr(md5(((random())::text || (clock_timestamp())::text)), 1, 12);

-- 3. admin_check (эски умумий код йўли билан)
CREATE OR REPLACE FUNCTION public.admin_check(p_code text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare a public.admin_users; pid bigint := public.my_profile_id(); sid bigint;
begin
  if pid is null or not public.is_admin() then raise exception 'admin_login_required' using errcode = '42501'; end if;
  if p_code is not null then
    select u.* into a from public.admin_sessions s join public.admin_users u on u.id = s.admin_id
     where s.token_hash = encode(extensions.digest(p_code, 'sha256'), 'hex') and s.profile_id = pid and s.ended_at is null
       and s.expires_at > now() and s.last_seen > now() - interval '30 minutes' and u.status = 'active';
    if found then
      update public.admin_sessions set last_seen = now() where token_hash = encode(extensions.digest(p_code, 'sha256'), 'hex');
      perform set_config('app.admin_id', a.id::text, true);
      perform set_config('app.admin_name', a.name, true);
      perform set_config('app.admin_roles', array_to_string(a.roles, ','), true);
      return;
    end if;
  end if;
  -- эски умумий код: фақат ҳали ҳеч ким PIN қўймаган бўлса
  if not exists (select 1 from public.admin_users where pin_hash is not null)
     and p_code is not null and p_code = (select value from public.app_settings where key = 'admin_code') then
    perform set_config('app.admin_id', '0', true); perform set_config('app.admin_name', 'умумий код', true); perform set_config('app.admin_roles', 'owner', true);
    return;
  end if;
  raise exception 'wrong code' using errcode = '28000';
end $function$;

-- 4. bot_secret Vault'дан жадвалга қайтади
insert into public.app_settings (key, value)
select 'bot_secret', decrypted_secret from vault.decrypted_secrets where name = 'bot_secret'
on conflict (key) do update set value = excluded.value;

CREATE OR REPLACE FUNCTION public.bot_post(p_body jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  perform net.http_post(
    url     := (select value from public.app_settings where key = 'bot_url'),
    body    := p_body,
    headers := jsonb_build_object('Content-Type', 'application/json',
                                  'x-bot-secret', (select value from public.app_settings where key = 'bot_secret')));
end $function$;

delete from vault.secrets where name = 'bot_secret';

-- 5. Янги функциялар учун default ҳуқуқлар
do $$
declare b aclitem[] := (select acl from ops.acl_backup where migration = '20261021_02' and ident = 'default:functions'); a record;
begin
  alter default privileges for role postgres grant execute on functions to public;
  alter default privileges for role postgres in schema public revoke execute on functions from anon, authenticated;
  if b is not null then
    for a in select g.grantee from aclexplode(b) g
              where g.privilege_type = 'EXECUTE' and g.grantee in (0, 'anon'::regrole, 'authenticated'::regrole) loop
      execute format('alter default privileges for role postgres in schema public grant execute on functions to %s',
                     case when a.grantee = 0 then 'public' else quote_ident(a.grantee::regrole::text) end);
    end loop;
  end if;
end $$;
delete from ops.acl_backup where migration = '20261021_02';

commit;
