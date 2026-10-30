-- Иловадаги тугмалар текшируви (db-test.sh): ҳайдовчи машина буюртмасини иловадан кўради ва олади, иккинчи марта ололмайди.
do $$
declare d1 bigint; d2 bigint; no1 bigint; r jsonb; u uuid := gen_random_uuid(); s1 text := 'ci-drv-1'; s2 text := 'ci-drv-2';
begin
  insert into public.sellers (name, role, status, shop, car) values ('CI D1', 'driver', 'active', '', 'Damas') returning id into d1;
  insert into public.sellers (name, role, status, shop, car) values ('CI D2', 'driver', 'active', '', 'Labo') returning id into d2;
  insert into public.driver_sessions (seller_id, token_hash) values (d1, encode(extensions.digest(s1, 'sha256'), 'hex')), (d2, encode(extensions.digest(s2, 'sha256'), 'hex'));
  insert into auth.users (id) values (u);
  insert into public.orders (customer_name, phone, mode, items, total, delivery_sum, user_id, notified_at)
    values ('CI', '+998900000000', 'car', '[{"n":"Labo","q":1,"u":"рейс"}]'::jsonb, 150000, 150000, u, now()) returning no into no1;

  r := public.drv_orders(s1);   -- паркка бириктирилмаган ҳайдовчи ҳам машина буюртмасини кўради
  if not exists (select 1 from jsonb_array_elements(r->'open') e where (e->>'no')::bigint = no1 and e->>'mode' = 'car' and e->>'what' = 'Labo') then
    raise exception 'drv_orders: машина буюртмаси очиқ рўйхатда йўқ: %', r->'open';
  end if;
  if not public.drv_claim(s1, no1) then raise exception 'drv_claim: машина буюртмаси олинмади'; end if;
  if public.drv_claim(s2, no1) then raise exception 'drv_claim: бир буюртмани икки ҳайдовчи олди'; end if;
  if (select stage from public.orders where no = no1) <> 1 or (select driver_id from public.orders where no = no1) <> d1 then raise exception 'drv_claim: ҳолат ёки ҳайдовчи нотўғри'; end if;
  r := public.drv_orders(s2);
  if exists (select 1 from jsonb_array_elements(r->'open') e where (e->>'no')::bigint = no1) then raise exception 'drv_orders: олинган буюртма бошқага кўринмоқда'; end if;
  r := to_jsonb(public.drv_go(s1, no1));
  if r #>> '{}' <> 'ok' or (select stage from public.orders where no = no1) <> 3 then raise exception 'drv_go: йўлга чиқмади: % · stage %', r, (select stage from public.orders where no = no1); end if;
  if public.drv_done(s1, no1) <> 'ok' then raise exception 'drv_done: топширилмади'; end if;

  -- админ функциялари анонимга ёпиқ
  if has_function_privilege('anon', 'public.admin_product_decide(text,integer,boolean)', 'execute') then raise exception 'admin_product_decide anon''га очиқ'; end if;
  if has_function_privilege('anon', 'public.admin_product_proposals(text)', 'execute') then raise exception 'admin_product_proposals anon''га очиқ'; end if;

  delete from public.orders where no = no1; delete from public.driver_sessions where seller_id in (d1, d2); delete from public.sellers where id in (d1, d2); delete from auth.users where id = u;
end $$;
