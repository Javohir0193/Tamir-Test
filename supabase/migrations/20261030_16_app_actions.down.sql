-- Ta'mir: 20261030_16_app_actions.sql ни орқага қайтаради.
-- Эслатма: products.reviewed_at ўчади (таклиф кўриб чиқилгани белгиси). Ҳайдовчи функциялари 08-миграциядаги ҳолатига қайтади.
begin;
drop function if exists public.admin_product_decide(text, integer, boolean);
drop function if exists public.admin_product_proposals(text);
CREATE OR REPLACE FUNCTION public.drv_order_json(o orders)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  return jsonb_build_object('no', o.no, 'stage', o.stage, 'address', o.address, 'lat', o.delivery_lat, 'lng', o.delivery_lng,
    'pickup_lat', o.pickup_lat, 'pickup_lng', o.pickup_lng, 'pickup_note', o.pickup_note,
    'customer', o.customer_name, 'phone', o.phone, 'slot', o.slot, 'note', o.note, 'driver_id', o.driver_id,
    'fee', coalesce(o.delivery_sum, 0) - coalesce(o.driver_fee, 0), 'market', (select coalesce(m.name_uz, m.name) from public.markets m where m.id = o.market_id),
    'lines', coalesce((select jsonb_agg(jsonb_build_object('line_no', l.line_no, 'name', l.name, 'qty', l.qty, 'unit', l.unit, 'loaded', l.loaded,
        'shop', coalesce(nullif(s.shop, ''), s.name), 'shop_phone', s.phone) order by l.seller_id, l.line_no)
        from public.order_lines l left join public.sellers s on s.id = l.seller_id where l.order_no = o.no and l.status <> 'missing' and l.seller_id is not null), '[]'::jsonb));
end $function$;

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
        where mk is not null and o.market_id = mk and o.mode = 'delivery' and o.driver_id is null and o.stage < 3 and o.fleet_dispatched_at is not null and o.cancelled_at is null), '[]'::jsonb),
    'mine', coalesce((select jsonb_agg(public.drv_order_json(o) order by o.no desc) from public.orders o
        where o.driver_id = d.id and o.cancelled_at is null and (o.stage < 4 or o.times ->> 4 is not null and (o.times ->> 4)::bigint > (extract(epoch from now() - interval '2 days') * 1000)::bigint)), '[]'::jsonb),
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
   where no = p_no and driver_id is null and cancelled_at is null and stage < 3 and mode = 'delivery' and market_id = mk;
  if not found then return false; end if;
  update public.order_lines set loaded = false where order_no = p_no;
  perform public.bot_post(jsonb_build_object('dm', coalesce((select jsonb_agg(jsonb_build_object('chat_id', a.tg_chat_id,
     'text', '🚚 №' || p_no || ': ҳайдовчи ' || coalesce(d.name, '') || ' иловадан олди.')) from public.sellers a where a.role = 'admin' and a.status = 'active' and a.tg_chat_id is not null), '[]'::jsonb)));
  return true;
end $function$;

CREATE OR REPLACE FUNCTION public.drv_go(p_session text, p_no bigint)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare d public.sellers := public.drv_auth(p_session); o public.orders; n int; t jsonb;
begin
  select * into o from public.orders where no = p_no and driver_id = d.id for update;
  if not found then return 'not_yours'; end if;
  if o.stage >= 3 then return 'already'; end if;
  select count(*) into n from public.order_lines where order_no = p_no and status <> 'missing' and seller_id is not null and not loaded;
  if n > 0 then return 'not_loaded'; end if;
  t := coalesce(o.times, '[]'::jsonb);
  for i in o.stage .. 2 loop t := t || to_jsonb((extract(epoch from now()) * 1000)::bigint); end loop;
  update public.orders set stage = 3, times = t, loaded_at = now() where no = p_no;
  return 'ok';
end $function$;

alter table public.products drop column if exists reviewed_at;
commit;
