-- Ta'mir: админ «Комиссия» да дўкон буюртмалари саноғи янги тартибга мослаштирилади.
-- Сабаб: ҳисоблагич фақат эски purchases ни санарди, янги тартибда (товар йиғувчига топширилганда ҳисобланади) у 0 бўлиб қолаётганди,
--   шунинг учун «бепул: N та қолди» камаймасди (ҳисоблашнинг ўзи тўғри ишларди, фақат кўрсаткич нотўғри эди).
-- Нима ўзгаради: admin_commissions — «Буюртма» ва «бепул қолди» эски харидлар + топширилган буюртмалар (shop_handed) бўйича.
-- Нима ўзгармайди: жадваллар, комиссия ҳисоблаш, бошқа функциялар.
-- Орқага қайтариш: 20261031_24_commission_count.down.sql
-- Тартиб: 23 дан кейин. SQL Editor'га тўлиқ қўйиб Run.

begin;

CREATE OR REPLACE FUNCTION public.admin_commissions(p_code text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare def numeric := coalesce((select value::numeric from public.app_settings where key = 'seller_commission_pct'), 0);
        n int := coalesce((select value::int from public.app_settings where key = 'commission_free_orders'), 0);
begin
  perform public.admin_check(p_code); perform public.admin_need('payout');
  return jsonb_build_object('default', def, 'free_orders', n, 'can_edit', public.admin_can('settings'),
    'shops', coalesce((select jsonb_agg(x order by x->>'name') from (
      select jsonb_build_object('id', s.id, 'name', coalesce(nullif(s.shop, ''), s.name), 'row', s.row_no, 'status', s.status, 'own', s.commission_pct, 'effective', coalesce(s.commission_pct, def),
             'orders', c.k, 'free_left', case when s.commission_pct is null then greatest(0, n - c.k) else 0 end,
             'gross', coalesce(sum(p.total) filter (where p.status = 'paid'), 0), 'commission', coalesce(sum(p.commission) filter (where p.status = 'paid'), 0)) x
        from public.sellers s
        left join public.purchases p on p.shop_id = s.id
        left join lateral (select count(*)::int k from (select order_no::bigint no from public.purchases p2 where p2.shop_id = s.id and p2.status in ('pending', 'paid') union select h.no from public.shop_handed(s.id) h) u) c on true
       where s.role = 'seller' group by s.id, c.k) q), '[]'::jsonb));
end $function$;

commit;
