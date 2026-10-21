-- Ta'mir: сессия ва токенлар хавфсизлиги.
-- Нима ўзгаради ва нима учун:
--   1. Ҳайдовчи сессияси 365 кун эмас, 30 кун (ишлатиб турса ўзи узаяди). Йўқолган телефон бир йил очиқ қолмасин.
--   2. Кириш токени (login_start) ва сотувчи коди (sellers.code) md5(random()) эмас, криптографик тасодифий байтдан.
--      random() олдиндан тахмин қилиниши мумкин. Узунлиги ва кўриниши ўша-ўша (24 ва 12 та hex белги).
--   3. admin_check'дан эски «умумий код» йўли олинди. Админ сайти фақат PIN билан киради.
--      Биринчи эгани яратиш (admin_set_pin) аввалгидек ишлайди.
--   4. bot_secret оддий жадвалдан Vault'га кўчади. ЭСЛАТМА: tg-bot Vault'ни ўқимайди, шунинг учун бу қисм
--      20261021_04 билан бекор қилинган. 02 ни 04 дан кейин қайта ишга туширманг (ботга хабар 500 беради).
--   5. Келажакда public схемада яратиладиган функцияларни аноним меҳмон автоматик чақира олмасин.
-- Нима ўзгармайди: жадваллар тузилмаси, сайт чақирадиган функциялар номи ва жавоби, маълумотлар.
-- Орқага қайтариш: 20261021_02_session_token_hardening.down.sql
-- Тартиб: ФАҚАТ test базада. SQL Editor'га тўлиқ қўйиб Run.

begin;

create schema if not exists ops;
revoke all on schema ops from public, anon, authenticated;
create table if not exists ops.session_backup (
  migration text not null,
  tbl text not null,
  token_hash text not null,
  expires_at timestamptz not null,
  primary key (migration, tbl, token_hash)
);
create table if not exists ops.acl_backup (
  migration text not null,
  ident text not null,
  acl aclitem[],
  saved_at timestamptz not null default now(),
  primary key (migration, ident)
);

-- 1. Сессия муддати: 30 кун
insert into ops.session_backup (migration, tbl, token_hash, expires_at)
select '20261021_02', 'driver_sessions', token_hash, expires_at from public.driver_sessions where expires_at > now() + interval '30 days'
union all
select '20261021_02', 'collector_sessions', token_hash, expires_at from public.collector_sessions where expires_at > now() + interval '30 days'
on conflict do nothing;
update public.driver_sessions set expires_at = now() + interval '30 days' where expires_at > now() + interval '30 days';
update public.collector_sessions set expires_at = now() + interval '30 days' where expires_at > now() + interval '30 days';
alter table public.driver_sessions alter column expires_at set default (now() + '30 days'::interval);
alter table public.collector_sessions alter column expires_at set default (now() + '30 days'::interval);

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
  update public.driver_sessions set last_seen = now(), expires_at = greatest(expires_at, now() + interval '30 days') where token_hash = h;
  return d;
end $function$;

-- 2. Тасодифий токенлар
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
  t := encode(extensions.gen_random_bytes(12), 'hex');
  insert into public.login_tokens (token, uid, consent) values (t, auth.uid(), coalesce(p_consent, false));
  return jsonb_build_object('token', t, 'bot', (select value from public.app_settings where key = 'bot_username'));
end $function$;

alter table public.sellers alter column code set default encode(extensions.gen_random_bytes(6), 'hex');

-- 3. Эски умумий код йўлисиз admin_check
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
  raise exception 'wrong code' using errcode = '28000';
end $function$;

-- 4. bot_secret -> Vault
do $$
declare v text := (select value from public.app_settings where key = 'bot_secret');
begin
  if v is null then
    raise notice 'app_settings.bot_secret йўқ, Vault''га ҳеч нарса кўчирилмади';
  elsif exists (select 1 from vault.secrets where name = 'bot_secret') then
    perform vault.update_secret((select id from vault.secrets where name = 'bot_secret'), v);
  else
    perform vault.create_secret(v, 'bot_secret', 'tg-bot x-bot-secret');
  end if;
end $$;

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
                                  'x-bot-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'bot_secret')));
end $function$;

delete from public.app_settings where key = 'bot_secret';

-- 5. Янги функциялар аноним учун ёпиқ туғилсин (мавжудларига тегмайди)
insert into ops.acl_backup (migration, ident, acl)
select '20261021_02', 'default:functions',
       (select d.defaclacl from pg_default_acl d join pg_namespace n on n.oid = d.defaclnamespace
         where d.defaclrole = 'postgres'::regrole and n.nspname = 'public' and d.defaclobjtype = 'f')   -- null = стандарт ҳолат
on conflict (migration, ident) do nothing;
alter default privileges for role postgres revoke execute on functions from public;      -- PUBLIC'га берилган стандарт ҳуқуқ шу ерда олинади
alter default privileges for role postgres in schema public revoke execute on functions from anon, authenticated;

commit;

-- Текшириш (алоҳида ишга туширинг):
-- select count(*) from vault.decrypted_secrets where name = 'bot_secret';          -- 1
-- select count(*) from public.app_settings where key = 'bot_secret';               -- 0
-- select max(expires_at) from public.driver_sessions;                              -- 30 кундан кўп эмас
-- Кейин сайтда битта синов буюртма беринг: ботга хабар келиши керак.
