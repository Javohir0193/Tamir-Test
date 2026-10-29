-- Миграциялардан кейинги асосий текширувлар. Бирортаси бажарилмаса хато беради.
do $$
declare n int;
begin
  -- ҳамма жадвалда RLS ёқиқ
  select count(*) into n from pg_class c join pg_namespace s on s.oid = c.relnamespace
   where s.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity;
  if n > 0 then raise exception 'RLS ўчиқ жадвал бор: %', n; end if;

  -- аноним жадвалларни тўғридан-тўғри ўқий олмайди (фақат 3 та очиқ view)
  select count(*) into n from information_schema.role_table_grants
   where table_schema = 'public' and grantee = 'anon' and table_name not in ('catalog_public', 'catalog_market', 'markets_public');
  if n > 0 then raise exception 'anon''га ортиқча жадвал ҳуқуқи: %', n; end if;

  -- SECURITY DEFINER функцияларнинг ҳаммасида search_path бор
  select count(*) into n from pg_proc p join pg_namespace s on s.oid = p.pronamespace
   where s.nspname = 'public' and p.prosecdef
     and not exists (select 1 from unnest(coalesce(p.proconfig, '{}')) c where c like 'search_path=%');
  if n > 0 then raise exception 'search_path йўқ SECURITY DEFINER функция: %', n; end if;

  -- бот сирини топа оладиган жой бор (app_settings)
  if not exists (select 1 from public.app_settings where key = 'bot_secret') then raise exception 'bot_secret йўқ'; end if;

  -- ходим тили: sellers.lang бор ва фақат uz/ru
  if not exists (select 1 from information_schema.columns where table_schema='public' and table_name='sellers' and column_name='lang') then
    raise exception 'sellers.lang йўқ';
  end if;

  -- буюртмани бекор қилиш: функция ва устунлар бор, анонимга ёпиқ
  if not exists (select 1 from pg_proc where proname = 'admin_order_cancel') then raise exception 'admin_order_cancel йўқ'; end if;
  if (select count(*) from information_schema.columns where table_schema='public' and table_name='orders' and column_name in ('cancelled_at','cancel_reason')) <> 2 then
    raise exception 'orders.cancelled_at/cancel_reason йўқ';
  end if;
  if has_function_privilege('anon', 'public.admin_order_cancel(text,bigint,text)', 'execute') then raise exception 'admin_order_cancel anon''га очиқ'; end if;

  -- тўлов мослиги қоидаси огоҳлантириш сканерида бор
  if position('paycheck:' in pg_get_functiondef('public.admin_alert_scan()'::regprocedure)) = 0 then raise exception 'admin_alert_scan да paycheck қоидаси йўқ'; end if;
end $$;
