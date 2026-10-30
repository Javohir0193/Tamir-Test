-- Ta'mir: ботга келадиган тасдиқлар иловаларда ҳам — ҳайдовчи ва админ қисми (дўкон ва йиғувчи қисми tg-bot функциясида)
-- Нима ўзгаради:
--   1) Ҳайдовчи иловаси «Очиқ» рўйхатида машина буюртмалари ҳам кўринади (ботда «🙋 Мен бораман» келадиган буюртма).
--      drv_claim машина буюртмасини ҳам олади (паркка бириктирилмаган ҳайдовчи ҳам), ботдаги каби ҳолат «Тасдиқланди» бўлади.
--      drv_order_json га mode ва what (машина тури) қўшилади. Етказиш буюртмалари учун ҳаммаси ўша-ўша.
--   2) drv_go: иловадан «Йўлга чиқдим» босилганда админларга ботдаги каби хабар боради.
--   3) Янги товар таклифлари (ботда «✅ Каталогга қўшиш / ❌ Рад этиш») админ панелида ҳам:
--      products.reviewed_at, admin_product_proposals, admin_product_decide. Бот ҳам reviewed_at ни белгилайди.
-- Бот ва илова бир хил устунларни шартли (where … is null) янгилайди: иккаласидан бирдан босилса, иккинчиси «аллақачон» бўлади.
-- Орқага қайтариш: 20261030_16_app_actions.down.sql
-- Тартиб: аввал test базада, SQL Editor'га тўлиқ қўйиб Run. Кейин tg-bot функцияси (тартиб муҳим эмас: бот устун йўқлигида ҳам ишлайди).

begin;

alter table public.products add column if not exists reviewed_at timestamptz;

CREATE OR REPLACE FUNCTION public.drv_order_json(o orders)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  return jsonb_build_object('no', o.no, 'stage', o.stage, 'mode', o.mode, 'what', case when o.mode = 'car' then o.items -> 0 ->> 'n' end,
    'address', o.address, 'lat', o.delivery_lat, 'lng', o.delivery_lng,
    'pickup_lat', o.pickup_lat, 'pickup_lng', o.pickup_lng, 'pickup_note', o.pickup_note,
    'customer', o.customer_name, 'phone', o.phone, 'slot', o.slot, 'note', o.note, 'driver_id', o.driver_id,
    'fee', coalesce(o.delivery_sum, case when o.mode = 'car' then o.total end, 0) - coalesce(o.driver_fee, 0), 'market', (select coalesce(m.name_uz, m.name) from public.markets m where m.id = o.market_id),
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
    'open', coalesce((select jsonb_agg(public.drv_order_json(o) order by coalesce(o.fleet_dispatched_at, o.notified_at)) from public.orders o
        where o.driver_id is null and o.cancelled_at is null and (
          (mk is not null and o.market_id = mk and o.mode = 'delivery' and o.stage < 3 and o.fleet_dispatched_at is not null)
          or (o.mode = 'car' and o.stage = 0 and o.notified_at > now() - interval '2 days'))), '[]'::jsonb),
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
  -- машина буюртмаси: бот ҳамма ҳайдовчига юборади, биринчи олган олади (ботдаги claimCar билан бир хил шарт)
  if exists (select 1 from public.orders where no = p_no and mode = 'car') then
    update public.orders set driver_id = d.id, driver_info = jsonb_build_object('name', d.name, 'phone', d.phone, 'car', coalesce(d.car, '')),
           stage = 1, times = coalesce(times, '[]'::jsonb) || to_jsonb((extract(epoch from now()) * 1000)::bigint)
     where no = p_no and mode = 'car' and driver_id is null and cancelled_at is null and stage = 0;
    if not found then return false; end if;
    perform public.bot_post(jsonb_build_object('dm', coalesce((select jsonb_agg(jsonb_build_object('chat_id', a.tg_chat_id,
       'text', '🙋 Машина №' || p_no || ': ' || coalesce(d.name, '') || ' (' || coalesce(d.car, '') || ') иловадан олди.')) from public.sellers a where a.role = 'admin' and a.status = 'active' and a.tg_chat_id is not null), '[]'::jsonb)));
    return true;
  end if;
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
  select count(*) into n from public.order_lines where order_no = p_no and status <> 'missing' and seller_id is not null;
  perform public.bot_post(jsonb_build_object('dm', coalesce((select jsonb_agg(jsonb_build_object('chat_id', a.tg_chat_id,
     'text', '🚚 №' || p_no || ': ' || coalesce(d.name, '') || ' (' || coalesce(d.car, '') || ') йўлга чиқди (иловадан)' || case when n > 0 then ', ' || n || ' та товар юкланди.' else '.' end))
     from public.sellers a where a.role = 'admin' and a.status = 'active' and a.tg_chat_id is not null), '[]'::jsonb)));
  return 'ok';
end $function$;

-- админ: кўриб чиқилмаган янги товар таклифлари (дўкон ёки йиғувчи қўшган, id ≥ 1000, ҳали каталогда эмас)
CREATE OR REPLACE FUNCTION public.admin_product_proposals(p_code text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  perform public.admin_check(p_code); perform public.admin_need('catalog');
  return coalesce((select jsonb_agg(jsonb_build_object('id', p.id, 'cat', p.cat, 'name', p.name, 'spec', p.spec, 'unit', p.unit, 'base', p.base_price,
      'offers', coalesce((select jsonb_agg(jsonb_build_object('shop', coalesce(nullif(s.shop, ''), s.name), 'price', f.price) order by f.price)
                 from public.offers f join public.sellers s on s.id = f.seller_id where f.product_id = p.id), '[]'::jsonb)) order by p.id desc)
    from public.products p where not p.active and p.reviewed_at is null and p.id >= 1000), '[]'::jsonb);
end $function$;

-- админ: таклифни каталогга қўшиш ёки рад этиш (ботдаги npa / npr билан бир хил: рад этилса нархлари ўчади)
CREATE OR REPLACE FUNCTION public.admin_product_decide(p_code text, p_id integer, p_ok boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare p public.products;
begin
  perform public.admin_check(p_code); perform public.admin_need('catalog');
  select * into p from public.products where id = p_id for update;
  if not found or p.active or p.reviewed_at is not null then raise exception 'not_pending'; end if;
  update public.products set active = p_ok, reviewed_at = now() where id = p_id;
  if not p_ok then delete from public.offers where product_id = p_id; end if;
  perform public.admin_log(case when p_ok then 'product_approve' else 'product_reject' end, 'product', p_id::text, null, jsonb_build_object('name', p.name, 'active', p_ok), null);
end $function$;

revoke all on function public.admin_product_proposals(text) from public, anon;
revoke all on function public.admin_product_decide(text, integer, boolean) from public, anon;
grant execute on function public.admin_product_proposals(text) to authenticated;
grant execute on function public.admin_product_decide(text, integer, boolean) to authenticated;

commit;

-- Текшириш (алоҳида ишга туширинг):
-- select proname from pg_proc where proname in ('admin_product_proposals', 'admin_product_decide');   -- 2 қатор
-- select count(*) from public.products where not active and reviewed_at is null and id >= 1000;     -- кутилаётган таклифлар
