-- Ta'mir: 20261022_06_admin_person_rename.sql ни орқага қайтариш.
begin;
drop function if exists public.admin_person_rename(text, bigint, text);
commit;
