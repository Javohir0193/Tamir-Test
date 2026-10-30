-- Савatни таққослаш текшируви (db-test.sh: сид юкланганидан кейин; ўзи ясаб, ўзи ўчиради).
do $$
declare mk int; s1 bigint; s2 bigint; s3 bigint; pa int; pb int; r jsonb; sh jsonb;
begin
  insert into public.markets (name) values ('CI market') returning id into mk;
  insert into public.sellers (name, role, status, shop, market_id) values ('N1', 'seller', 'active', 'N1', mk) returning id into s1;
  insert into public.sellers (name, role, status, shop, market_id, row_no) values ('N2', 'seller', 'active', 'N2', mk, '7-қатор') returning id into s2;
  insert into public.sellers (name, role, status, shop, market_id) values ('N3', 'seller', 'active', 'N3', mk) returning id into s3;
  select min(id) into pa from public.products where active; select max(id) into pb from public.products where active;
  -- N1: иккаласи 100/200; N2: иккаласи, арзонроқ; N3: фақат биринчиси жуда арзон
  insert into public.offers (seller_id, product_id, price) values (s1, pa, 100), (s1, pb, 200), (s2, pa, 90), (s2, pb, 200), (s3, pa, 50);
  r := public.cart_compare(jsonb_build_object('market_id', mk, 'items', jsonb_build_array(jsonb_build_object('id', pa, 'q', 2), jsonb_build_object('id', pb, 'q', 1))));
  sh := r->'shops';
  if jsonb_array_length(sh) <> 3 then raise exception 'дўконлар сони: %', r; end if;
  if sh->0->>'row' <> '7-қатор' or sh->0->>'market' <> 'CI market' then raise exception 'қатор/бозор нотўғри: %', sh->0; end if;
  if sh->1->>'row' is not null then raise exception 'N1 да қатор бўлмаслиги керак: %', sh->1; end if;
  -- тўлиқлар аввал, нарх бўйича: N2 (380) < N1 (400); кейин N3 (қисман: 100)
  if sh->0->>'shop' <> 'N2' or (sh->0->>'total')::int <> 380 or (sh->0->>'have')::int <> 2 then raise exception 'N2 нотўғри: %', sh->0; end if;
  if sh->1->>'shop' <> 'N1' or (sh->1->>'total')::int <> 400 then raise exception 'N1 нотўғри: %', sh->1; end if;
  if sh->2->>'shop' <> 'N3' or (sh->2->>'total')::int <> 100 or sh->2->'missing' <> jsonb_build_array(pb) then raise exception 'N3 нотўғри: %', sh->2; end if;
  -- аралаш: pa энг арзон 50 (N3) ×2 + pb 200 = 300
  if (r->'mix'->>'total')::int <> 300 or r->'mix'->'missing' <> '[]'::jsonb then raise exception 'mix нотўғри: %', r->'mix'; end if;
  -- ёмон кириш
  begin perform public.cart_compare('{"items": "x"}'::jsonb); raise exception 'ёмон кириш ўтиб кетди'; exception when others then if sqlerrm <> 'bad_value' then raise; end if; end;
  -- тозалаш
  delete from public.offers where seller_id in (s1, s2, s3); delete from public.sellers where id in (s1, s2, s3); delete from public.markets where id = mk;
end $$;
