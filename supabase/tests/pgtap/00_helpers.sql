-- pgTAP учун умумий ёрдамчилар. Ҳар бир тест файли буни \ir орқали улайди (ўзи транзакция ичида, охирида rollback).
-- as_user(uid, sql): sql'ни Supabase'даги каби «authenticated» роли ва JWT sub = uid билан бажаради, натижани jsonb қайтаради.
-- uid = null — сессиясиз (анонимдан ҳам олдинги ҳолат). Хато бўлса роль ўзи қайтади ва хато юқорига чиқади.
create extension if not exists pgtap;

create function pg_temp.as_user(p_uid uuid, p_sql text) returns jsonb language plpgsql as $$
declare r jsonb;
begin
  perform set_config('request.jwt.claim.sub', coalesce(p_uid::text, ''), true);
  execute 'set local role authenticated';
  execute p_sql into r;
  execute 'reset role';
  perform set_config('request.jwt.claim.sub', '', true);
  return r;
end $$;

-- as_anon(sql): худди шу, лекин «anon» роли билан (сайтга кирмаган меҳмон).
create function pg_temp.as_anon(p_sql text) returns jsonb language plpgsql as $$
declare r jsonb;
begin
  execute 'set local role anon';
  execute p_sql into r;
  execute 'reset role';
  return r;
end $$;
