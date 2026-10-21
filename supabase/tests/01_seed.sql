-- Миграциялар ишлаши учун энг кам созламалар (test базадаги каби). Ҳақиқий калит эмас.
insert into public.app_settings (key, value) values ('bot_secret', 'ci-secret'), ('admin_code', 'ci-old'), ('bot_url', 'http://localhost/tg-bot');
insert into public.sellers (name, role, status) values ('CI driver', 'driver', 'active');
