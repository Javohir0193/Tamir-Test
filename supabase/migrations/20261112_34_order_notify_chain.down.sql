-- 34 ни орқага қайтариш: orders_push_notify 27-миграциядаги ҳолига қайтади, ҳайдовчи → йиғувчи триггери ўчади.
begin;
drop trigger if exists orders_driver on public.orders;
drop function if exists public.orders_driver_notify();

CREATE OR REPLACE FUNCTION public.orders_push_notify()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare st text;
begin
  st := case
    when new.cancelled_at is not null and old.cancelled_at is null then 'cancelled'
    when new.stage is distinct from old.stage and new.stage = 1 then 'collecting'
    when new.stage is distinct from old.stage and new.stage = 2 then 'ready'
    when new.stage is distinct from old.stage and new.stage = 3 then 'on_way'
    when new.stage is distinct from old.stage and new.stage = 4 then 'delivered'
    when new.pay_status = 'paid' and old.pay_status is distinct from 'paid' then 'paid'
  end;
  if st is null then return new; end if;
  if not exists (select 1 from public.push_subs where app = 'shop'
                  and (user_id = new.user_id or (new.profile_id is not null and profile_id = new.profile_id))) then
    return new;
  end if;
  begin
    perform public.bot_post(jsonb_build_object('push_order', new.no, 'st', st));
  exception when others then
    raise warning 'orders_push_notify: %', sqlerrm;      -- push бўлмаса ҳам буюртма ўзгариши тўхтамайди
  end;
  return new;
end $function$;

revoke all on function public.orders_push_notify() from public, anon, authenticated;
commit;
