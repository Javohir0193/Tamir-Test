-- Ta'mir: search_products — Supabase'да pg_trgm.word_similarity_threshold ни функцияга SET қилиб бўлмайди (permission denied 42501).
-- Нима ўзгаради: функция танаси: SET ўрнига word_similarity(...) >= 0.45 ни тўғридан-тўғри солиштиради (натижа бир хил).
-- Нима ўзгармайди: жадваллар, индекс, функция номи ва имзоси, рухсатлар. 10-миграция аввал Run қилинган бўлиши керак (ўша ердаги эски функцияни алмаштиради).
-- Орқага қайтариш: 20261029_13_search_no_guc.down.sql (бўш: эски вариант Supabase'да ишламайди)

begin;

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
