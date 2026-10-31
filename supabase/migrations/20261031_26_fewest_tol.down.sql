-- 26 ни орқага қайтариш (функциялар аввалги ҳолига, созлама ўчади).
begin;

CREATE OR REPLACE FUNCTION public.admin_set_app(p_code text, p_key text, p_value text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare old text;
begin
  perform public.admin_check(p_code); perform public.admin_need('settings');
  if p_key not in ('pay_minutes', 'reserve_pct', 'answer_minutes', 'payout_alert_minutes', 'unpicked_alert_minutes') then raise exception 'not_allowed'; end if;
  if p_value !~ '^[0-9]{1,3}$' or p_value::int < 1 then raise exception 'bad_value'; end if;
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
    'app', coalesce((select jsonb_object_agg(key, value) from public.app_settings where key in ('pay_minutes', 'reserve_pct', 'payments_on', 'pay_test_mode', 'answer_minutes', 'payout_alert_minutes', 'unpicked_alert_minutes')), '{}'::jsonb),
    'can_edit', public.admin_can('settings'));
end $function$;

delete from public.app_settings where key = 'fewest_tol_pct';

commit;
