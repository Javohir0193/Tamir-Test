-- Ta'mir: админ йиғувчи ва ҳайдовчининг исмини ўзгартира олади.
-- Нима учун: Telegram'дан исмсиз келган ҳайдовчи сайтда бўш кўринади («· тест»), админда исмни тузатишнинг йўли йўқ эди.
-- Нима ўзгаради: янги функция admin_person_rename(p_code, p_id, p_name). «Одамлар» рўйхатидаги ✏️ тугмаси шуни чақиради.
--   Рухсат: фақат 'people' ҳуқуқи бор админ. Фақат йиғувчи ва ҳайдовчи. Исм 2–60 белги. Ўзгариш аудит журналига ёзилади.
-- Нима ўзгармайди: мавжуд функциялар, жадваллар, маълумотлар.
-- Орқага қайтариш: 20261022_06_admin_person_rename.down.sql
-- Тартиб: ФАҚАТ test базада. SQL Editor'га тўлиқ қўйиб Run.

begin;

CREATE OR REPLACE FUNCTION public.admin_person_rename(p_code text, p_id bigint, p_name text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare s public.sellers; nm text := btrim(coalesce(p_name, ''));
begin
  perform public.admin_check(p_code); perform public.admin_need('people');
  if length(nm) < 2 or length(nm) > 60 then raise exception 'bad_value'; end if;
  select * into s from public.sellers where id = p_id and role in ('collector', 'driver');
  if not found then raise exception 'unknown_key'; end if;
  update public.sellers set name = nm where id = p_id;
  perform public.admin_log('person_rename', s.role, p_id::text, jsonb_build_object('name', s.name), jsonb_build_object('name', nm), null);
end $function$;

revoke all on function public.admin_person_rename(text, bigint, text) from public;
grant execute on function public.admin_person_rename(text, bigint, text) to authenticated;

commit;

-- Текшириш (алоҳида ишга туширинг):
-- select proname from pg_proc where proname = 'admin_person_rename';   -- 1 қатор
