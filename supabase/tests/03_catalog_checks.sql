-- Каталог ва қидирув текшируви (db-test.sh: сид маълумот юкланганидан кейин).
do $$
declare n int; k1 text; k2 text;
begin
  select count(*) into n from public.categories;
  if n < 20 then raise exception 'categories тўлмаган: %', n; end if;

  -- кирилл, ўзбек лотини ва «ts» ёзуви битта калитга тушади
  k1 := public.search_key_norm('Цемент М400'); k2 := public.search_key_norm('tsement m400');
  if k1 is distinct from k2 then raise exception 'калит мос эмас: % / %', k1, k2; end if;
  if public.search_key_norm('Ўзбек қоп ғишт') <> 'ozbek qop gisht' then raise exception 'ў/қ/ғ калити хато: %', public.search_key_norm('Ўзбек қоп ғишт'); end if;

  -- қидирув: кирилл, лотин ва хато ёзилган сўз
  select count(*) into n from public.search_products('цемент'); if n = 0 then raise exception 'қидирув: цемент йўқ'; end if;
  select count(*) into n from public.search_products('cement'); if n = 0 then raise exception 'қидирув: cement йўқ'; end if;
  select count(*) into n from public.search_products('sement'); if n = 0 then raise exception 'қидирув: sement йўқ'; end if;
  select count(*) into n from public.search_products('sment'); if n = 0 then raise exception 'қидирув: хато ёзилган сўз топилмади'; end if;
  select count(*) into n from public.search_products('x'); if n <> 0 then raise exception 'қисқа сўров бўш бўлиши керак'; end if;

  -- id кетма-кетлиги энг катта id дан юқори
  if (select nextval(pg_get_serial_sequence('public.products', 'id'))) <= (select max(id) from public.products) then raise exception 'products id кетма-кетлиги паст'; end if;

  -- anon categories жадвалини тўғридан-тўғри ўқий олмайди
  if has_table_privilege('anon', 'public.categories', 'select') then raise exception 'anon categories ни ўқий олади'; end if;
end $$;
