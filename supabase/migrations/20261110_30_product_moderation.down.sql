-- 30 ни орқага қайтариш: таклиф ва ҳал қилиш функциялари ўчади, admin_product_proposals ва admin_product_decide(3 аргумент)
-- 16-миграциядаги ҳолига қайтади. Бот янги функциялар йўқлигини кўриб эски йўлда ишлайди.
-- ДИҚҚАТ: proposed_by / proposed_at / reject_reason устунлари ўчади (ким таклиф қилгани ва рад этиш сабаби йўқолади).
-- Товарларнинг ўзи, active / reviewed_at ва нархлар қолади.
begin;

drop function if exists public.admin_product_decide(text, integer, boolean, text, jsonb);
drop function if exists public.product_decide(integer, boolean, text, jsonb, text);
drop function if exists public.product_propose(bigint, bigint, text, text, text, text, bigint);
drop function if exists public.seller_proposals(bigint);

CREATE OR REPLACE FUNCTION public.admin_product_proposals(p_code text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  perform public.admin_check(p_code); perform public.admin_need('catalog');
  return coalesce((select jsonb_agg(jsonb_build_object('id', p.id, 'cat', p.cat, 'name', p.name, 'spec', p.spec, 'unit', p.unit, 'base', p.base_price,
      'offers', coalesce((select jsonb_agg(jsonb_build_object('shop', coalesce(nullif(s.shop, ''), s.name), 'price', f.price) order by f.price)
                 from public.offers f join public.sellers s on s.id = f.seller_id where f.product_id = p.id), '[]'::jsonb)) order by p.id desc)
    from public.products p where not p.active and p.reviewed_at is null and p.id >= 1000), '[]'::jsonb);
end $function$;

-- админ: таклифни каталогга қўшиш ёки рад этиш (ботдаги npa / npr билан бир хил: рад этилса нархлари ўчади)
CREATE OR REPLACE FUNCTION public.admin_product_decide(p_code text, p_id integer, p_ok boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare p public.products;
begin
  perform public.admin_check(p_code); perform public.admin_need('catalog');
  select * into p from public.products where id = p_id for update;
  if not found or p.active or p.reviewed_at is not null then raise exception 'not_pending'; end if;
  update public.products set active = p_ok, reviewed_at = now() where id = p_id;
  if not p_ok then delete from public.offers where product_id = p_id; end if;
  perform public.admin_log(case when p_ok then 'product_approve' else 'product_reject' end, 'product', p_id::text, null, jsonb_build_object('name', p.name, 'active', p_ok), null);
end $function$;

drop index if exists public.products_pending_idx;
alter table public.products drop constraint if exists products_proposed_by_fkey;
alter table public.products drop column if exists proposed_by;
alter table public.products drop column if exists proposed_at;
alter table public.products drop column if exists reject_reason;
drop sequence if exists public.product_proposal_seq;

commit;
