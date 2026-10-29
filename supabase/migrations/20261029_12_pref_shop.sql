-- Ta'mir: мижоз дўкон танлайди (2-қадам): танланган дўкон нархлари буюртмага ёзилади, бот шу дўконга биринчи беради.
-- Нима учун: «мумкин қадар битта тўлиқ дўкондан олиш». Таққослаш (миграция 11) натижасидан мижоз дўконни танлайди.
-- Нима ўзгаради: orders.pref_shop (бўш бўлиши мумкин); line_price()/line_shop() ёрдамчилар; quote_order ва create_order
--   ихтиёрий p.shop_id қабул қилади (бўлмаса — аввалгидек ҳар товар энг арзон дўкондан). Танланган дўконда товар бўлмаса — энг арзон дўкондан.
-- Нима ўзгармайди: бошқа функциялар, жадваллар (фақат битта бўш устун қўшилади), рухсатлар.
-- Орқага қайтариш: 20261029_12_pref_shop.down.sql (функцияларни аввалги ҳолига қайтаради)
-- Тартиб: ФАҚАТ test базада; миграция 11 дан кейин.

begin;

alter table public.orders add column if not exists pref_shop bigint;

-- Танланган дўконнинг нархи (бор ва фаол бўлса), бўлмаса бозордаги энг арзон нарх.
create or replace function public.line_price(p_market int, p_product int, p_shop bigint)
 returns bigint language sql stable security definer set search_path to 'public'
as $function$
  select coalesce(
    (select o.price from public.offers o join public.sellers s on s.id = o.seller_id
      where p_shop is not null and o.seller_id = p_shop and o.product_id = p_product and o.in_stock
        and s.status = 'active' and s.role = 'seller' and (s.market_id = p_market or s.market_id is null)),
    (select cm.best_price from public.catalog_market cm where cm.market_id = p_market and cm.id = p_product))
$function$;
create or replace function public.line_shop(p_market int, p_product int, p_shop bigint)
 returns text language sql stable security definer set search_path to 'public'
as $function$
  select coalesce(
    (select s.shop from public.offers o join public.sellers s on s.id = o.seller_id
      where p_shop is not null and o.seller_id = p_shop and o.product_id = p_product and o.in_stock
        and s.status = 'active' and s.role = 'seller' and (s.market_id = p_market or s.market_id is null)),
    (select cm.best_shop from public.catalog_market cm where cm.market_id = p_market and cm.id = p_product))
$function$;
revoke all on function public.line_price(int, int, bigint) from public;
revoke all on function public.line_shop(int, int, bigint) from public;

CREATE OR REPLACE FUNCTION public.quote_order(p jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_shop bigint; v_mk int; v_goods bigint := 0; v_nop int := 0; v_kg numeric := 0; v_mode text := coalesce(p->>'mode', 'delivery');
        v_lat double precision; v_lng double precision; v_m jsonb; v_out jsonb; v_res bigint := 0;
begin
  begin v_mk := nullif(p->>'market_id', '')::int; exception when others then v_mk := null; end;
  begin v_shop := nullif(p->>'shop_id', '')::bigint; exception when others then v_shop := null; end;
  begin v_lat := (p->>'lat')::double precision; v_lng := (p->>'lng')::double precision; exception when others then v_lat := null; v_lng := null; end;
  if v_mode not in ('delivery', 'pickup', 'car') then v_mode := 'delivery'; end if;
  if v_mode = 'car' then
    v_m := public.order_money('car', 0, 0, v_mk, v_lat, v_lng, p->>'zone', p->>'car', p->>'provider');
    v_out := v_m || jsonb_build_object('nop', 0);
  else
    select coalesce(sum(round(coalesce(public.line_price(v_mk, q.id, v_shop), 0) * q.q)), 0), count(*) filter (where public.line_price(v_mk, q.id, v_shop) is null),
           coalesce(sum(q.q * coalesce(pr.weight_kg, 1)), 0)
      into v_goods, v_nop, v_kg
    from (select (e->>'id')::int as id, sum(round((e->>'q')::numeric, 2)) as q from jsonb_array_elements(coalesce(p->'items', '[]')) e group by 1) q
    left join public.products pr on pr.id = q.id
    ;
    v_m := public.order_money(v_mode, v_goods, v_kg, v_mk, v_lat, v_lng, p->>'zone', nullif(p->>'body', ''), p->>'provider');
    v_out := v_m || jsonb_build_object('nop', v_nop, 'min_order', public.fs('min_order'),
      'short', case when v_nop = 0 then greatest(public.fs('min_order') - v_goods, 0) else 0 end);
    if coalesce((select value from public.app_settings where key = 'payments_on'), 'false') = 'true' then
      v_res := round(v_goods * coalesce((select value::numeric from public.app_settings where key = 'reserve_pct'), 5) / 100);
    end if;
  end if;
  return v_out || jsonb_build_object('reserve', v_res, 'pay_total', (v_m->>'total')::bigint + v_res);
end $function$;

CREATE OR REPLACE FUNCTION public.create_order(p jsonb)
 RETURNS orders
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_pid bigint := public.my_profile_id();
  v_mode text := coalesce(p->>'mode', '');
  v_shop bigint; v_mk int; v_name text; v_phone text; v_addr text; v_note text; v_slot text;
  v_lat double precision; v_lng double precision;
  v_items jsonb := '[]'::jsonb; v_goods bigint := 0; v_kg numeric := 0; v_nop int := 0;
  v_car public.delivery_tariffs; v_m jsonb; r record; n int := 0; v_row public.orders;
begin
  if v_uid is null then raise exception 'no_session' using errcode = '28000'; end if;
  if coalesce((select value from public.app_settings where key = 'require_login'), 'true') = 'true' and v_pid is null then
    raise exception 'login_required' using errcode = '28000';
  end if;
  if (select count(*) from public.orders where user_id = v_uid and created_at > now() - interval '1 hour')
     >= coalesce((select value::int from public.app_settings where key = 'orders_per_hour'), 10) then
    raise exception 'too_many' using errcode = '54000';
  end if;
  if v_mode not in ('delivery', 'pickup', 'car') then raise exception 'bad_mode'; end if;

  v_name  := left(trim(coalesce(p->>'name', '')), 60);
  v_phone := left(trim(coalesce(p->>'phone', '')), 30);
  v_addr  := nullif(left(trim(coalesce(p->>'address', '')), 300), '');
  v_note  := nullif(left(trim(coalesce(p->>'note', '')), 500), '');
  v_slot  := nullif(left(trim(coalesce(p->>'slot', '')), 60), '');
  if v_name = '' then raise exception 'name_required'; end if;
  if length(regexp_replace(v_phone, '\D', '', 'g')) < 9 then raise exception 'phone_required'; end if;
  if v_mode in ('delivery', 'car') and v_addr is null then raise exception 'address_required'; end if;
  if v_mode = 'pickup' then v_addr := null; end if;
  begin
    v_lat := (p->>'lat')::double precision; v_lng := (p->>'lng')::double precision;
  exception when others then v_lat := null; v_lng := null; end;
  if v_lat is null or v_lng is null or v_lat not between 36 and 46 or v_lng not between 55 and 74 or v_mode = 'pickup' then
    v_lat := null; v_lng := null;
  end if;
  begin v_shop := nullif(p->>'shop_id', '')::bigint; exception when others then v_shop := null; end;
  begin v_mk := nullif(p->>'market_id', '')::int; exception when others then v_mk := null; end;
  if v_mk is not null and not exists (select 1 from public.markets where id = v_mk and active) then raise exception 'bad_market'; end if;

  if v_mode = 'car' then
    select * into v_car from public.delivery_tariffs where id = p->>'car' and active;
    if not found then raise exception 'bad_car'; end if;
    v_m := public.order_money('car', 0, 0, v_mk, v_lat, v_lng, p->>'zone', v_car.id, p->>'provider');
    v_items := jsonb_build_array(jsonb_build_object('id', null, 'n', 'Машина до ' || v_car.cap_kg || ' кг',
                 'q', 1, 'u', 'рейс', 'price', (v_m->>'delivery')::bigint, 'w', false, 'car', v_car.id));
  else
    if v_mk is null then raise exception 'market_required'; end if;
    if jsonb_typeof(p->'items') <> 'array' or jsonb_array_length(p->'items') = 0 then raise exception 'empty_cart'; end if;
    if jsonb_array_length(p->'items') > 100 then raise exception 'too_many_items'; end if;

    for r in
      with req as (
        select (e->>'id')::int as id, sum(round((e->>'q')::numeric, 2)) as q
        from jsonb_array_elements(p->'items') e group by 1
      )
      select req.id, req.q, pr.name, pr.unit, pr.active, pr.weight_kg, public.line_price(v_mk, req.id, v_shop) as best_price, public.line_shop(v_mk, req.id, v_shop) as best_shop
      from req left join public.products pr on pr.id = req.id
      order by req.id
    loop
      if r.name is null or not r.active then raise exception 'unknown_product %', r.id; end if;
      if r.q is null or r.q <= 0 or r.q > 100000 then raise exception 'bad_qty %', r.id; end if;
      n := n + 1;
      v_items := v_items || jsonb_build_object('id', r.id, 'n', r.name, 'q', r.q, 'u', r.unit,
                   'price', coalesce(r.best_price, 0), 'shop', r.best_shop, 'w', false, 'nop', r.best_price is null);
      v_goods := v_goods + round(coalesce(r.best_price, 0) * r.q);
      v_kg := v_kg + r.q * coalesce(r.weight_kg, 1);
      if r.best_price is null then v_nop := v_nop + 1; end if;
    end loop;
    -- минимал буюртма (нархи аниқланмаган товар бўлса суммани билмаймиз — текширмаймиз)
    if v_nop = 0 and v_goods < public.fs('min_order') then raise exception 'min_order'; end if;
    v_m := public.order_money(v_mode, v_goods, v_kg, v_mk, v_lat, v_lng, p->>'zone', nullif(p->>'body', ''), p->>'provider');
  end if;

  insert into public.orders (pref_shop, user_id, profile_id, market_id, customer_name, phone, address, note, mode, slot, total, goods, work,
                             times, items, delivery_lat, delivery_lng,
                             goods_sum, delivery_sum, service_fee, collector_fee, driver_fee, gateway_pct, gateway_fee, platform_income,
                             zone, body, trips, weight_kg, provider)
  values (case when v_mode = 'car' then null else v_shop end, v_uid, v_pid, v_mk, v_name, v_phone, v_addr, v_note, v_mode,
          case when v_mode = 'car' then coalesce(v_slot, 'Как можно скорее') else v_slot end,
          (v_m->>'total')::bigint, v_mode <> 'car', false,
          jsonb_build_array((extract(epoch from now()) * 1000)::bigint), v_items, v_lat, v_lng,
          (v_m->>'goods')::bigint, (v_m->>'delivery')::bigint, (v_m->>'service')::bigint, (v_m->>'collector_fee')::bigint,
          (v_m->>'driver_fee')::bigint, (v_m->>'gateway_pct')::numeric, (v_m->>'gateway_fee')::bigint, (v_m->>'platform')::bigint,
          v_m->>'zone', v_m->>'body', (v_m->>'trips')::int, (v_m->>'kg')::numeric, v_m->>'provider')
  returning * into v_row;
  perform public.ledger_rebook(v_row.no);
  return v_row;
end $function$;

commit;
