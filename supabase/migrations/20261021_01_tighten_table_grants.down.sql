-- Ta'mir: 20261021_01_tighten_table_grants.sql ни орқага қайтариш.
-- ops.acl_backup'да сақланган аввалги ҳуқуқларни аниқ тиклайди.

begin;

do $$
declare b record; a record;
begin
  if not exists (select 1 from ops.acl_backup where migration = '20261021_01') then
    raise exception 'ops.acl_backup бўш: миграция ишга туширилмаган ёки аллақачон қайтарилган';
  end if;
  for b in select * from ops.acl_backup where migration = '20261021_01' loop
    if to_regclass(b.ident) is null then continue; end if;   -- жадвал кейин ўчирилган бўлса
    execute format('revoke all on %s from anon, authenticated', b.ident);
    for a in select g.grantee, g.privilege_type from aclexplode(b.acl) g
              where g.grantee in ('anon'::regrole, 'authenticated'::regrole) loop
      execute format('grant %s on %s to %I', a.privilege_type, b.ident, a.grantee::regrole::text);
    end loop;
  end loop;
end $$;

alter default privileges for role postgres in schema public
  grant insert, update, delete, truncate, references, trigger on tables to anon, authenticated;

delete from ops.acl_backup where migration = '20261021_01';

commit;
