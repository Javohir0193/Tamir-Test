-- Ta'mir: buyurtma oqimini sinashdan oldingi tekshiruv. FAQAT O'QIYDI, hech narsani o'zgartirmaydi.
-- Qayerda: FAQAT test loyiha -> SQL Editor -> New query -> to'liq qo'yib Run.
-- Natija jadvali: check / n. Maxfiy qiymatlar chiqmaydi (faqat sonlar va kalit nomlari).

select 'markets (faol)' as check, count(*)::text as n from public.markets where active
union all select 'products', count(*)::text from public.products
union all select 'offers (narxlar)', count(*)::text from public.offers
union all select 'sellers: seller, faol', count(*)::text from public.sellers where role = 'seller' and status = 'active'
union all select 'sellers: collector, faol', count(*)::text from public.sellers where role = 'collector' and status = 'active'
union all select 'sellers: driver, faol', count(*)::text from public.sellers where role = 'driver' and status = 'active'
union all select 'sellers: tg_chat_id bor', count(*)::text from public.sellers where tg_chat_id is not null
union all select 'admin_users (faol)', count(*)::text from public.admin_users where status = 'active'
union all select 'delivery_tariffs (faol)', count(*)::text from public.delivery_tariffs where active
union all select 'payment_providers (yoqilgan)', count(*)::text from public.payment_providers where enabled
union all select 'app_settings kalitlari', coalesce(string_agg(key, ', ' order by key), '-') from public.app_settings
union all select 'vault: bot_secret', count(*)::text from vault.secrets where name = 'bot_secret'
union all select 'cron: tamir-cleanup', count(*)::text from cron.job where jobname = 'tamir-cleanup'
union all select 'orders (jami)', count(*)::text from public.orders;
