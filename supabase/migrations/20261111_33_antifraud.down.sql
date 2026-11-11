-- 33 ни орқага қайтариш: антифрод белгилари, сканер, cron вазифаси, blacklist триггерлари ва fraud_* созламалари ўчади.
-- ДИҚҚАТ: белгилар ва админ қарорлари йўқолади (керак бўлса олдин: create table ops.bk_fraud_flags as table public.fraud_flags;).
-- Профилга қўйилган 'blacklist' белгилари ва block_reason ўзгармайди (админ уларни «Мижозлар» бўлимида олиб ташлайди).
begin;

do $$ begin
  if exists (select 1 from pg_namespace where nspname = 'cron') and exists (select 1 from cron.job where jobname = 'tamir-fraud-scan') then
    perform cron.unschedule('tamir-fraud-scan');
  end if;
end $$;
drop trigger if exists orders_not_blocked on public.orders;
drop trigger if exists reviews_not_blocked on public.reviews;
drop function if exists public.profile_not_blocked();
drop function if exists public.admin_fraud_decide(text, bigint, text, text, boolean);
drop function if exists public.fraud_decide(bigint, text, text, boolean, text);
drop function if exists public.admin_fraud(text, text, integer);
drop function if exists public.fraud_scan();
drop function if exists public.fraud_setting(text, integer);
drop table if exists public.fraud_flags;
drop index if exists public.orders_profile_created_idx;
delete from public.app_settings where key in ('fraud_orders_hour', 'fraud_unpaid_day', 'fraud_phone_profiles', 'fraud_complaints',
                                              'fraud_big_first', 'fraud_devices_day', 'fraud_reviews_day');

commit;
