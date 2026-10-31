-- 23 ни орқага қайтариш. Диққат: shop_payouts даги ёзувлар ўчади.
begin;
drop function if exists public.admin_shop_pay(text, bigint, bigint, text);
drop function if exists public.admin_shop_queue(text);
drop function if exists public.shop_handed(bigint);
drop table if exists public.shop_payouts;
commit;
