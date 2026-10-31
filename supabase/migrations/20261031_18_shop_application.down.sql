-- Ta'mir: 20261031_18_shop_application.sql ни орқага қайтариш.
-- Диққат: янги устунлардаги маълумот (блок, қатор, дўкон рақами, карта эгаси, СТИР, бозор блоклари) ўчади.
--   row_no ва card сақланиб қолади.

begin;

drop function if exists public.admin_market_blocks(text, integer, text[]);

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

drop function if exists public.mask_card(text);
alter table public.sellers drop column if exists inn;
alter table public.sellers drop column if exists card_holder;
alter table public.sellers drop column if exists shop_no;
alter table public.sellers drop column if exists row_line;
alter table public.sellers drop column if exists block;
alter table public.markets drop column if exists blocks;

commit;
