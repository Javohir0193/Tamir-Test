-- Ta'mir: каталог қидируви — ҳар бир сўз алоҳида, тоифа ва бозор фильтри, нарх бўйича тартиб (ADR-012).
-- Нима учун: search_products бутун сўровни битта «калит» сифатида қидиради. «цемент 400» → «sement 400», бу эса
--   «sement m400 50 kg» ичида кетма-кет йўқ, шунинг учун топилмайди. Бозор танланган бўлса ҳам нарх ва «нечта дўкон»
--   ҳамма бозорлар бўйича (catalog_public) қайтади; тоифа ва нарх бўйича тартиб йўқ.
-- Нима ўзгаради:
--   catalog_search(q, cat, market, sort, limit) — очиқ (anon, authenticated):
--     • сўров сўзларга бўлинади (6 тагача), ҲАР БИР сўз товарда бўлиши керак: калитда бор (кирилл/лотин бир хил)
--       ёки 4+ ҳарфли сўз хато ёзилган бўлса word_similarity ≥ 0.5 («semnt» → «sement»);
--     • cat — тоифа (бўш = ҳаммаси), market — бозор id (нарх ва дўконлар сони шу бозор бўйича, нархи бор товарлар),
--     • sort: 'rel' (мослик, одатда), 'price_asc', 'price_desc' (нархсизлар охирида);
--     • жавоб: search_products билан бир хил устунлар (сайт иккаласини ҳам ўқий олади).
--   products_search_trgm_idx (10-миграция) ишлатилади: ҳар сўз учун «like '%сўз%'» GIN индекс билан.
-- Нима ўзгармайди: search_products (имзо ва натижа ўша), жадваллар, индекслар, view'лар.
-- Орқага қайтариш: 20261110_31_catalog_search.down.sql
-- Тартиб: 30 дан кейин (мустақил), аввал test базада. SQL Editor'га тўлиқ қўйиб Run. Сайт функция йўқлигида search_products га қайтади.

begin;

CREATE OR REPLACE FUNCTION public.catalog_search(p_q text, p_cat text DEFAULT NULL::text, p_market integer DEFAULT NULL::integer,
                                                 p_sort text DEFAULT 'rel'::text, p_limit integer DEFAULT 30)
 RETURNS TABLE(id integer, cat text, name text, spec text, unit text, emoji text, base_price bigint, best_price bigint, best_shop text, offers integer, score real)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare k text := public.search_key_norm(left(coalesce(p_q, ''), 80));
        w text[]; lim int := least(greatest(coalesce(p_limit, 30), 1), 100); srt text := coalesce(nullif(p_sort, ''), 'rel');
begin
  if srt not in ('rel', 'price_asc', 'price_desc') then raise exception 'bad_value'; end if;
  select coalesce(array_agg(t), '{}') into w from (select distinct t from unnest(string_to_array(k, ' ')) t where t <> '' limit 6) x;
  if length(k) < 2 or cardinality(w) = 0 then return; end if;
  return query
    with hit as (
      select p.id, p.search_key,
             (select avg(case when p.search_key like '%' || t || '%' then 1.0 else word_similarity(t, p.search_key) end) from unnest(w) t)::real sc,
             (p.search_key like '%' || k || '%') phrase
        from public.products p
       where p.active and (nullif(p_cat, '') is null or p.cat = p_cat)
         and not exists (select 1 from unnest(w) t
                          where not (p.search_key like '%' || t || '%' or (length(t) >= 4 and word_similarity(t, p.search_key) >= 0.5))))
    select c.id, c.cat, c.name, c.spec, c.unit, c.emoji, c.base_price,
           case when p_market is null then c.best_price else m.best_price end,
           case when p_market is null then c.best_shop else m.best_shop end,
           case when p_market is null then c.offers else coalesce(m.offers, 0) end,
           (h.sc + case when h.phrase then 0.5 else 0 end)::real
      from hit h
      join public.catalog_public c on c.id = h.id
      left join public.catalog_market m on m.market_id = p_market and m.id = h.id
     where p_market is null or m.id is not null
     order by case when srt = 'price_asc'  then coalesce(case when p_market is null then c.best_price else m.best_price end, c.base_price) end asc nulls last,
              case when srt = 'price_desc' then coalesce(case when p_market is null then c.best_price else m.best_price end, c.base_price) end desc nulls last,
              h.phrase desc, 11 desc, c.name
     limit lim;
end $function$;

revoke all on function public.catalog_search(text, text, integer, text, integer) from public;
grant execute on function public.catalog_search(text, text, integer, text, integer) to anon, authenticated;

commit;

-- Текшириш (алоҳида ишга туширинг):
-- select name, spec, score from public.catalog_search('цемент 400');          -- «Цемент М400 …» биринчи
-- select name, best_price from public.catalog_search('semnt', null, null, 'price_asc');
