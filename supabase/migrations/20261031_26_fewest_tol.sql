-- Ta'mir: «кам дўкон» чегараси бутун сават бўйича, админда созланади (fewest_tol_pct, бошида 5%).
-- Нима учун: ҳар товар бошқа дўконда бироз арзон бўлса, 10 та товар 10 та дўконга бўлиниб кетарди; бот энди бутун сават суммаси
--   энг арзон йиғиндидан шу фоиздан ортиқ ошмаса, энг кам дўконни танлайди (бот коди: tg-bot, route()).
-- Нима ўзгаради: app_settings га fewest_tol_pct = 5 (бор бўлса тегмайди); admin_set_app ва admin_settings шу калитни қабул қилади/кўрсатади (0–30).
-- Нима ўзгармайди: жадваллар, бошқа функциялар. Мижозга нарх ўзгармайди (қотирилган), фарқ платформа даромадидан кетади.
-- Орқага қайтариш: 20261031_26_fewest_tol.down.sql
-- Тартиб: 25 дан кейин. SQL Editor'га тўлиқ қўйиб Run.

begin;

insert into public.app_settings (key, value) values ('fewest_tol_pct', '5') on conflict (key) do nothing;

CREATE OR REPLACE FUNCTION public.admin_set_app(p_code text, p_key text, p_value text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare old text;
begin
  perform public.admin_check(p_code); perform public.admin_need('settings');
  if p_key not in ('pay_minutes', 'reserve_pct', 'answer_minutes', 'payout_alert_minutes', 'unpicked_alert_minutes', 'fewest_tol_pct') then raise exception 'not_allowed'; end if;
  if p_value !~ '^[0-9]{1,3}$' then raise exception 'bad_value'; end if;
  if p_key = 'fewest_tol_pct' then
    if p_value::int > 30 then raise exception 'bad_value'; end if;          -- 0 рухсат: фақат энг арзон
  elsif p_value::int < 1 then raise exception 'bad_value'; end if;
  if p_key = 'reserve_pct' and p_value::int > 30 then raise exception 'bad_value'; end if;
  if p_key = 'pay_minutes' and p_value::int > 180 then raise exception 'bad_value'; end if;
  select value into old from public.app_settings where key = p_key;
  update public.app_settings set value = p_value where key = p_key;
  if not found then insert into public.app_settings (key, value) values (p_key, p_value); end if;
  perform public.admin_log('set_app', 'setting', p_key, to_jsonb(old), to_jsonb(p_value));
end $function$;

CREATE OR REPLACE FUNCTION public.admin_settings(p_code text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  perform public.admin_check(p_code);
  return jsonb_build_object(
    'fees', coalesce((select jsonb_agg(jsonb_build_object('key', key, 'value', value, 'note', note) order by key) from public.fee_settings where key <> 'cfg_v2'), '[]'::jsonb),
    'tariffs', coalesce((select jsonb_agg(jsonb_build_object('id', id, 'name', name, 'cap', cap_kg, 'near', near_price, 'mid', mid_price, 'far', far_price, 'active', active) order by sort) from public.delivery_tariffs), '[]'::jsonb),
    'providers', coalesce((select jsonb_agg(jsonb_build_object('code', code, 'name', name, 'pct', pct, 'enabled', enabled) order by sort) from public.payment_providers), '[]'::jsonb),
    'app', coalesce((select jsonb_object_agg(key, value) from public.app_settings where key in ('pay_minutes', 'reserve_pct', 'payments_on', 'pay_test_mode', 'answer_minutes', 'payout_alert_minutes', 'unpicked_alert_minutes', 'fewest_tol_pct')), '{}'::jsonb),
    'can_edit', public.admin_can('settings'));
end $function$;

commit;
