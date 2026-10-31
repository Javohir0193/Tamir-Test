-- Ta'mir: «ҳисобланди» → «тасдиқланди» → «ўтказилди». Тасдиқ: мижоз «Олдим» босганда (ёки админ қўйиб юборганда, ёки етказилгандан кейин payout_hold_hours соат ўтса — мавжуд қоида).
-- Нима ўзгаради:
--   order_confirm_states(p_nos): буюртмалар ҳолати {no: 'free' тасдиқланган | 'wait' кутилмоқда | 'hold' мижоз эътироз билдирган}; етказилмаган буюртма доим 'wait'. Фақат сервер (бот) чақиради.
--   staff_account: JSON га confirmed (тасдиқланган), waiting, held ва due (тасдиқланган − ўтказилган) қўшилади. Эски майдонлар қолади.
-- Нима ўзгармайди: жадваллар, order_payout_state, staff_balance_v, админ ҳақ тўлаши.
-- Орқага қайтариш: 20261031_22_confirm_states.down.sql
-- Тартиб: 20 ва 21 дан кейин. SQL Editor'га тўлиқ қўйиб Run.

begin;

CREATE OR REPLACE FUNCTION public.order_confirm_states(p_nos bigint[])
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce(jsonb_object_agg(o.no::text,
           case when o.stage >= case o.mode when 'pickup' then 3 else 4 end then public.order_payout_state(o) else 'wait' end), '{}'::jsonb)
  from public.orders o where o.no = any(p_nos)
$function$;

CREATE OR REPLACE FUNCTION public.staff_account(p_seller bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare s public.sellers; r jsonb; paid bigint;
begin
  select * into s from public.sellers where id = p_seller;
  if not found or s.role not in ('collector', 'driver') then return null; end if;
  select coalesce(sum(amount), 0) into paid from public.staff_payouts where seller_id = s.id;
  if s.role = 'driver' then
    select jsonb_build_object('role', 'driver', 'orders', count(*),
             'gross', coalesce(sum(q.gross), 0), 'platform', coalesce(sum(q.plat), 0), 'net', coalesce(sum(q.amt), 0),
             'accrued', coalesce(sum(q.amt), 0), 'paid', paid, 'balance', coalesce(sum(q.amt), 0) - paid,
             'confirmed', coalesce(sum(q.amt) filter (where q.st = 'free'), 0),
             'waiting', coalesce(sum(q.amt) filter (where q.st = 'wait'), 0),
             'held', coalesce(sum(q.amt) filter (where q.st = 'hold'), 0),
             'due', coalesce(sum(q.amt) filter (where q.st = 'free'), 0) - paid,
             'pct', coalesce(public.fs('driver_pct'), 0))
      into r from (
        select coalesce(o.delivery_sum, 0) gross, coalesce(o.driver_fee, 0) plat, coalesce(o.delivery_sum, 0) - coalesce(o.driver_fee, 0) amt,
               public.order_payout_state(o) st
        from public.orders o
        where o.driver_id = s.id and o.pay_status in ('paid', 'none')
          and o.stage >= case o.mode when 'pickup' then 3 else 4 end) q;
  else
    select jsonb_build_object('role', 'collector', 'orders', count(*),
             'gross', coalesce(sum(q.base), 0), 'platform', coalesce(sum(greatest(q.base - q.cf, 0)), 0), 'net', coalesce(sum(q.cf), 0),
             'accrued', coalesce(sum(q.cf), 0), 'paid', paid, 'balance', coalesce(sum(q.cf), 0) - paid,
             'confirmed', coalesce(sum(q.cf) filter (where q.st = 'free'), 0),
             'waiting', coalesce(sum(q.cf) filter (where q.st = 'wait'), 0),
             'held', coalesce(sum(q.cf) filter (where q.st = 'hold'), 0),
             'due', coalesce(sum(q.cf) filter (where q.st = 'free'), 0) - paid,
             'pct', coalesce(public.fs('collector_share'), 0))
      into r from (
        select coalesce(o.collector_fee, 0) cf,
               case when o.mode = 'car' then 0 else round(coalesce(public.fs('fixed_fee'), 0) + public.tier_amount(coalesce(o.goods_sum, 0))) end base,
               case when o.stage >= case o.mode when 'pickup' then 3 else 4 end then public.order_payout_state(o) else 'wait' end st
        from public.orders o
        where o.picker_id = s.id and o.pay_status in ('paid', 'none') and o.stage >= 2) q;
  end if;
  return r;
end $function$;

revoke all on function public.order_confirm_states(bigint[]) from public, anon, authenticated;
grant execute on function public.order_confirm_states(bigint[]) to service_role;

commit;
