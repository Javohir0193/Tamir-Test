-- 20261029_10_catalog_search.sql ни қайтаради. products қаторлари ва id'лар ўзгармайди.
begin;
drop function if exists public.search_products(text, integer);
drop function if exists public.catalog_categories();
drop index if exists public.products_search_trgm_idx;
alter table public.products drop column if exists search_key;
alter table public.products drop column if exists spec_uz;
alter table public.products drop column if exists name_uz;
drop table if exists public.categories;
drop function if exists public.search_key_norm(text);
drop function if exists public.search_key_of(text);
commit;
