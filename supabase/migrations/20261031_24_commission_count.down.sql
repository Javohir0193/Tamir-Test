-- 24 ни орқага қайтариш (эски санаш).
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
        left join lateral (select count(distinct p2.order_no)::int k from public.purchases p2 where p2.shop_id = s.id and p2.status in ('pending', 'paid')) c on true
       where s.role = 'seller' group by s.id, c.k) q), '[]'::jsonb));
end $function$;

commit;
