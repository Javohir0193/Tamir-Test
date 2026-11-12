-- 32 ни орқага қайтариш: баҳолар жадвали ва функциялари ўчади, review_days созламаси ўчади.
-- ДИҚҚАТ: ҳамма баҳо ва шарҳлар йўқолади (керак бўлса олдин: create table ops.bk_reviews as table public.reviews;).
-- Сайт функциялар йўқлигини кўриб «Баҳолаш» тугмасини ва юлдузчаларни кўрсатмайди.
begin;

drop function if exists public.admin_review_set(text, bigint, text, text);
drop function if exists public.admin_reviews(text, text, integer);
drop function if exists public.review_moderate(bigint, text, text, text);
drop function if exists public.seller_reviews(bigint);
drop function if exists public.shop_reviews(bigint, integer);
drop function if exists public.review_author(text);
drop function if exists public.ratings_summary();
drop function if exists public.review_save(bigint, jsonb);
drop function if exists public.review_needs_check(text);
drop function if exists public.review_targets(bigint);
drop function if exists public.review_order_targets(bigint);
drop function if exists public.review_window(public.orders);
drop table if exists public.reviews;
delete from public.app_settings where key = 'review_days';

commit;
