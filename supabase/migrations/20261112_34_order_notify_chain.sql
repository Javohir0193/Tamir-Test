-- Ta'mir: буюртма хабарлари қатъий занжир бўйича: мижоз → дўкон → йиғувчи → ҳайдовчи → мижоз.
-- Нима учун: мижоз ички босқичлар ҳақида ҳам push оларди («йиғилмоқда», «ҳайдовчи кутилмоқда»), Telegram орқали кирган
--   мижозга эса «йўлда» ва «етказилди» умуман бормасди; ҳайдовчи буюртмани олганда йиғувчи кимга топширишини билмасди.
-- Нима ўзгаради:
--   orders_push_notify: мижозга фақат ўзига тегишли босқичлар — тўланди, (машина) ҳайдовчи топилди, (олиб кетиш) тайёр,
--     йўлда, етказилди, бекор. 1 (тасдиқланди) ва 2 (паркда) босқичлари мижозга юборилмайди.
--     Ботга хабар push обунаси бўлса ЁКИ мижоз Telegram орқали кирган бўлса кетади (бот Telegram'га ҳам ёзади).
--   orders_driver_notify (янги триггер): етказиш буюртмасига ҳайдовчи тайинланса (бот, ҳайдовчи иловаси ёки админ панел —
--     қаердан бўлса ҳам, бир жойда) → бот йиғувчига «ҳайдовчи X · тел · машина, унга топширинг» деб ёзади.
-- Нима ўзгармайди: жадваллар, мавжуд API функциялари, админ хабарлари.
-- Тартиб: аввал tg-bot'нинг янги версиясини деплой қилинг (push_order'да Telegram ва driver_set), кейин шу файл.
--   Эски бот driver_set'ни танимайди ва зарарсиз ўтказиб юборади.
-- Орқага қайтариш: 20261112_34_order_notify_chain.down.sql
-- SQL Editor'га тўлиқ қўйиб Run.

begin;

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
    when new.stage is distinct from old.stage and new.stage = 1 and new.mode = 'car' then 'driver_found'
    when new.stage is distinct from old.stage and new.stage = 3 and new.mode = 'pickup' then 'pickup_ready'
    when new.stage is distinct from old.stage and new.stage = 3 then 'on_way'
    when new.stage is distinct from old.stage and new.stage = 4 then 'delivered'
    when new.pay_status = 'paid' and old.pay_status is distinct from 'paid' then 'paid'
  end;
  if st is null then return new; end if;
  -- push обунаси бор, ёки (Telegram хабари керак бўлган босқич ва) мижоз Telegram орқали кирган
  if not exists (select 1 from public.push_subs where app = 'shop'
                  and (user_id = new.user_id or (new.profile_id is not null and profile_id = new.profile_id)))
     and not (st in ('driver_found', 'pickup_ready', 'on_way', 'delivered')
              and exists (select 1 from public.profiles p where p.id = new.profile_id and p.tg_id is not null)) then
    return new;
  end if;
  begin
    perform public.bot_post(jsonb_build_object('push_order', new.no, 'st', st));
  exception when others then
    raise warning 'orders_push_notify: %', sqlerrm;      -- хабар бўлмаса ҳам буюртма ўзгариши тўхтамайди
  end;
  return new;
end $function$;

-- Ҳайдовчи тайинланди → йиғувчига хабар (бот ёзади). Фақат етказиш буюртмаси, йиғувчи бор ва ҳайдовчи бошқа одам.
CREATE OR REPLACE FUNCTION public.orders_driver_notify()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if new.driver_id is null or new.driver_id is not distinct from old.driver_id
     or new.picker_id is null or new.picker_id = new.driver_id
     or new.mode <> 'delivery' or new.cancelled_at is not null or new.stage >= 3 then
    return new;
  end if;
  begin
    perform public.bot_post(jsonb_build_object('driver_set', new.no));
  exception when others then
    raise warning 'orders_driver_notify: %', sqlerrm;
  end;
  return new;
end $function$;

drop trigger if exists orders_driver on public.orders;
create trigger orders_driver after update of driver_id on public.orders
  for each row execute function public.orders_driver_notify();

revoke all on function public.orders_push_notify(), public.orders_driver_notify() from public, anon, authenticated;

commit;

-- Текшириш:
-- select tgname from pg_trigger where tgrelid = 'public.orders'::regclass and tgname in ('orders_push', 'orders_driver');   -- 2 қатор
