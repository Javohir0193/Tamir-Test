-- 27 ни орқага қайтариш. Диққат: ҳамма push обуналари ўчади (телефонларда тугмани қайта босиш керак бўлади).
-- app_settings'даги vapid_public / vapid_private қолади (бот яна ишлатади); ўчириш керак бўлса — пастдаги қатор.
begin;
drop trigger if exists orders_push on public.orders;
drop function if exists public.orders_push_notify();
drop function if exists public.push_unsubscribe(text, text);
drop function if exists public.push_subscribe(text, text, text, text, text, text);
drop function if exists public.push_key();
drop table if exists public.push_subs;
commit;
-- delete from public.app_settings where key in ('vapid_public', 'vapid_private');
