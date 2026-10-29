-- Ta'mir: 20261029_08_order_cancel.sql ни орқага қайтаради.
-- Эслатма: бекор қилиш белгилари (cancelled_at, cancel_reason) ўчади.
begin;
drop function if exists public.admin_order_cancel(text, bigint, text);
-- drv_orders ва drv_claim ни аввалги (бекор қилиш шартисиз) ҳолатга қайтариш
CREATE OR REPLACE FUNCTION public.drv_orders(p_session text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare d public.sellers := public.drv_auth(p_session); mk int;
begin
  select market_id into mk from public.fleets where id = d.fleet_id and active;
  return jsonb_build_object(
    'me', jsonb_build_object('id', d.id, 'name', coalesce(nullif(d.name, ''), d.shop), 'car', d.car, 'fleet', (select name from public.fleets where id = d.fleet_id)),
    'open', coalesce((select jsonb_agg(public.drv_order_json(o) order by o.fleet_dispatched_at) from public.orders o
        where mk is not null and o.market_id = mk and o.mode = 'delivery' and o.driver_id is null and o.stage < 3 and o.fleet_dispatched_at is not null), '[]'::jsonb),
    'mine', coalesce((select jsonb_agg(public.drv_order_json(o) order by o.no desc) from public.orders o
        where o.driver_id = d.id and (o.stage < 4 or o.times ->> 4 is not null and (o.times ->> 4)::bigint > (extract(epoch from now() - interval '2 days') * 1000)::bigint)), '[]'::jsonb),
    'earn', coalesce((select jsonb_build_object('due', b.earned - b.paid, 'waiting', b.waiting, 'held', b.held, 'paid', b.paid) from public.staff_balance_v b where b.seller_id = d.id),
        jsonb_build_object('due', 0, 'waiting', 0, 'held', 0, 'paid', 0)));
end $function$;

CREATE OR REPLACE FUNCTION public.drv_claim(p_session text, p_no bigint)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare d public.sellers := public.drv_auth(p_session); mk int;
begin
  select market_id into mk from public.fleets where id = d.fleet_id and active;
  if mk is null then raise exception 'no_fleet'; end if;
  update public.orders set driver_id = d.id, driver_info = jsonb_build_object('name', d.name, 'phone', d.phone, 'car', coalesce(d.car, ''))
   where no = p_no and driver_id is null and stage < 3 and mode = 'delivery' and market_id = mk;
  if not found then return false; end if;
  update public.order_lines set loaded = false where order_no = p_no;
  perform public.bot_post(jsonb_build_object('dm', coalesce((select jsonb_agg(jsonb_build_object('chat_id', a.tg_chat_id,
     'text', '🚚 №' || p_no || ': ҳайдовчи ' || coalesce(d.name, '') || ' иловадан олди.')) from public.sellers a where a.role = 'admin' and a.status = 'active' and a.tg_chat_id is not null), '[]'::jsonb)));
  return true;
end $function$;

alter table public.orders drop column if exists cancel_reason;
alter table public.orders drop column if exists cancelled_at;
commit;
