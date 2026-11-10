-- 29 ни орқага қайтариш: иккала функция ўчади. Бот функция йўқлигини кўриб эски йўлга (бирма-бир upsert) қайтади.
-- price_history'даги 'seller' / 'seller_file' ёзувлари қолади (тарих, зарари йўқ).
begin;
drop function if exists public.seller_offers_save(bigint, jsonb, text);
drop function if exists public.seller_offers_check(bigint, jsonb);
commit;
