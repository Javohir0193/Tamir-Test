-- Push обуналари текшируви (db-test.sh): ҳайдовчи, йиғувчи, мижоз обуна бўлади; нотўғри сессия ва бегона манзил рад этилади;
-- буюртма ҳолати ўзгарганда триггер хато бермайди; жадвал анонимга ёпиқ.
do $$
declare d1 bigint; c1 bigint; u uuid := gen_random_uuid(); no1 bigint; ok boolean; i int;
  k1 text := repeat('B', 87); a1 text := repeat('a', 22);
  ep text := 'https://fcm.googleapis.com/fcm/send/ci-1';
begin
  insert into public.sellers (name, role, status, shop, tg_chat_id) values ('CI PD', 'driver', 'active', '', 7001) returning id into d1;
  insert into public.sellers (name, role, status, shop, tg_chat_id) values ('CI PC', 'collector', 'active', '', 7002) returning id into c1;
  insert into public.driver_sessions (seller_id, token_hash) values (d1, encode(extensions.digest('ci-push-d', 'sha256'), 'hex'));
  insert into public.collector_sessions (seller_id, token_hash) values (c1, encode(extensions.digest('ci-push-c', 'sha256'), 'hex'));

  if not public.push_subscribe('driver', 'ci-push-d', ep, k1, a1, 'ru') then raise exception 'push_subscribe driver'; end if;
  if (select tg_chat_id from public.push_subs where app = 'driver' and endpoint = ep) <> 7001 then raise exception 'push_subs: ҳайдовчи chat_id нотўғри'; end if;
  if (select lang from public.push_subs where app = 'driver' and endpoint = ep) <> 'ru' then raise exception 'push_subs: тил ёзилмади'; end if;
  perform public.push_subscribe('driver', 'ci-push-d', ep, k1, a1, 'uz');                -- қайта обуна: дубликат йўқ
  if (select count(*) from public.push_subs where endpoint = ep) <> 1 then raise exception 'push_subs: дубликат'; end if;
  perform public.push_subscribe('collector', 'ci-push-c', ep, k1, a1);                   -- бир телефон, бошқа илова
  if (select count(*) from public.push_subs where endpoint = ep) <> 2 then raise exception 'push_subs: бир телефонда икки илова бўлмади'; end if;

  begin perform public.push_subscribe('collector', 'ci-push-d', ep, k1, a1); raise exception 'x';
  exception when others then if sqlerrm = 'x' then raise exception 'push_subscribe: бегона сессия қабул қилинди'; end if; end;
  begin perform public.push_subscribe('driver', 'ci-push-d', 'https://evil.example.com/x', k1, a1); raise exception 'x';
  exception when others then if sqlerrm = 'x' then raise exception 'push_subscribe: бегона манзил қабул қилинди'; end if; end;
  begin perform public.push_subscribe('driver', 'ci-push-d', 'https://fcm.googleapis.com.evil.com/x', k1, a1); raise exception 'x';
  exception when others then if sqlerrm = 'x' then raise exception 'push_subscribe: ўхшаш бегона манзил қабул қилинди'; end if; end;
  begin perform public.push_subscribe('shop', null, ep, k1, a1); raise exception 'x';
  exception when others then if sqlerrm = 'x' then raise exception 'push_subscribe: сессиясиз мижоз қабул қилинди'; end if; end;

  -- мижоз
  insert into auth.users (id) values (u);
  perform set_config('request.jwt.claim.sub', u::text, true);
  perform public.push_subscribe('shop', null, 'https://web.push.apple.com/ci-2', k1, a1);
  if (select user_id from public.push_subs where app = 'shop') <> u then raise exception 'push_subs: мижоз user_id нотўғри'; end if;
  for i in 1..12 loop perform public.push_subscribe('shop', null, 'https://web.push.apple.com/ci-x' || i, k1, a1); end loop;
  if (select count(*) from public.push_subs where app = 'shop' and user_id = u) <> 10 then raise exception 'push_subs: 10 тадан кўп обуна қолди'; end if;

  insert into public.orders (customer_name, phone, mode, items, total, user_id) values ('CI', '+998900000000', 'car', '[]'::jsonb, 1000, u) returning no into no1;
  update public.orders set pay_status = 'paid' where no = no1;           -- триггер ботга ёзади (CI'да net.http_post — заглушка)
  update public.orders set stage = 3 where no = no1;
  update public.orders set cancelled_at = now() where no = no1;
  perform set_config('request.jwt.claim.sub', '', true);

  if not public.push_unsubscribe('driver', ep) then raise exception 'push_unsubscribe'; end if;
  if exists (select 1 from public.push_subs where app = 'driver') then raise exception 'push_unsubscribe: ўчмади'; end if;
  if public.push_key() is not null and public.push_key() = '' then raise exception 'push_key'; end if;

  if has_table_privilege('anon', 'public.push_subs', 'select') then raise exception 'push_subs anon''га очиқ'; end if;
  if has_function_privilege('anon', 'public.orders_push_notify()', 'execute') then raise exception 'orders_push_notify anon''га очиқ'; end if;
  if not has_function_privilege('anon', 'public.push_subscribe(text,text,text,text,text,text)', 'execute') then raise exception 'push_subscribe anon''га ёпиқ'; end if;

  delete from public.push_subs where tg_chat_id in (7001, 7002) or user_id = u;
  delete from public.orders where no = no1; delete from auth.users where id = u;
  delete from public.driver_sessions where seller_id = d1; delete from public.collector_sessions where seller_id = c1;
  delete from public.sellers where id in (d1, c1);
end $$;
