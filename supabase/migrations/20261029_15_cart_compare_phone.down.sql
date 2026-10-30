-- Орқага қайтариш: cart_compare 14-миграциядаги кўринишига қайтади (phone йўқ)
begin;

create or replace function public.cart_compare(p jsonb)
 returns jsonb
 language plpgsql
 stable
 security definer
 set search_path to 'public'
as $function$
declare v_mk int;
begin
  begin v_mk := nullif(p->>'market_id', '')::int; exception when others then v_mk := null; end;
  if jsonb_typeof(p->'items') is distinct from 'array' or jsonb_array_length(p->'items') > 200 then raise exception 'bad_value'; end if;
  return (
    with q as (
      select (e->>'id')::int as id, sum(round((e->>'q')::numeric, 2)) as q
        from jsonb_array_elements(p->'items') e
       where (e->>'id') ~ '^[0-9]+$' and coalesce((e->>'q')::numeric, 0) > 0
       group by 1),
    need as (select count(*)::int as n from q),
    mix as (
      select jsonb_build_object('total', coalesce(sum(round(cm.best_price * q.q)), 0),
                                'missing', coalesce(jsonb_agg(q.id order by q.id) filter (where cm.best_price is null), '[]'::jsonb)) as j
        from q left join public.catalog_market cm on cm.market_id = v_mk and cm.id = q.id),
    per as (
      select s.id, s.shop, s.row_no, s.market_id, count(o.price)::int as have, coalesce(sum(round(o.price * q.q)), 0)::bigint as total,
             coalesce(jsonb_agg(q.id order by q.id) filter (where o.price is null), '[]'::jsonb) as missing
        from public.sellers s
        cross join q
        left join public.offers o on o.seller_id = s.id and o.product_id = q.id and o.in_stock
       where s.role = 'seller' and s.status = 'active' and (s.market_id = v_mk or s.market_id is null)
       group by s.id, s.shop, s.row_no, s.market_id
      having count(o.price) > 0),
    top as (
      select per.*, (per.have = need.n) as full from per cross join need
       order by (per.have = need.n) desc, per.have desc, per.total, per.shop limit 12)
    select jsonb_build_object('mix', (select j from mix),
      'shops', coalesce((select jsonb_agg(jsonb_build_object('id', t.id, 'shop', t.shop, 'row', t.row_no, 'market', (select coalesce(m.name_uz, m.name) from public.markets m where m.id = t.market_id), 'need', (select n from need), 'have', t.have, 'total', t.total, 'missing', t.missing)
                                         order by t.full desc, t.have desc, t.total, t.shop) from top t), '[]'::jsonb)));
end $function$;
revoke all on function public.cart_compare(jsonb) from public;
grant execute on function public.cart_compare(jsonb) to anon, authenticated;

commit;
