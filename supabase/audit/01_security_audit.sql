-- Ta'mir: базанинг хавфсизлик аудити. ФАҚАТ ЎҚИЙДИ, ҳеч нарсани ўзгартирмайди.
-- Қаерда: Supabase → лойиҳа → SQL Editor → New query → шу файлни тўлиқ қўйинг → Run.
-- Натижа битта жадвал бўлиб чиқади: «Export → Download CSV» қилиб, файлни чатга юборинг.
-- Бу ерда функцияларнинг коди ва маълумотлар (исм, телефон) ЙЎҚ, фақат созламалар.

with
tbl as (
  select c.oid, c.relname, c.relkind, c.relrowsecurity, c.relforcerowsecurity, c.reloptions
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relkind in ('r', 'p', 'v', 'm')
),
rows as (
  -- 1. Жадваллар: RLS ёқилганми
  select 1 as ord, 'table_rls' as section, relname as object,
         case when relrowsecurity then 'RLS ON' else '!!! RLS OFF' end
         || case when relforcerowsecurity then ', FORCE' else '' end as detail
  from tbl where relkind in ('r', 'p')

  union all
  -- 2. View'лар: security_invoker бўлмаса, view RLS'ни четлаб ўтади
  select 2, 'view', relname,
         case when coalesce(array_to_string(reloptions, ','), '') like '%security_invoker=true%'
              then 'security_invoker' else 'owner rights (RLS четлаб ўтилади — текшириш керак)' end
  from tbl where relkind in ('v', 'm')

  union all
  -- 3. RLS қоидалари
  select 3, 'policy', tablename || ' / ' || policyname,
         cmd || ' to ' || array_to_string(roles, ',') || ' | using: ' || coalesce(qual, '—') || ' | check: ' || coalesce(with_check, '—')
  from pg_policies where schemaname = 'public'

  union all
  -- 4. anon / authenticated роллари жадвалларга қандай ҳуқуққа эга
  select 4, 'grant', table_name || ' → ' || grantee, string_agg(privilege_type, ',' order by privilege_type)
  from information_schema.role_table_grants
  where table_schema = 'public' and grantee in ('anon', 'authenticated')
  group by table_name, grantee

  union all
  -- 5. Функциялар: SECURITY DEFINER, search_path, ким чақира олади
  select 5, 'function', p.proname || '(' || pg_get_function_identity_arguments(p.oid) || ')',
         case when p.prosecdef then 'DEFINER' else 'invoker' end
         || case when p.prosecdef and not exists (select 1 from unnest(coalesce(p.proconfig, '{}')) x where x like 'search_path=%')
                 then ' !!! search_path йўқ' else '' end
         || ' | anon:' || case when has_function_privilege('anon', p.oid, 'execute') then 'yes' else 'no' end
         || ' | auth:' || case when has_function_privilege('authenticated', p.oid, 'execute') then 'yes' else 'no' end
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.prokind = 'f'

  union all
  -- 6. Realtime орқали тарқатиладиган жадваллар
  select 6, 'realtime', tablename, 'supabase_realtime'
  from pg_publication_tables where pubname = 'supabase_realtime'

  union all
  -- 7. Ўрнатилган кенгайтмалар
  select 7, 'extension', extname, extversion from pg_extension

  union all
  -- 8. Жадваллар ҳажми (қатор сони тахминий)
  select 8, 'size', relname, reltuples::bigint || ' rows, ' || pg_size_pretty(pg_total_relation_size(oid))
  from tbl where relkind in ('r', 'p')
)
select section, object, detail from rows order by ord, object;
