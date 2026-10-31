-- 25 ни орқага қайтариш. Диққат: order_events даги тарих ўчади.
begin;
drop trigger if exists orders_events on public.orders;
drop function if exists public.admin_order_events(text, bigint);
drop function if exists public.order_status(public.orders);
drop function if exists public.order_events_log();
drop table if exists public.order_events;
commit;
