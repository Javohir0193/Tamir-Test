-- Ta'mir: 20261031_21_staff_accrual.sql ни орқага қайтариш: staff_account 20-миграциядаги ҳолатга қайтади.
begin;

CREATE OR REPLACE FUNCTION public.staff_account(p_seller bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare s public.sellers; r jsonb;
begin
  select * into s from public.sellers where id = p_seller;
  if not found or s.role not in ('collector', 'driver') then return null; end if;
  if s.role = 'driver' then
    select jsonb_build_object('role', 'driver', 'orders', count(*),
             'gross', coalesce(sum(coalesce(o.delivery_sum, 0)), 0),
             'platform', coalesce(sum(coalesce(o.driver_fee, 0)), 0),
             'net', coalesce(sum(coalesce(o.delivery_sum, 0) - coalesce(o.driver_fee, 0)), 0),
             'pct', coalesce(public.fs('driver_pct'), 0))
      into r from public.orders o
      where o.driver_id = s.id and o.pay_status in ('paid', 'none')
        and o.stage >= case o.mode when 'pickup' then 3 else 4 end;
  else
    select jsonb_build_object('role', 'collector', 'orders', count(*),
             'gross', coalesce(sum(q.base), 0),
             'platform', coalesce(sum(greatest(q.base - q.cf, 0)), 0),
             'net', coalesce(sum(q.cf), 0),
             'pct', coalesce(public.fs('collector_share'), 0))
      into r from (
        select coalesce(o.collector_fee, 0) cf,
               case when o.mode = 'car' then 0 else round(coalesce(public.fs('fixed_fee'), 0) + public.tier_amount(coalesce(o.goods_sum, 0))) end base
        from public.orders o
        where o.picker_id = s.id and o.pay_status in ('paid', 'none')
          and o.stage >= case o.mode when 'pickup' then 3 else 4 end) q;
  end if;
  return r;
end $function$;

commit;
