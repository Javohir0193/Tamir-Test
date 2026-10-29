-- Ta'mir: ходимлар (дўкон, йиғувчи, ҳайдовчи, админ) учун Telegram бот тили.
-- Нима учун: ботдаги хабарлар фақат ўзбекча эди; рус тилида гаплашадиган ходимлар тушунмасди.
-- Нима ўзгаради: sellers жадвалига янги устун lang ('uz' ёки 'ru', одатда 'uz'). Бот /til буйруғи орқали ўзгартиради.
-- Нима ўзгармайди: мавжуд устунлар, функциялар, RLS. Эски қаторлар 'uz' бўлиб қолади.
-- Орқага қайтариш: 20261029_07_staff_lang.down.sql
-- Тартиб: ФАҚАТ test базада. SQL Editor'га тўлиқ қўйиб Run.

begin;
alter table public.sellers add column if not exists lang text not null default 'uz';
alter table public.sellers drop constraint if exists sellers_lang_check;
alter table public.sellers add constraint sellers_lang_check check (lang in ('uz','ru'));
commit;
