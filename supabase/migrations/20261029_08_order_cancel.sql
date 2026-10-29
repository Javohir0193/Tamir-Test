-- Ta'mir: админ буюртмани бекор қила олади, тўланган бўлса қайтариш (refund) автоматик яратилади.
-- Нима учун: бекор қилишнинг йўли йўқ эди; қўлда «Бекор» қайтариш яратилар, лекин буюртма йиғувчи/ҳайдовчида «тирик» қолар эди.
-- Нима ўзгаради:
--   orders.cancelled_at ва orders.cancel_reason (янги устунлар);
--   admin_order_cancel(p_code, p_no, p_reason): ҳуқуқ 'orders_edit', сабаб ≥ 3 белги, етказилган буюртмани бекор қилиб бўлмайди;
--   тўланган буюртма → pay_status 'refunded' ва кутилаётган refund (kind 'cancel', тўланган сумма минус аввалги қайтаришлар);
--   тўланмаган → pay_status 'expired' (даромад ҳисобларидан чиқади); аудит журнали; йиғувчи, ҳайдовчи ва мижозга ботда хабар.
--   drv_orders ва drv_claim: бекор қилинган буюртмани кўрсатмайди ва олдирмайди.
-- Нима ўзгармайди: мавжуд жадваллар, refund яратиш/тасдиқлаш функциялари (пул ҳаракати олдингидек admin_refund_done орқали).
-- Орқага қайтариш: 20261029_08_order_cancel.down.sql
-- Тартиб: ФАҚАТ test базада. SQL Editor'га тўлиқ қўйиб Run.

begin;

alter table public.orders add column if not exists cancelled_at timestamp with time zone;
alter table public.orders add column if not exists cancel_reason text;

CREATE OR REPLACE FUNCTION public.admin_order_cancel(p_code text, p_no bigint, p_reason text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare o public.orders; why text := btrim(coalesce(p_reason, '')); done_sum bigint := 0; amt bigint := 0; rid bigint;
        me bigint := nullif(current_setting('app.admin_id', true), '')::bigint; dms jsonb := '[]'::jsonb; cust record;
begin
  perform public.admin_check(p_code); perform public.admin_need('orders_edit');
  if length(why) < 3 then raise exception 'reason_required'; end if;
  select * into o from public.orders where no = p_no for update;
  if not found then raise exception 'unknown_key'; end if;
  if o.cancelled_at is not null then raise exception 'already_cancelled'; end if;
  if o.stage >= case o.mode when 'pickup' then 3 else 4 end then raise exception 'already_done'; end if;

  if o.pay_status = 'paid' then
    select coalesce(sum(amount), 0) into done_sum from public.refunds where order_no = p_no;
    amt := coalesce(o.pay_amount, 0) - done_sum;
    if amt > 0 then
      insert into public.refunds (order_no, kind, amount, reason, created_by) values (p_no, 'cancel', amt, left(why, 300), me) returning id into rid;
    end if;
  end if;
  update public.orders set cancelled_at = now(), cancel_reason = left(why, 300),
         pay_status = case o.pay_status when 'paid' then 'refunded' else 'expired' end
   where no = p_no;
  update public.payments set status = 'cancelled', cancelled_at = now() where order_no = p_no and status = 'created';
  perform public.admin_log('order_cancel', 'order', p_no::text, jsonb_build_object('stage', o.stage, 'pay', o.pay_status),
                           jsonb_build_object('refund', rid, 'amount', amt), why);

  -- хабарлар: йиғувчи, ҳайдовчи (ботда рус тилига ўзи ўтади), мижоз (ўз тилида)
  select coalesce(jsonb_agg(jsonb_build_object('chat_id', s.tg_chat_id, 'text', '🚫 №' || p_no || ' буюртма бекор қилинди. Сабаб: ' || why || E'\nЮкламанг, давом эттирманг.')), '[]'::jsonb)
    into dms from public.sellers s where s.id in (o.picker_id, o.driver_id) and s.tg_chat_id is not null;
  select p.tg_id, p.lang into cust from public.profiles p where p.id = o.profile_id;
  if cust.tg_id is not null then
    dms := dms || jsonb_build_array(jsonb_build_object('chat_id', cust.tg_id, 'text',
      case when cust.lang = 'ru' then '🚫 Заказ №' || p_no || ' отменён.' || case when amt > 0 then E'\nСумма ' || amt || ' сум будет возвращена.' else '' end
           else '🚫 №' || p_no || ' буюртма бекор қилинди.' || case when amt > 0 then E'\n' || amt || ' сўм қайтарилади.' else '' end end));
  end if;
  if jsonb_array_length(dms) > 0 then perform public.bot_post(jsonb_build_object('dm', dms)); end if;
  return jsonb_build_object('ok', true, 'refund_id', rid, 'refund_amount', amt);
end $function$;

-- ҳайдовчи иловаси: бекор қилинган буюртма рўйхатда кўринмайди ва олинмайди (қолган қисми ўзгармаган)
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

revoke all on function public.admin_order_cancel(text, bigint, text) from public;
grant execute on function public.admin_order_cancel(text, bigint, text) to authenticated;

commit;

-- Текшириш (алоҳида ишга туширинг):
-- select proname from pg_proc where proname = 'admin_order_cancel';   -- 1 қатор
-- select column_name from information_schema.columns where table_name = 'orders' and column_name in ('cancelled_at','cancel_reason');   -- 2 қатор
