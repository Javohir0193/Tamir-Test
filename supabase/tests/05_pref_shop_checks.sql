-- Дўкон танлаш текшируви (db-test.sh): quote_order танланган дўкон нархини ҳисоблайди, бўлмаса энг арзонини.
do $$
declare mk int; s1 bigint; s2 bigint; pa int; pb int; q jsonb; items jsonb;
begin
  insert into public.markets (name) values ('CI market 2') returning id into mk;
  insert into public.sellers (name, role, status, shop, market_id) values ('P1', 'seller', 'active', 'P1', mk) returning id into s1;
  insert into public.sellers (name, role, status, shop, market_id) values ('P2', 'seller', 'active', 'P2', mk) returning id into s2;
  select min(id) into pa from public.products where active; select max(id) into pb from public.products where active;
  -- P1: pa=100, pb=200; P2: фақат pa=50 (энг арзон)
  insert into public.offers (seller_id, product_id, price) values (s1, pa, 100), (s1, pb, 200), (s2, pa, 50);
  items := jsonb_build_array(jsonb_build_object('id', pa, 'q', 2), jsonb_build_object('id', pb, 'q', 1));

  q := public.quote_order(jsonb_build_object('mode', 'pickup', 'market_id', mk, 'items', items));
  if (q->>'goods')::int <> 300 then raise exception 'аралаш: кутилган 300, келди %', q->>'goods'; end if;   -- pa=50×2 + pb=200
  q := public.quote_order(jsonb_build_object('mode', 'pickup', 'market_id', mk, 'items', items, 'shop_id', s1));
  if (q->>'goods')::int <> 400 then raise exception 'P1: кутилган 400, келди %', q->>'goods'; end if;          -- 100×2 + 200
  -- P2 да pb йўқ: pb энг арзон дўкондан (200) олинади
  q := public.quote_order(jsonb_build_object('mode', 'pickup', 'market_id', mk, 'items', items, 'shop_id', s2));
  if (q->>'goods')::int <> 300 then raise exception 'P2: кутилган 300, келди %', q->>'goods'; end if;          -- 50×2 + 200
  -- ёмон shop_id эътиборга олинмайди
  q := public.quote_order(jsonb_build_object('mode', 'pickup', 'market_id', mk, 'items', items, 'shop_id', 'abc'));
  if (q->>'goods')::int <> 300 then raise exception 'ёмон shop_id: %', q->>'goods'; end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'orders' and column_name = 'pref_shop') then raise exception 'orders.pref_shop йўқ'; end if;

  delete from public.offers where seller_id in (s1, s2); delete from public.sellers where id in (s1, s2); delete from public.markets where id = mk;
end $$;
