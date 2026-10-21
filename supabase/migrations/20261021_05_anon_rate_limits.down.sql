-- Ta'mir: 20261021_05_anon_rate_limits.sql ни орқага қайтариш. Функциялар аввалги ҳолига қайтади, индекс ўчади.

begin;

CREATE OR REPLACE FUNCTION public.log_event(p_anon text, p_kind text, p_props jsonb DEFAULT '{}'::jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if p_kind not in ('visit', 'tab', 'search', 'calc', 'cart_add', 'checkout', 'login_start', 'login', 'order') then return; end if;
  if p_anon is null or length(p_anon) not between 8 and 40 then return; end if;
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
  insert into public.collector_login (token) values (t);
  return t;
end $function$;

drop index if exists public.events_anon_at_idx;

commit;
