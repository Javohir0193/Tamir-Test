-- Ta'mir: аризалар тартиби (дўкон, йиғувчи, ҳайдовчи).
-- Нима учун: «Одамлар» бўлимида янги ариза буюртма сони бўйича саралангани учун энг пастга тушиб қоларди;
--   ботда рол танланган заҳоти (телефон ҳам юборилмасдан) ариза «Кутилмоқда» бўлиб кўринар ва ҳисобга кирарди;
--   чала аризани панелдан тасдиқлаб юбориш мумкин эди; панелдан тасдиқланганда илова тугмаси қўйилмасди.
-- Нима ўзгаради:
--   admin_people: ҳар қаторга 'created' ва 'step' қўшилди; янги 'apps' (тўлиқ аризалар, энг эскиси биринчи)
--     ва 'unfinished' (чала аризалар, охирги 50 та) рўйхатлари. Эски 'collectors', 'drivers', 'shops' ўзгармади.
--   admin_dashboard: 'pending_people' фақат тўлиқ юборилган аризаларни санайди.
--   admin_person_set: чала аризани тасдиқлаш 'not_finished' хато беради; тасдиқда ботга 'welcome' юборилади.
-- Нима ўзгармайди: жадваллар, маълумотлар, функциялар номи ва параметрлари.
-- Орқага қайтариш: 20261031_17_applications_order.down.sql
-- Тартиб: SQL Editor'га тўлиқ қўйиб Run. Ботни ҳам янгиланг (welcome учун), эски бот ҳам ишлайверади.

begin;

CREATE OR REPLACE FUNCTION public.admin_dashboard(p_code text, p_days integer DEFAULT 7)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare d int := least(greatest(coalesce(p_days, 7), 1), 90); since timestamptz; r jsonb;
begin
  perform public.admin_check(p_code);
  perform public.admin_alert_scan();
  since := now() - make_interval(days => d);
  select jsonb_build_object(
    'days', d,
    'orders', (select jsonb_build_object(
        'total', count(*), 'paid', count(*) filter (where pay_status = 'paid'), 'unpaid', count(*) filter (where pay_status = 'unpaid'),
        'expired', count(*) filter (where pay_status = 'expired'),
        'sum', coalesce(sum(total) filter (where pay_status in ('paid', 'none')), 0),
        'avg', coalesce(round(avg(total) filter (where pay_status in ('paid', 'none'))), 0),
        'delivered', count(*) filter (where stage >= 4),
        'platform', coalesce(sum(platform_income) filter (where pay_status in ('paid', 'none')), 0)) from public.orders where created_at >= since),
    'today', (select jsonb_build_object('orders', count(*), 'paid', count(*) filter (where pay_status in ('paid', 'none')),
        'sum', coalesce(sum(total) filter (where pay_status in ('paid', 'none')), 0)) from public.orders where created_at >= date_trunc('day', now())),
    'by_stage', coalesce((select jsonb_object_agg(stage::text, n) from (select stage, count(*) n from public.orders where pay_status in ('paid', 'none') and stage < 4 group by stage) s), '{}'::jsonb),
    'funnel', coalesce((select jsonb_object_agg(kind, jsonb_build_object('n', n, 'people', p)) from
        (select kind, count(*) n, count(distinct anon) p from public.events where at >= since group by kind) e), '{}'::jsonb),
    'visitors', (select count(distinct anon) from public.events where at >= since),
    'new_customers', (select count(*) from public.profiles where created_at >= since),
    'customers', (select count(*) from public.profiles),
    'searches_empty', coalesce((select jsonb_agg(x) from (select props->>'q' as q, count(*) n from public.events
        where kind = 'search' and at >= since and coalesce((props->>'n')::int, 0) = 0 group by 1 order by 2 desc limit 10) x), '[]'::jsonb),
    'top_searches', coalesce((select jsonb_agg(x) from (select props->>'q' as q, count(*) n from public.events
        where kind = 'search' and at >= since group by 1 order by 2 desc limit 10) x), '[]'::jsonb),
    'refunds_pending', (select count(*) from public.refunds where status = 'pending'),
    'payouts_pending', (select jsonb_build_object('n', count(*), 'sum', coalesce(sum(total), 0), 'oldest_min', coalesce(max((extract(epoch from now() - created_at) / 60)::int), 0))
                        from public.purchases where status = 'pending'),
    'pending_people', (select count(*) from public.sellers where status = 'pending' and reg_step is null and role in ('seller', 'collector', 'driver')),
    'alerts', public.admin_alerts_json()
  ) into r;
  if public.admin_can('money') then
    r := r || jsonb_build_object('money', (select jsonb_build_object(
        'in', coalesce(sum(amount) filter (where kind = 'customer_payment'), 0), 'shops', coalesce(-sum(amount) filter (where kind = 'shop_goods'), 0),
        'drivers', coalesce(-sum(amount) filter (where kind = 'driver_pay'), 0), 'collectors', coalesce(-sum(amount) filter (where kind = 'collector_pay'), 0),
        'gateway', coalesce(-sum(amount) filter (where kind = 'gateway_fee'), 0), 'platform', coalesce(-sum(amount) filter (where kind = 'platform_income'), 0),
        'reserve', coalesce(-sum(amount) filter (where kind = 'reserve_hold'), 0), 'refunds', coalesce(sum(amount) filter (where kind = 'refund'), 0),
        'sum_all', coalesce(sum(amount), 0)) from public.ledger));
  else
    r := jsonb_set(r, '{orders}', (r->'orders') - 'sum' - 'avg' - 'platform') ;
    r := jsonb_set(r, '{today}', (r->'today') - 'sum');
  end if;
  return r;
end $function$;

CREATE OR REPLACE FUNCTION public.admin_people(p_code text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare ph boolean;
begin
  perform public.admin_check(p_code); ph := public.admin_can('phones');
  return jsonb_build_object(
    'collectors', coalesce((select jsonb_agg(x order by (x->>'orders')::int desc) from (
        select jsonb_build_object('id', s.id, 'name', s.name, 'phone', case when ph then s.phone else public.mask_phone(s.phone) end, 'status', s.status, 'reason', s.block_reason, 'created', s.created_at, 'step', s.reg_step,
               'orders', count(o.no), 'earned', coalesce(sum(o.collector_fee), 0)) x
        from public.sellers s left join public.orders o on o.picker_id = s.id and o.pay_status in ('paid', 'none')
        where s.role = 'collector' group by s.id) q), '[]'::jsonb),
    'drivers', coalesce((select jsonb_agg(x order by (x->>'orders')::int desc) from (
        select jsonb_build_object('id', s.id, 'name', s.name, 'phone', case when ph then s.phone else public.mask_phone(s.phone) end, 'status', s.status, 'reason', s.block_reason, 'created', s.created_at, 'step', s.reg_step, 'car', s.car,
               'orders', count(o.no), 'earned', coalesce(sum(coalesce(o.delivery_sum, 0) - coalesce(o.driver_fee, 0)), 0)) x
        from public.sellers s left join public.orders o on o.driver_id = s.id and o.pay_status in ('paid', 'none')
        where s.role = 'driver' group by s.id) q), '[]'::jsonb),
    'shops', coalesce((select jsonb_agg(x order by (x->>'sold')::bigint desc) from (
        select jsonb_build_object('id', s.id, 'name', s.name, 'shop', s.shop, 'row', s.row_no, 'status', s.status, 'reason', s.block_reason, 'created', s.created_at, 'step', s.reg_step,
               'phone', case when ph then s.phone else public.mask_phone(s.phone) end, 'card', s.card,
               'prices', (select count(*) from public.offers f where f.seller_id = s.id),
               'sold', coalesce(sum(p.total) filter (where p.status in ('pending', 'paid')), 0), 'paid', coalesce(sum(p.total) filter (where p.status = 'paid'), 0)) x
        from public.sellers s left join public.purchases p on p.shop_id = s.id
        where s.role = 'seller' group by s.id) q), '[]'::jsonb),
    -- тўлиқ юборилган аризалар: энг эскиси биринчи (навбат)
    'apps', coalesce((select jsonb_agg(jsonb_build_object('id', s.id, 'role', s.role, 'name', s.name, 'shop', s.shop, 'row', s.row_no,
               'phone', case when ph then s.phone else public.mask_phone(s.phone) end, 'market', m.name, 'car', s.car, 'license', s.license_no,
               'has_photo', s.license_photo is not null, 'cats', coalesce(array_length(s.categories, 1), 0), 'created', s.created_at) order by s.created_at, s.id)
        from public.sellers s left join public.markets m on m.id = s.market_id
        where s.status = 'pending' and s.reg_step is null and s.role in ('seller', 'collector', 'driver')), '[]'::jsonb),
    -- чала аризалар (бот ёки register.html да тугалланмаган): тасдиқлаб бўлмайди, фақат кўриш учун
    'unfinished', coalesce((select jsonb_agg(x order by (x->>'created') desc) from (
        select jsonb_build_object('id', s.id, 'role', s.role, 'name', s.name, 'step', s.reg_step,
               'phone', case when ph then s.phone else public.mask_phone(s.phone) end, 'created', s.created_at) x
        from public.sellers s
        where s.status = 'pending' and s.reg_step is not null and s.role in ('seller', 'collector', 'driver')
        order by s.created_at desc limit 50) q), '[]'::jsonb));
end $function$;

CREATE OR REPLACE FUNCTION public.admin_person_set(p_code text, p_id bigint, p_status text, p_reason text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare s public.sellers;
begin
  perform public.admin_check(p_code); perform public.admin_need('people');
  if p_status not in ('active', 'blocked', 'pending') then raise exception 'bad_value'; end if;
  if p_status = 'blocked' and (p_reason is null or length(trim(p_reason)) < 3) then raise exception 'reason_required'; end if;
  select * into s from public.sellers where id = p_id and role <> 'admin';
  if not found then raise exception 'unknown_key'; end if;
  if p_status = 'active' and s.status = 'pending' and s.reg_step is not null then raise exception 'not_finished'; end if;
  update public.sellers set status = p_status, block_reason = case when p_status = 'blocked' then left(p_reason, 300) else null end where id = p_id;
  perform public.admin_log('person_' || p_status, s.role, p_id::text, jsonb_build_object('status', s.status), jsonb_build_object('status', p_status), p_reason);
  if s.tg_chat_id is not null then
    -- welcome: янги бот аризачига ботдаги ✅ билан бир хил хабар ва илова тугмасини юборади; эски бот text ни юборади
    perform public.bot_post(jsonb_build_object('dm', jsonb_build_array(jsonb_build_object('chat_id', s.tg_chat_id,
      'welcome', case when p_status = 'active' and s.status = 'pending' then p_id end,
      'text', case p_status when 'active' then '✅ Аризангиз тасдиқланди. Ботда /start босинг.' when 'blocked' then '⛔ Ҳисобингиз блокланди. Сабаб: ' || coalesce(p_reason, '') else 'ℹ️ Ҳолатингиз ўзгарди.' end))));
  end if;
end $function$;

commit;
