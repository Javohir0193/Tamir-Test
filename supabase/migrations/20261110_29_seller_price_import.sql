-- Ta'mir: дўкон нархлари — битта транзакцияда сақлаш, нарх тарихи ва файлдан юклашда бозор нархи билан солиштириш.
-- Нима учун: ҳозир бот (tg-bot, action «save») нархларни бирма-бир upsert қилади: ярмида хато бўлса ярми ёзилиб қолади,
--   price_history'га ҳеч нарса тушмайди (админ «нарх тарихи»да дўкон ўзгаришлари кўринмайди), фаол бўлмаган
--   (рад этилган) товарга ҳам нарх ёзиш мумкин. Файлдан (Excel/CSV) юклаганда эса бозордан кескин фарқ қилган нарх
--   (мас. битта ноль ортиқча) огоҳлантиришсиз кетади.
-- Нима ўзгаради (иккаласи ФАҚАТ service_role учун — уларни бот чақиради, сайт тўғридан-тўғри эмас):
--   seller_offers_save(p_seller, p_rows, p_src) — [{product_id, price, in_stock, src?}] ни битта транзакцияда ёзади.
--     price 0/бўш — нархни ўчиради (ботдаги «save» билан бир хил). Каталогда йўқ ёки рад этилган товар, нотўғри нарх
--     ўтказиб юборилади. Нарх ўзгарса price_history'га 'seller' ёки 'seller_file' (файлдан) манбаси билан ёзилади.
--   seller_offers_check(p_seller, p_rows) — [{product_id, price}] учун бозор медианаси (бошқа дўконлар) ва фарқ %;
--     st: ok | warn (фарқ app_settings.price_dev_pct дан катта, одатда 30%) | err_price | err_product. Ҳеч нарса ёзмайди.
-- Нима ўзгармайди: жадваллар, мавжуд функциялар ва ҳуқуқлар. Бот янги функция йўқ бўлса эски йўл билан ишлайверади.
-- Орқага қайтариш: 20261110_29_seller_price_import.down.sql
-- Тартиб: 28 дан кейин, аввал test базада. SQL Editor'га тўлиқ қўйиб Run. Кейин tg-bot (тартиб муҳим эмас).

begin;

CREATE OR REPLACE FUNCTION public.seller_offers_save(p_seller bigint, p_rows jsonb, p_src text DEFAULT 'seller'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare saved int := 0; removed int := 0; skipped int := 0; r record; old bigint;
begin
  if p_src not in ('seller', 'seller_file') then raise exception 'bad_value'; end if;
  if jsonb_typeof(p_rows) is distinct from 'array' then raise exception 'bad_value'; end if;
  if jsonb_array_length(p_rows) > 2000 then raise exception 'too_many_rows'; end if;
  if not exists (select 1 from public.sellers where id = p_seller and role = 'seller' and status = 'active') then raise exception 'unknown_key'; end if;
  for r in
    select distinct on (pid) pid, price, stock, src from (
      select case when (e.v->>'product_id') ~ '^[0-9]{1,9}$' then (e.v->>'product_id')::int end pid,
             case when coalesce(e.v->>'price', '') in ('', '0') then 0
                  when (e.v->>'price') ~ '^[0-9]{1,12}(\.[0-9]+)?$' then round((e.v->>'price')::numeric)::bigint end price,
             coalesce(e.v->>'in_stock', '') not in ('false', '0') stock,
             case when e.v->>'src' = 'file' then 'seller_file' else p_src end src, e.ord
      from jsonb_array_elements(p_rows) with ordinality e(v, ord)) t
    where pid is not null order by pid, ord desc
  loop
    if r.price = 0 then
      delete from public.offers where seller_id = p_seller and product_id = r.pid;
      if found then removed := removed + 1; end if;
      continue;
    end if;
    -- каталогдаги фаол товар ёки ҳали кўриб чиқилмаган таклиф (рад этилганига нарх қўйилмайди)
    if r.price is null or r.price < 0 or r.price >= 1000000000
       or not exists (select 1 from public.products p where p.id = r.pid and (p.active or p.reviewed_at is null)) then
      skipped := skipped + 1; continue;
    end if;
    select price into old from public.offers where seller_id = p_seller and product_id = r.pid;
    insert into public.offers (seller_id, product_id, price, in_stock, updated_at) values (p_seller, r.pid, r.price, r.stock, now())
      on conflict (seller_id, product_id) do update set price = excluded.price, in_stock = excluded.in_stock, updated_at = now();
    if old is distinct from r.price then
      insert into public.price_history (seller_id, product_id, old_price, new_price, source) values (p_seller, r.pid, old, r.price, r.src);
    end if;
    saved := saved + 1;
  end loop;
  return jsonb_build_object('saved', saved, 'removed', removed, 'skipped', skipped);
end $function$;

CREATE OR REPLACE FUNCTION public.seller_offers_check(p_seller bigint, p_rows jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare dev numeric := coalesce((select value::numeric from public.app_settings where key = 'price_dev_pct'), 30); res jsonb;
begin
  if jsonb_typeof(p_rows) is distinct from 'array' then raise exception 'bad_value'; end if;
  if jsonb_array_length(p_rows) > 2000 then raise exception 'too_many_rows'; end if;
  select coalesce(jsonb_agg(z.r order by z.ord), '[]'::jsonb) into res from (
    select t.ord, jsonb_build_object('product_id', t.pid, 'price', t.price, 'old', o.price, 'med', m.med,
             'dev', case when m.med > 0 and t.price > 0 then round((t.price - m.med) * 100.0 / m.med, 1) end,
             'st', case when p.id is null then 'err_product'
                        when t.price is null or t.price <= 0 or t.price >= 1000000000 then 'err_price'
                        when m.med > 0 and abs(t.price - m.med) * 100 > dev * m.med then 'warn' else 'ok' end) r
    from (select e.ord, case when (e.v->>'product_id') ~ '^[0-9]{1,9}$' then (e.v->>'product_id')::int end pid,
                 case when (e.v->>'price') ~ '^[0-9]{1,12}(\.[0-9]+)?$' then round((e.v->>'price')::numeric)::bigint end price
          from jsonb_array_elements(p_rows) with ordinality e(v, ord)) t
    left join public.products p on p.id = t.pid and (p.active or p.reviewed_at is null)
    left join public.offers o on o.seller_id = p_seller and o.product_id = t.pid
    left join lateral (select (percentile_cont(0.5) within group (order by o2.price))::bigint med from public.offers o2
                       where o2.product_id = t.pid and o2.in_stock and o2.seller_id <> p_seller) m on true) z;
  return res;
end $function$;

revoke all on function public.seller_offers_save(bigint, jsonb, text) from public, anon, authenticated;
revoke all on function public.seller_offers_check(bigint, jsonb) from public, anon, authenticated;
grant execute on function public.seller_offers_save(bigint, jsonb, text) to service_role;
grant execute on function public.seller_offers_check(bigint, jsonb) to service_role;

commit;

-- Текшириш (алоҳида ишга туширинг):
-- select proname from pg_proc where proname in ('seller_offers_save', 'seller_offers_check');   -- 2 қатор
-- select public.seller_offers_check(<дўкон id>, '[{"product_id": 1, "price": 62000}]');
