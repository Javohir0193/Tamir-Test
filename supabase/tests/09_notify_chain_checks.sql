-- Хабарлар занжири (34-миграция, db-test.sh): мижозга фақат ўз босқичлари, ҳайдовчи тайинланса йиғувчига.
-- net.http_post шу транзакция ичида ёзиб олувчига алмаштирилади, охирида rollback — база ўзгармайди.
begin;
create temp table posted (body jsonb);
create or replace function net.http_post(url text, body jsonb default '{}', params jsonb default '{}', headers jsonb default '{}', timeout_milliseconds int default 5000)
  returns bigint language sql as $$ insert into posted values (body); select 1::bigint $$;

do $$
declare u uuid := gen_random_uuid(); pid bigint; pid2 bigint; c1 bigint; d1 bigint; no1 bigint; no2 bigint; no3 bigint; got text;
begin
  insert into auth.users (id) values (u);
  insert into public.profiles (name, phone, tg_id) values ('CI TG', '+998901110001', 7900001) returning id into pid;
  insert into public.profiles (name, phone) values ('CI нет TG', '+998901110002') returning id into pid2;
  insert into public.sellers (name, role, status, shop, tg_chat_id) values ('CI NC', 'collector', 'active', '', 7901) returning id into c1;
  insert into public.sellers (name, role, status, shop, tg_chat_id) values ('CI ND', 'driver', 'active', '', 7902) returning id into d1;

  -- етказиш, мижоз Telegram'да
  insert into public.orders (customer_name, phone, mode, items, total, user_id, profile_id, pay_status) values ('CI', '+998901110001', 'delivery', '[]'::jsonb, 1000, u, pid, 'none') returning no into no1;
  delete from posted;
  update public.orders set stage = 1, picker_id = c1 where no = no1;
  update public.orders set stage = 2 where no = no1;
  if exists (select 1 from posted where body ? 'push_order') then raise exception 'мижозга 1/2-босқич хабари кетди: %', (select string_agg(body::text, ' ') from posted); end if;

  update public.orders set driver_id = d1 where no = no1;
  if (select count(*) from posted where body ->> 'driver_set' = no1::text) <> 1 then raise exception 'ҳайдовчи тайинланди — йиғувчига хабар кетмади'; end if;
  update public.orders set driver_info = '{}'::jsonb where no = no1;              -- driver_id ўзгармади
  if (select count(*) from posted where body ? 'driver_set') <> 1 then raise exception 'driver_set такрорланди'; end if;

  update public.orders set stage = 3 where no = no1;
  select string_agg(body ->> 'st', ',') into got from posted where body ->> 'push_order' = no1::text;
  if got is distinct from 'on_way' then raise exception 'йўлда: кутилган on_way, келди %', got; end if;
  update public.orders set stage = 4 where no = no1;
  select string_agg(body ->> 'st', ',') into got from posted where body ->> 'push_order' = no1::text;
  if got is distinct from 'on_way,delivered' then raise exception 'етказилди: келди %', got; end if;

  -- йўлга чиққандан кейин ҳайдовчи алмашса — йиғувчига хабар йўқ
  delete from posted;
  update public.orders set driver_id = c1 where no = no1;
  if exists (select 1 from posted where body ? 'driver_set') then raise exception 'йўлдан кейин driver_set кетди'; end if;

  -- мижоз Telegram'сиз ва push'сиз: ҳеч нарса кетмайди
  insert into public.orders (customer_name, phone, mode, items, total, user_id, profile_id, pay_status) values ('CI2', '+998901110002', 'delivery', '[]'::jsonb, 1000, u, pid2, 'none') returning no into no2;
  delete from posted;
  update public.orders set stage = 3 where no = no2;
  if exists (select 1 from posted where body ? 'push_order') then raise exception 'обунасиз мижозга хабар кетди'; end if;

  -- машина ва олиб кетиш: ўз номлари
  insert into public.orders (customer_name, phone, mode, items, total, user_id, profile_id, pay_status) values ('CI3', '+998901110001', 'car', '[]'::jsonb, 1000, u, pid, 'none') returning no into no3;
  delete from posted;
  update public.orders set stage = 1 where no = no3;
  update public.orders set stage = 2 where no = no3;
  select string_agg(body ->> 'st', ',') into got from posted where body ? 'push_order';
  if got is distinct from 'driver_found' then raise exception 'машина: кутилган driver_found, келди %', got; end if;
  update public.orders set mode = 'pickup', stage = 3 where no = no3;
  select string_agg(body ->> 'st', ',') into got from posted where body ? 'push_order';
  if got is distinct from 'driver_found,pickup_ready' then raise exception 'олиб кетиш: келди %', got; end if;

  if has_function_privilege('anon', 'public.orders_driver_notify()', 'execute') then raise exception 'orders_driver_notify anon''га очиқ'; end if;
end $$;
rollback;
