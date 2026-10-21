-- Ta'mir: bot_secret ни 02 дан олдинги жойига (app_settings) қайтариш.
-- Нима учун: tg-bot Edge Function x-bot-secret'ни app_settings'дан ўқийди (Vault'дан эмас). 02 уни Vault'га кўчиргач,
--   функция «Not configured: TG_BOT_TOKEN or bot_secret missing» (500) қайтарди, ботга хабар бормади.
--   Далил: net._http_response'да 02 дан кейинги чақирувлар 500, 02.down дан кейинги чақирувлар 200.
-- Хавфсизлик: 01 миграциясидан кейин app_settings'ни anon ва authenticated ўқий олмайди (ҳуқуқ олинган, RLS ёқиқ).
--   Сир фақат service_role ва SECURITY DEFINER функцияларга кўринади. Вақтинча шу ҳолат етарли.
-- Нима ўзгармайди: 02 нинг қолган қисмлари (30 кунлик сессия, тасодифий токенлар, admin_check, default ҳуқуқлар).
-- Кейинчалик: tg-bot коди репозиторийга қўшилиб, Vault'дан ўқийдиган бўлса, бу ўзгариш қайта кўрилади.
-- Орқага қайтариш: 20261021_04_bot_secret_back_to_settings.down.sql
-- Тартиб: ФАҚАТ test базада, 02 дан кейин. SQL Editor'га тўлиқ қўйиб Run.

begin;

-- 1. Vault'даги қиймат жадвалга қайтади (Vault'да йўқ бўлса, жадвалдаги қолади)
do $$
declare v text := (select decrypted_secret from vault.decrypted_secrets where name = 'bot_secret');
begin
  if v is not null then
    insert into public.app_settings (key, value) values ('bot_secret', v)
    on conflict (key) do update set value = excluded.value;
  end if;
  if not exists (select 1 from public.app_settings where key = 'bot_secret') then
    raise exception 'bot_secret ни ҳеч қаердан топиб бўлмади (на Vault, на app_settings)';
  end if;
end $$;

-- 2. bot_post яна app_settings'дан ўқийди
CREATE OR REPLACE FUNCTION public.bot_post(p_body jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  perform net.http_post(
    url     := (select value from public.app_settings where key = 'bot_url'),
    body    := p_body,
    headers := jsonb_build_object('Content-Type', 'application/json',
                                  'x-bot-secret', (select value from public.app_settings where key = 'bot_secret')));
end $function$;

delete from vault.secrets where name = 'bot_secret';

commit;

-- Текшириш (алоҳида ишга туширинг):
-- select count(*) from public.app_settings where key = 'bot_secret';   -- 1
-- select count(*) from vault.secrets where name = 'bot_secret';        -- 0
-- Кейин сайтдан синов буюртма беринг: ботга хабар келиши керак. Кейин:
-- select status_code, left(content::text, 80) from net._http_response order by created desc limit 1;   -- 200, ok
