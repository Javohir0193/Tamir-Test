-- ФАҚАТ TEST базада (tamir-test, mlhhmohaxpetptmrtqrz) бир марта ишлатинг: бу база синов базаси эканини белгилайди.
-- Шундан кейин «🧪 Тестовая оплата» (pay_test) ишлайди (pay_test_mode = 'true' ҳам бўлиши керак).
-- PROD базада ҲЕЧ ҚАЧОН ишлатманг: у ерда app_env бўлмаслиги (ёки 'prod' бўлиши) керак — шунда синов тўлови ёпиқ.
-- Олдин текширинг: Supabase'нинг юқори чап бурчагида лойиҳа номи TEST эканига ишонч ҳосил қилинг.
begin;
insert into public.app_settings (key, value) values ('app_env', 'test')
  on conflict (key) do update set value = excluded.value;
commit;
select key, value from public.app_settings where key in ('app_env', 'pay_test_mode');
