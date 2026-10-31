-- Ta'mir: дўкон аризаси янги тартибда: Ф.И.Ш → бозор → бозор ичидаги блок/бино → қатор → дўкон рақами → карта.
-- Нима учун: платформа дўконга материал пулини картага ўтказади; дўкон жойи аниқ (блок, қатор, рақам) бўлиши керак.
-- Нима ўзгаради:
--   markets.blocks (text[], бўш бўлиши мумкин): бозор ичидаги блок ёки бинолар рўйхати. Бўш бўлса, формада қўлда ёзилади.
--   sellers: block, row_line, shop_no, card_holder, inn устунлари (ҳаммаси бўш бўлиши мумкин, эски дўконларга таъсир йўқ).
--     row_no аввалгидек тўлдирилади ("Блок · N-қатор · M-дўкон"), шунинг учун уни ишлатадиган жойлар ўзгармайди.
--   mask_card(): картанинг фақат охирги 4 рақамини кўрсатади. admin_people'да карта энди маскаланган
--     (тўлиқ рақам фақат «Тўловлар» бўлимида, payout ҳуқуқи бор админга кўринади, аввалгидек).
--   admin_people: 'apps' га block, row_line, shop_no, card (маскаланган), card_holder, inn; янги 'markets' рўйхати.
--   admin_market_blocks(p_code, p_id, p_blocks): бозор блокларини сақлаш ('people' ҳуқуқи, аудит журналига ёзилади).
-- Нима ўзгармайди: мавжуд маълумотлар, бошқа функциялар ва API'лар.
-- Орқага қайтариш: 20261031_18_shop_application.down.sql
-- Тартиб: 17 дан кейин. SQL Editor'га тўлиқ қўйиб Run.

begin;

alter table public.markets add column if not exists blocks text[] not null default '{}'::text[];
alter table public.sellers add column if not exists block text;
alter table public.sellers add column if not exists row_line text;
alter table public.sellers add column if not exists shop_no text;
alter table public.sellers add column if not exists card_holder text;
alter table public.sellers add column if not exists inn text;

CREATE OR REPLACE FUNCTION public.mask_card(p text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
  select case when p is null or btrim(p) = '' then null
              else '•••• ' || right(regexp_replace(p, '\D', '', 'g'), 4) end
$function$;

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
               'phone', case when ph then s.phone else public.mask_phone(s.phone) end, 'card', public.mask_card(s.card),
               'prices', (select count(*) from public.offers f where f.seller_id = s.id),
               'sold', coalesce(sum(p.total) filter (where p.status in ('pending', 'paid')), 0), 'paid', coalesce(sum(p.total) filter (where p.status = 'paid'), 0)) x
        from public.sellers s left join public.purchases p on p.shop_id = s.id
        where s.role = 'seller' group by s.id) q), '[]'::jsonb),
    -- тўлиқ юборилган аризалар: энг эскиси биринчи (навбат)
    'apps', coalesce((select jsonb_agg(jsonb_build_object('id', s.id, 'role', s.role, 'name', s.name, 'shop', s.shop, 'row', s.row_no,
               'phone', case when ph then s.phone else public.mask_phone(s.phone) end, 'market', m.name, 'car', s.car, 'license', s.license_no,
               'has_photo', s.license_photo is not null, 'cats', coalesce(array_length(s.categories, 1), 0), 'created', s.created_at,
               'block', s.block, 'row_line', s.row_line, 'shop_no', s.shop_no, 'card', public.mask_card(s.card), 'card_holder', s.card_holder, 'inn', s.inn) order by s.created_at, s.id)
        from public.sellers s left join public.markets m on m.id = s.market_id
        where s.status = 'pending' and s.reg_step is null and s.role in ('seller', 'collector', 'driver')), '[]'::jsonb),
    -- чала аризалар (бот ёки register.html да тугалланмаган): тасдиқлаб бўлмайди, фақат кўриш учун
    'unfinished', coalesce((select jsonb_agg(x order by (x->>'created') desc) from (
        select jsonb_build_object('id', s.id, 'role', s.role, 'name', s.name, 'step', s.reg_step,
               'phone', case when ph then s.phone else public.mask_phone(s.phone) end, 'created', s.created_at) x
        from public.sellers s
        where s.status = 'pending' and s.reg_step is not null and s.role in ('seller', 'collector', 'driver')
        order by s.created_at desc limit 50) q), '[]'::jsonb),
    -- бозорлар ва ичидаги блок/бинолар (ариза формасида танланади)
    'markets', coalesce((select jsonb_agg(jsonb_build_object('id', m.id, 'name', m.name, 'blocks', m.blocks) order by m.sort, m.id)
        from public.markets m where m.active), '[]'::jsonb));
end $function$;

CREATE OR REPLACE FUNCTION public.admin_market_blocks(p_code text, p_id integer, p_blocks text[])
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare old text[]; nb text[];
begin
  perform public.admin_check(p_code); perform public.admin_need('people');
  select coalesce(array_agg(b order by ord), '{}') into nb from (
    select distinct on (lower(b)) b, ord from (select left(btrim(x), 40) b, ord from unnest(coalesce(p_blocks, '{}')) with ordinality u(x, ord)) z
    where b <> '' order by lower(b), ord) q;
  if array_length(nb, 1) > 100 then raise exception 'too_many_rows'; end if;
  select blocks into old from public.markets where id = p_id;
  if not found then raise exception 'unknown_key'; end if;
  update public.markets set blocks = nb where id = p_id;
  perform public.admin_log('market_blocks', 'market', p_id::text, jsonb_build_object('blocks', old), jsonb_build_object('blocks', nb), null);
end $function$;

revoke all on function public.admin_market_blocks(text, integer, text[]) from public;
grant execute on function public.admin_market_blocks(text, integer, text[]) to authenticated;
revoke all on function public.mask_card(text) from public;
grant execute on function public.mask_card(text) to authenticated;

commit;
