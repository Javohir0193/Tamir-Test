-- Ta'mir: anon/authenticated ролларидан ортиқча жадвал ҳуқуқларини олиш.
-- Нима учун: 12 та жадвалда аноним меҳмонга INSERT/UPDATE/DELETE/TRUNCATE берилган. Ҳозир уларни RLS тўсиб турибди,
--   лекин битта хато policy ёзилса, жадвал дарров очилиб қолади. Сайтга фақат ўқиш керак бўлган 4 та нарса қолади.
-- Нима ўзгармайди: функциялар (RPC), service_role (tg-bot), RLS, маълумотлар.
-- Сайт ўқийди: orders (authenticated, RLS билан), catalog_public, catalog_market, markets_public.
-- Орқага қайтариш: 20261021_01_tighten_table_grants.down.sql (ops.acl_backup'дан аниқ тиклайди).
-- Тартиб: АВВАЛ test базада, текширувдан кейин prod'да. SQL Editor'га тўлиқ қўйиб Run.

begin;

-- 0. Ҳозирги ҳуқуқларни сақлаш. ops схемаси API орқали кўринмайди.
create schema if not exists ops;
revoke all on schema ops from public, anon, authenticated;
create table if not exists ops.acl_backup (
  migration text not null,
  ident text not null,
  acl aclitem[],
  saved_at timestamptz not null default now(),
  primary key (migration, ident)
);
insert into ops.acl_backup (migration, ident, acl)
select '20261021_01', c.oid::regclass::text, c.relacl
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
 where n.nspname = 'public' and c.relkind in ('r', 'p', 'v', 'm')
on conflict (migration, ident) do nothing;

-- 1. Барча жадвал ва view'лардан anon/authenticated ҳуқуқларини олиш
do $$
declare r record;
begin
  for r in select c.oid::regclass as rel
             from pg_class c join pg_namespace n on n.oid = c.relnamespace
            where n.nspname = 'public' and c.relkind in ('r', 'p', 'v', 'm')
  loop
    execute format('revoke all on %s from anon, authenticated', r.rel);
  end loop;
end $$;

-- 2. Сайт ўқийдиганларини қайтариш (фақат SELECT)
grant select on public.orders to authenticated;   -- RLS: фақат ўз буюртмаси; realtime ҳам шунга таянади
grant select on public.catalog_public, public.catalog_market, public.markets_public to anon, authenticated;

-- 3. Келажакда яратиладиган жадвалларга ҳам ортиқча ҳуқуқ берилмасин
alter default privileges for role postgres in schema public
  revoke insert, update, delete, truncate, references, trigger on tables from anon, authenticated;

commit;

-- Текшириш (алоҳида ишга туширинг): 4 та қатор чиқиши керак
-- select table_name, grantee, string_agg(privilege_type, ',') from information_schema.role_table_grants
--  where table_schema = 'public' and grantee in ('anon', 'authenticated') group by 1, 2 order by 1, 2;
