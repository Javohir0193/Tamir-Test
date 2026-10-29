-- Ta'mir: огоҳлантириш сканерига тўлов текшируви қўшилади (ҳафта 4: кунлик сверка огоҳлантириши).
-- Нима учун: Click/Payme билан тўлов ва буюртма ҳолати мос келмаса, буни ҳеч ким сезмас эди.
-- Нима ўзгаради: admin_alert_scan() га 3 та қоида: (1) тўланган тўлов бор, лекин буюртма «тўланди» эмас; (2) буюртма «тўланди», лекин тўланган тўлов йўқ;
--   (3) тўлов суммаси буюртма суммасидан фарқ қилади. Топилса, Telegram'да админларга қизил огоҳлантириш кетади (сканер аввалдан ишлайди, қайта юборилмайди).
-- Нима ўзгармайди: қолган қоидалар, жадваллар. Бекор қилинган (cancelled_at) буюртма биринчи қоидадан чиқарилган.
-- Орқага қайтариш: 20261029_09_pay_mismatch_alert.down.sql
-- Тартиб: ФАҚАТ test базада. SQL Editor'га тўлиқ қўйиб Run.

begin;

CREATE OR REPLACE FUNCTION public.admin_alert_scan()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare r record;
        mp int := coalesce((select value::int from public.app_settings where key = 'payout_alert_minutes'), 5);
        mu int := coalesce((select value::int from public.app_settings where key = 'unpicked_alert_minutes'), 30);
begin
  create temp table if not exists _want (key text, lvl text, text text, order_no bigint) on commit drop;
  delete from _want where true;
  insert into _want
    select 'unpicked:' || o.no, 'red', '🔴 №' || o.no || ': ҳеч ким олмаган (' || (extract(epoch from now() - o.created_at) / 60)::int || ' дақиқа)', o.no
      from public.orders o where o.picker_id is null and o.stage = 0 and o.pay_status in ('paid', 'none')
        and o.created_at < now() - make_interval(mins => mu) and o.created_at > now() - interval '3 days'
    union all
    select 'payout:' || p.id, 'red', '🔴 №' || p.order_no || ': дўконга тўлов кутилмоқда — ' || coalesce(s.shop, s.name, '') || ', ' || p.total || ' сўм', p.order_no
      from public.purchases p left join public.sellers s on s.id = p.shop_id
      where p.status = 'pending' and p.created_at < now() - make_interval(mins => mp)
    union all
    select 'ledger:' || c.order_no, 'red', '🔴 №' || c.order_no || ': пул журнали мувозанатда эмас (фарқ ' || c.diff || ')', c.order_no from public.ledger_check c
    union all
    select 'paycheck:' || x.order_no, 'red', '🔴 №' || x.order_no || ': тўлов ва буюртма мос эмас — ' || x.why, x.order_no from (
      select pm.order_no, 'тўланган тўлов бор, буюртма «тўланди» эмас (' || o.pay_status || ')' as why
        from public.payments pm join public.orders o on o.no = pm.order_no
       where pm.status = 'paid' and o.pay_status not in ('paid', 'refunded') and o.cancelled_at is null
      union
      select o.no, 'буюртма «тўланди», лекин тўланган тўлов йўқ'
        from public.orders o
       where o.pay_status = 'paid' and not exists (select 1 from public.payments pm where pm.order_no = o.no and pm.status = 'paid')
      union
      select pm.order_no, 'тўлов суммаси (' || pm.amount || ') буюртма суммасидан (' || o.pay_amount || ') фарқ қилади'
        from public.payments pm join public.orders o on o.no = pm.order_no
       where pm.status = 'paid' and o.pay_amount is not null and pm.amount <> o.pay_amount
    ) x
    union all
    select 'refund:' || r2.id, 'yellow', '🟡 №' || r2.order_no || ': қайтариш 24 соатдан ортиқ кутмоқда, ' || r2.amount || ' сўм', r2.order_no
      from public.refunds r2 where r2.status = 'pending' and r2.created_at < now() - interval '24 hours'
    union all
    select 'ticket:' || t.id, 'yellow', '🟡 Мурожаат №' || t.id || coalesce(' (буюртма №' || t.order_no || ')', '') || ': жавоб кутмоқда', t.order_no
      from public.tickets t where t.status = 'open' and t.created_at < now() - interval '10 minutes'
    union all
    select 'reg:' || s.id, 'info', 'ℹ️ Янги ариза: ' || s.role || ' — ' || coalesce(nullif(s.shop, ''), s.name), null
      from public.sellers s where s.status = 'pending';
  for r in
    insert into public.admin_alerts (key, lvl, text, order_no)
      select key, lvl, text, order_no from _want on conflict (key) where resolved_at is null do nothing returning text
  loop
    perform public.bot_post(jsonb_build_object('alert', r.text));
  end loop;
  update public.admin_alerts a set resolved_at = now() where a.resolved_at is null and not exists (select 1 from _want w where w.key = a.key);
end $function$;

commit;
