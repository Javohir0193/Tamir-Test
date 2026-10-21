-- Ta'mir: аноним чақириладиган 3 та функцияга спамдан ҳимоя.
-- Нима учун: log_event, drv_login_new, col_login_new ни ҳар ким (киришсиз) чексиз чақира олади.
--   Бот ёки скрипт events, driver_login, collector_login жадвалларини миллионлаб қатор билан тўлдириши мумкин.
-- Нима ўзгаради:
--   1. log_event: битта браузер (anon) учун минутига 30 та ҳодиса, ҳаммаси бўлиб минутига 3000 та. Ортиғи жимгина ташланади
--      (сайт хато кўрмайди, бу функция фақат статистика учун).
--   2. drv_login_new, col_login_new: ҳаммаси бўлиб 10 минутда 100 та кириш ҳаволаси. Ортиғида «Жуда кўп уриниш» хатоси.
--      Оддий ишлатишда (бир неча ходим) бу чегарага ҳеч қачон етилмайди.
--   3. events(anon, at) индекси: биринчи текширув тез ишлаши учун.
-- Нима ўзгармайди: функциялар номи, параметрлари ва жавоби, жадваллар тузилмаси.
-- Орқага қайтариш: 20261021_05_anon_rate_limits.down.sql
-- Тартиб: ФАҚАТ test базада. SQL Editor'га тўлиқ қўйиб Run.

begin;

create index if not exists events_anon_at_idx on public.events (anon, at);

CREATE OR REPLACE FUNCTION public.log_event(p_anon text, p_kind text, p_props jsonb DEFAULT '{}'::jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if p_kind not in ('visit', 'tab', 'search', 'calc', 'cart_add', 'checkout', 'login_start', 'login', 'order') then return; end if;
  if p_anon is null or length(p_anon) not between 8 and 40 then return; end if;
  if (select count(*) from (select 1 from public.events where anon = p_anon and at > now() - interval '1 minute' limit 30) x) >= 30 then return; end if;
  if (select count(*) from (select 1 from public.events where at > now() - interval '1 minute' limit 3000) x) >= 3000 then return; end if;
  if p_props is null or jsonb_typeof(p_props) <> 'object' or length(p_props::text) > 1000 then p_props := '{}'::jsonb; end if;
  insert into public.events (anon, kind, props) values (p_anon, p_kind, p_props);
end $function$;

CREATE OR REPLACE FUNCTION public.drv_login_new()
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare t text := replace(gen_random_uuid()::text, '-', '');
begin
  delete from public.driver_login where created_at < now() - interval '1 day';
  if (select count(*) from (select 1 from public.driver_login where created_at > now() - interval '10 minutes' limit 100) x) >= 100 then
    raise exception 'Жуда кўп уриниш. 10 дақиқадан кейин қайта уриниб кўринг.' using errcode = '54000';
  end if;
  insert into public.driver_login (token) values (t);
  return t;
end $function$;

CREATE OR REPLACE FUNCTION public.col_login_new()
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare t text := replace(gen_random_uuid()::text, '-', '');
begin
  delete from public.collector_login where created_at < now() - interval '1 day';
  if (select count(*) from (select 1 from public.collector_login where created_at > now() - interval '10 minutes' limit 100) x) >= 100 then
    raise exception 'Жуда кўп уриниш. 10 дақиқадан кейин қайта уриниб кўринг.' using errcode = '54000';
  end if;
  insert into public.collector_login (token) values (t);
  return t;
end $function$;

commit;

-- Текшириш (алоҳида ишга туширинг):
-- select count(*) from pg_indexes where indexname = 'events_anon_at_idx';   -- 1
-- Кейин driver.html да «Telegram орқали кириш» ни бир марта босинг: аввалгидек ишлаши керак.
