-- Ta'mir: 20261021_04_bot_secret_back_to_settings.sql ни орқага қайтариш (bot_secret яна Vault'га кўчади).
-- ОГОҲЛАНТИРИШ: tg-bot ҳозир Vault'ни ўқимайди, бу файлдан кейин бот хабарлари 500 беради.
-- Фақат tg-bot Vault'дан ўқийдиган қилиб ўзгартирилгандан кейин ишлатинг.

begin;

do $$
declare v text := (select value from public.app_settings where key = 'bot_secret');
begin
  if v is null then raise exception 'app_settings.bot_secret йўқ'; end if;
  if exists (select 1 from vault.secrets where name = 'bot_secret') then
    perform vault.update_secret((select id from vault.secrets where name = 'bot_secret'), v);
  else
    perform vault.create_secret(v, 'bot_secret', 'tg-bot x-bot-secret');
  end if;
end $$;

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
                                  'x-bot-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'bot_secret')));
end $function$;

delete from public.app_settings where key = 'bot_secret';

commit;
