-- Ta'mir: базанинг ТУЗИЛМАСИНИ экспорт қилиш (маълумотсиз). ФАҚАТ ЎҚИЙДИ.
-- Қаерда: Supabase → лойиҳа → SQL Editor → New query → шу файлни тўлиқ қўйинг → Run.
-- Натижа: «Export → Download CSV». Файлни ОЧИҚ жойга (GitHub, Telegram гуруҳ) қўйманг, фақат чатга юборинг:
-- функциялар ичида махфий матн (масалан, бот токени) бўлиши мумкин.

with rows as (
  -- 1. Жадваллар ва устунлар
  select 1 as ord, 'column' as kind, c.table_name || '.' || c.column_name as object,
         c.data_type || case when c.is_nullable = 'NO' then ' not null' else '' end
         || coalesce(' default ' || c.column_default, '') as definition
  from information_schema.columns c
  where c.table_schema = 'public'

  union all
  -- 2. Калитлар ва чекловлар (primary key, foreign key, unique, check)
  select 2, 'constraint', cl.relname || ' / ' || con.conname, pg_get_constraintdef(con.oid)
  from pg_constraint con
  join pg_class cl on cl.oid = con.conrelid
  join pg_namespace n on n.oid = cl.relnamespace
  where n.nspname = 'public'

  union all
  -- 3. Индекслар
  select 3, 'index', tablename || ' / ' || indexname, indexdef
  from pg_indexes where schemaname = 'public'

  union all
  -- 4. View'лар
  select 4, 'view', viewname, definition
  from pg_views where schemaname = 'public'

  union all
  -- 5. Триггерлар
  select 5, 'trigger', cl.relname || ' / ' || t.tgname, pg_get_triggerdef(t.oid)
  from pg_trigger t
  join pg_class cl on cl.oid = t.tgrelid
  join pg_namespace n on n.oid = cl.relnamespace
  where n.nspname = 'public' and not t.tgisinternal

  union all
  -- 6. RLS қоидалари
  select 6, 'policy', tablename || ' / ' || policyname,
         'for ' || cmd || ' to ' || array_to_string(roles, ',') || coalesce(' using (' || qual || ')', '') || coalesce(' with check (' || with_check || ')', '')
  from pg_policies where schemaname = 'public'

  union all
  -- 7. Функцияларнинг тўлиқ коди
  select 7, 'function', p.proname || '(' || pg_get_function_identity_arguments(p.oid) || ')', pg_get_functiondef(p.oid)
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.prokind = 'f'
)
select kind, object, definition from rows order by ord, object;
