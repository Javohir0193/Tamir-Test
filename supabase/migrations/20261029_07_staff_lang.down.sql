-- 20261029_07_staff_lang.sql ни қайтаради.
begin;
alter table public.sellers drop constraint if exists sellers_lang_check;
alter table public.sellers drop column if exists lang;
commit;
