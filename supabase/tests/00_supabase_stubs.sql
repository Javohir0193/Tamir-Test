-- Бўш Postgres'да Supabase лойиҳасида аллақачон бор нарсаларнинг соддалаштирилган ўрнини босувчиси.
-- Фақат CI ва маҳаллий текширув учун. Ҳақиқий Supabase базасида ИШЛАТМАНГ.
do $$ begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then create role anon nologin; end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then create role authenticated nologin; end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then create role service_role nologin bypassrls; end if;
end $$;
create schema auth;
create table auth.users (id uuid primary key);
create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
create schema net;
create table net._http_response (id bigint, status_code int, content text, created timestamptz default now());
create function net.http_post(url text, body jsonb default '{}', params jsonb default '{}', headers jsonb default '{}', timeout_milliseconds int default 5000)
  returns bigint language sql as $$ select 1::bigint $$;
create publication supabase_realtime;
create schema vault;
create table vault.secrets (id uuid primary key default gen_random_uuid(), name text unique, secret text, description text);
create view vault.decrypted_secrets as select id, name, secret as decrypted_secret from vault.secrets;
create function vault.create_secret(s text, n text, d text default '') returns uuid language sql as $$ insert into vault.secrets (name, secret, description) values (n, s, d) returning id $$;
create function vault.update_secret(i uuid, s text) returns void language sql as $$ update vault.secrets set secret = s where id = i $$;
create schema cron;
create table cron.job (jobname text, schedule text, command text);
create function cron.schedule(n text, s text, c text) returns bigint language sql as $$ delete from cron.job where jobname = n; insert into cron.job values (n, s, c); select 1::bigint $$;
create function cron.unschedule(n text) returns boolean language sql as $$ delete from cron.job where jobname = n; select true $$;
