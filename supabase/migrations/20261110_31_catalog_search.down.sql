-- 31 ни орқага қайтариш: catalog_search ўчади. Сайт функция йўқлигини кўриб search_products (10/13-миграция) га қайтади.
begin;
drop function if exists public.catalog_search(text, text, integer, text, integer);
commit;
