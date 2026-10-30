-- Ta'mir: каталог базага (1-қадам): категориялар, ўзбекча номлар, кирилл/лотин қидируви.
-- Нима учун: ҳафта 5–6. Каталог ҳозир catalog.js да; базада фақат products бор, ўзбекча ном ва қидирув йўқ.
-- Нима ўзгаради:
--   categories жадвали (RLS ёқилган, тўғридан-тўғри ўқиш ёпиқ; очиқ RPC: catalog_categories());
--   products га name_uz, spec_uz ва search_key (кирилл ва лотин битта лотин «калит»га келтирилади), pg_trgm индекси;
--   search_key_of(text): ўша калитни ясовчи функция; search_products(q, limit): очиқ қидирув (хато ёзилган сўзни ҳам топади).
-- Нима ўзгармайди: products ўзи, id'лар, offers, catalog_public, сайтнинг ҳозирги ишлаши (catalog.js захира бўлиб қолади).
-- Орқага қайтариш: 20261029_10_catalog_search.down.sql
-- Тартиб: ФАҚАТ test базада. SQL Editor'га тўлиқ қўйиб Run. Кейин supabase/ops/seed_catalog_from_js.sql.

begin;

create extension if not exists pg_trgm with schema extensions;

-- Кирилл (ўзбек/рус) ва лотин ёзувини битта лотин «калит»га келтиради: «цемент», «sement», «tsement» бир хил чиқади.
create or replace function public.search_key_of(t text)
 returns text
 language sql
 immutable
 set search_path to 'public'
as $function$
  select btrim(regexp_replace(
    translate(
      replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(lower(coalesce(t, '')),
        'щ', 'sh'), 'ш', 'sh'), 'ч', 'ch'), 'ё', 'yo'), 'ю', 'yu'), 'я', 'ya'), 'ц', 's'), 'ж', 'j'), 'ў', 'o'), 'ғ', 'g'), 'қ', 'q'), 'ҳ', 'h'),
      'абвгдезийклмнопрстуфхыэьъ''ʻʼ`’',
      'abvgdeziyklmnoprstufxie'),
    '[^a-z0-9]+', ' ', 'g'))
$function$;
-- Лотин ёзувни ҳам шу калитга келтирувчи қўшимча тузатишлар:
create or replace function public.search_key_norm(t text)
 returns text
 language sql
 immutable
 set search_path to 'public'
as $function$
  -- «ts»→«s», «kh»→«x», «c»→«s» («ch» сақланади): лотинда «cement», «tsement», «sement» бир хил
  select replace(replace(replace(replace(replace(replace(replace(public.search_key_of(t), 'ch', '#'), 'c', 's'), '#', 'ch'), 'ts', 's'), 'kh', 'x'), 'ye', 'e'), 'yo', 'e')
$function$;

create table if not exists public.categories (
  id text primary key,
  name_ru text not null,
  name_uz text not null,
  grp text,
  color text,
  sort integer not null default 100
);
alter table public.categories enable row level security;
revoke all on public.categories from public, anon, authenticated;

alter table public.products add column if not exists name_uz text;
alter table public.products add column if not exists spec_uz text;
alter table public.products add column if not exists search_key text
  generated always as (public.search_key_norm(coalesce(name, '') || ' ' || coalesce(spec, '') || ' ' || coalesce(name_uz, '') || ' ' || coalesce(spec_uz, ''))) stored;
create index if not exists products_search_trgm_idx on public.products using gin (search_key extensions.gin_trgm_ops);

create or replace function public.catalog_categories()
 returns setof public.categories
 language sql
 stable
 security definer
 set search_path to 'public'
as $function$
  select * from public.categories order by sort, id
$function$;
revoke all on function public.catalog_categories() from public;
grant execute on function public.catalog_categories() to anon, authenticated;

create or replace function public.search_products(p_q text, p_limit integer default 30)
 returns table (id integer, cat text, name text, spec text, unit text, emoji text, base_price bigint,
                best_price bigint, best_shop text, offers integer, score real)
 language plpgsql
 stable
 security definer
 set search_path to 'public', 'extensions'
as $function$
declare k text := public.search_key_norm(left(coalesce(p_q, ''), 80)); lim int := least(greatest(coalesce(p_limit, 30), 1), 100);
begin
  if length(k) < 2 then return; end if;
  return query
    select c.id, c.cat, c.name, c.spec, c.unit, c.emoji, c.base_price, c.best_price, c.best_shop, c.offers,
           greatest(similarity(p.search_key, k), word_similarity(k, p.search_key))::real
      from public.products p join public.catalog_public c on c.id = p.id
     where p.search_key like '%' || k || '%' or word_similarity(k, p.search_key) >= 0.45
     order by (p.search_key like '%' || k || '%') desc, 11 desc, c.name
     limit lim;
end $function$;
revoke all on function public.search_products(text, integer) from public;
grant execute on function public.search_products(text, integer) to anon, authenticated;

commit;

-- Текшириш (алоҳида ишга туширинг):
-- select public.search_key_norm('Цемент М400'), public.search_key_norm('tsement m400');   -- иккаласи ҳам «sement m400»
-- select * from public.search_products('sement');
