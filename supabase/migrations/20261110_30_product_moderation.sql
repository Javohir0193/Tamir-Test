-- Ta'mir: янги товар таклифлари модерацияси — бир хил қоида (бот ва админ панели), сабаб, дўконга хабар.
-- Нима учун (ҳозир):
--   • бот таклиф id'сини max(id)+1 билан олади: икки дўкон бир вақтда юборса, бири хато билан йўқолади;
--   • дубликат фақат номи айнан бир хил бўлса аниқланади («Цемент М400» ва «sement m400» — икки хил товар бўлиб кетади);
--   • рад этишда сабаб сўралмайди, дўконга хабар бормайди, ким таклиф қилгани сақланмайди;
--   • ботдаги «✅/❌» тугмаси аллақачон ҳал қилинган таклифни қайта ўзгартира олади (reviewed_at текширилмайди).
-- Нима ўзгаради:
--   products: proposed_by (ким таклиф қилди), proposed_at, reject_reason устунлари (ҳаммаси ихтиёрий, эски қаторлар null).
--   product_proposal_seq: таклиф id'лари учун кетма-кетлик (1000 дан юқори, тўқнашмайди).
--   product_propose(by, shop, name, spec, cat, unit, price) — фақат бот (service_role): текширади (тоифа, ўлчов, нарх),
--     кирилл/лотин бўйича дубликатни топади (search_key_norm), дўконга 20 та / жами 300 та кутилаётган таклиф чеклови,
--     товарни active = false қилиб қўшади, нарх бўлса дўкон нархини ёзади, ўхшаш товарларни қайтаради.
--   product_decide(id, ok, reason, patch, via) — ягона «ҳал қилиш» қоидаси: фақат кутилаётган таклиф, тасдиқлашда номи/тоифаси/
--     ўлчовини тузатиш мумкин (patch), рад этилса нархлари ўчади, сабаб сақланади, таклиф қилганга Telegram хабар.
--   admin_product_decide(code, id, ok, reason, patch) — янги (5 аргументли): рад этишда сабаб шарт.
--   admin_product_decide(code, id, ok) — эскиси қолади (имзоси ва ҳуқуқи ўша), ичида product_decide чақирилади.
--   admin_product_proposals(code) — ўша имзо; жавобга qo'shimcha: by (ким), at (қачон), similar (ўхшаш фаол товарлар).
--   seller_proposals(seller) — дўконнинг ўз таклифлари ва ҳолати (кутилмоқда / қўшилди / рад этилди + сабаб), фақат бот.
-- Нима ўзгармайди: мавжуд товарлар, нархлар, catalog_public, бошқа функциялар. Бот янги функциялар йўқлигида эски йўлда ишлайди.
-- Орқага қайтариш: 20261110_30_product_moderation.down.sql
-- Тартиб: 29 дан кейин, аввал test базада. SQL Editor'га тўлиқ қўйиб Run. Кейин tg-bot (тартиб муҳим эмас).

begin;

alter table public.products add column if not exists proposed_by bigint;
alter table public.products add column if not exists proposed_at timestamptz;
alter table public.products add column if not exists reject_reason text;
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'products_proposed_by_fkey') then
    alter table public.products add constraint products_proposed_by_fkey foreign key (proposed_by) references public.sellers(id) on delete set null;
  end if;
end $$;
create index if not exists products_pending_idx on public.products (proposed_by) where not active and reviewed_at is null;

create sequence if not exists public.product_proposal_seq;
select setval('public.product_proposal_seq', greatest(1000, (select coalesce(max(id), 0) + 1 from public.products)), false);
revoke all on sequence public.product_proposal_seq from public, anon, authenticated;

-- Таклиф: фақат бот чақиради (дўкон ёки йиғувчи номидан). p_shop — нарх ёзиладиган дўкон (йиғувчи бозордаги дўкон учун таклиф қилади).
CREATE OR REPLACE FUNCTION public.product_propose(p_by bigint, p_shop bigint, p_name text, p_spec text, p_cat text, p_unit text, p_price bigint DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare who public.sellers; nm text := left(btrim(coalesce(p_name, '')), 80); sp text := left(btrim(coalesce(p_spec, '')), 80);
        un text := left(btrim(coalesce(p_unit, '')), 15); pr bigint := coalesce(p_price, 0); k text; nid int; dup public.products;
begin
  select * into who from public.sellers where id = p_by and role in ('seller', 'collector') and status = 'active';
  if not found then raise exception 'unknown_key'; end if;
  if p_shop is not null and not exists (select 1 from public.sellers where id = p_shop and role = 'seller') then raise exception 'unknown_key'; end if;
  if length(nm) < 2 or length(un) < 1 then raise exception 'bad_value'; end if;
  if not exists (select 1 from public.categories where id = p_cat) and exists (select 1 from public.categories) then raise exception 'bad_category'; end if;
  if pr < 0 or pr >= 1000000000 then raise exception 'bad_price'; end if;
  k := public.search_key_norm(nm || ' ' || sp);
  -- дубликат: каталогдаги товар (рус ёки ўзбекча номи) ёки кутилаётган таклиф билан бир хил «калит»
  select * into dup from public.products p
   where (p.active or p.reviewed_at is null)
     and (public.search_key_norm(p.name || ' ' || coalesce(p.spec, '')) = k
          or (p.name_uz is not null and public.search_key_norm(p.name_uz || ' ' || coalesce(p.spec_uz, '')) = k))
   order by p.active desc limit 1;
  if found then raise exception '%', case when dup.active then 'duplicate' else 'duplicate_pending' end using detail = dup.id::text; end if;
  if (select count(*) from public.products where not active and reviewed_at is null and proposed_by = p_by) >= 20 then raise exception 'too_many'; end if;
  if (select count(*) from public.products where not active and reviewed_at is null and id >= 1000) >= 300 then raise exception 'too_many'; end if;
  for i in 1 .. 5 loop   -- эски бот max(id)+1 билан ёзса ҳам тўқнашмасин
    nid := nextval('public.product_proposal_seq');
    begin
      insert into public.products (id, cat, name, spec, unit, emoji, base_price, active, proposed_by, proposed_at)
        values (nid, p_cat, nm, sp, un, '📦', pr, false, p_by, now());
      exit;
    exception when unique_violation then nid := null;
    end;
  end loop;
  if nid is null then raise exception 'busy'; end if;
  if pr > 0 and coalesce(p_shop, case when who.role = 'seller' then who.id end) is not null then
    insert into public.offers (seller_id, product_id, price, in_stock, updated_at) values (coalesce(p_shop, who.id), nid, pr, true, now())
      on conflict (seller_id, product_id) do update set price = excluded.price, in_stock = true, updated_at = now();
  end if;
  return jsonb_build_object('id', nid, 'similar', coalesce((select jsonb_agg(jsonb_build_object('id', s.id, 'name', s.name, 'spec', s.spec) order by s.sc desc)
     from (select p.id, p.name, p.spec, similarity(p.search_key, k) sc from public.products p where p.active and p.search_key % k order by 4 desc limit 3) s), '[]'::jsonb));
end $function$;

-- Ҳал қилиш (бот ва админ панели учун ягона қоида). p_via: 'admin' (панель) ёки 'bot'.
CREATE OR REPLACE FUNCTION public.product_decide(p_id integer, p_ok boolean, p_reason text DEFAULT NULL::text, p_patch jsonb DEFAULT '{}'::jsonb, p_via text DEFAULT 'admin'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare p public.products; n public.products; pt jsonb := coalesce(p_patch, '{}'::jsonb); rs text := nullif(left(btrim(coalesce(p_reason, '')), 300), ''); chat bigint;
begin
  if p_ok is null or p_via not in ('admin', 'bot') or jsonb_typeof(pt) <> 'object' then raise exception 'bad_value'; end if;
  select * into p from public.products where id = p_id for update;
  if not found or p.active or p.reviewed_at is not null then raise exception 'not_pending'; end if;
  if p_ok then
    if pt ? 'name' and length(btrim(pt->>'name')) < 2 then raise exception 'bad_value'; end if;
    if pt ? 'unit' and length(btrim(pt->>'unit')) < 1 then raise exception 'bad_value'; end if;
    if pt ? 'cat' and not exists (select 1 from public.categories where id = pt->>'cat') then raise exception 'bad_category'; end if;
    update public.products set active = true, reviewed_at = now(), reject_reason = null,
           name = coalesce(left(btrim(pt->>'name'), 80), name), spec = coalesce(left(btrim(pt->>'spec'), 80), spec),
           unit = coalesce(left(btrim(pt->>'unit'), 15), unit), cat = coalesce(pt->>'cat', cat)
     where id = p_id returning * into n;
  else
    update public.products set reviewed_at = now(), reject_reason = coalesce(rs, 'Сабаб кўрсатилмаган') where id = p_id returning * into n;
    delete from public.offers where product_id = p_id;
  end if;
  perform public.admin_log(case when p_ok then 'product_approve' else 'product_reject' end, 'product', p_id::text,
    jsonb_build_object('name', p.name, 'spec', p.spec, 'unit', p.unit, 'cat', p.cat),
    jsonb_build_object('name', n.name, 'spec', n.spec, 'unit', n.unit, 'cat', n.cat, 'active', p_ok, 'via', p_via), rs);
  select tg_chat_id into chat from public.sellers where id = p.proposed_by;
  if chat is not null then
    perform public.bot_post(jsonb_build_object('dm', jsonb_build_array(jsonb_build_object('chat_id', chat,
      'text', case when p_ok then '✅ Таклифингиз каталогга қўшилди: ' || n.name || coalesce(nullif(' (' || n.spec || ')', ' ()'), '')
                   else '❌ Таклифингиз рад этилди: ' || p.name || E'\nСабаб: ' || n.reject_reason end))));
  end if;
  return jsonb_build_object('id', n.id, 'name', n.name, 'spec', n.spec, 'active', n.active);
end $function$;

-- Админ панели: рад этишда сабаб шарт, тасдиқлашда тузатиш мумкин
CREATE OR REPLACE FUNCTION public.admin_product_decide(p_code text, p_id integer, p_ok boolean, p_reason text, p_patch jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  perform public.admin_check(p_code); perform public.admin_need('catalog');
  if not coalesce(p_ok, true) and length(btrim(coalesce(p_reason, ''))) < 3 then raise exception 'reason_required'; end if;
  return public.product_decide(p_id, p_ok, p_reason, coalesce(p_patch, '{}'::jsonb), 'admin');
end $function$;

-- Эски имзо (сайтнинг эски нусхаси учун): ўша натижа, лекин энди ягона қоида орқали
CREATE OR REPLACE FUNCTION public.admin_product_decide(p_code text, p_id integer, p_ok boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  perform public.admin_check(p_code); perform public.admin_need('catalog');
  perform public.product_decide(p_id, p_ok, null, '{}'::jsonb, 'admin');
end $function$;

CREATE OR REPLACE FUNCTION public.admin_product_proposals(p_code text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
begin
  perform public.admin_check(p_code); perform public.admin_need('catalog');
  return coalesce((select jsonb_agg(jsonb_build_object('id', p.id, 'cat', p.cat, 'name', p.name, 'spec', p.spec, 'unit', p.unit, 'base', p.base_price,
      'by', (select coalesce(nullif(s.shop, ''), s.name) || case when s.role = 'collector' then ' (йиғувчи)' else '' end from public.sellers s where s.id = p.proposed_by),
      'at', p.proposed_at,
      'offers', coalesce((select jsonb_agg(jsonb_build_object('shop', coalesce(nullif(s.shop, ''), s.name), 'price', f.price) order by f.price)
                 from public.offers f join public.sellers s on s.id = f.seller_id where f.product_id = p.id), '[]'::jsonb),
      'similar', coalesce((select jsonb_agg(jsonb_build_object('id', q.id, 'name', q.name, 'spec', q.spec) order by q.sc desc)
                 from (select a.id, a.name, a.spec, similarity(a.search_key, p.search_key) sc from public.products a
                        where a.active and a.search_key % p.search_key order by 4 desc limit 3) q), '[]'::jsonb)) order by p.id desc)
    from public.products p where not p.active and p.reviewed_at is null and p.id >= 1000), '[]'::jsonb);
end $function$;

CREATE OR REPLACE FUNCTION public.seller_proposals(p_seller bigint)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce(jsonb_agg(jsonb_build_object('id', p.id, 'name', p.name, 'spec', p.spec, 'unit', p.unit, 'cat', p.cat, 'at', p.proposed_at,
           'st', case when p.active then 'ok' when p.reviewed_at is null then 'wait' else 'no' end, 'reason', p.reject_reason) order by p.id desc), '[]'::jsonb)
    from (select * from public.products where proposed_by = p_seller order by id desc limit 50) p
$function$;

revoke all on function public.product_propose(bigint, bigint, text, text, text, text, bigint) from public, anon, authenticated;
revoke all on function public.product_decide(integer, boolean, text, jsonb, text) from public, anon, authenticated;
revoke all on function public.seller_proposals(bigint) from public, anon, authenticated;
revoke all on function public.admin_product_decide(text, integer, boolean, text, jsonb) from public, anon;
grant execute on function public.product_propose(bigint, bigint, text, text, text, text, bigint) to service_role;
grant execute on function public.product_decide(integer, boolean, text, jsonb, text) to service_role;
grant execute on function public.seller_proposals(bigint) to service_role;
grant execute on function public.admin_product_decide(text, integer, boolean, text, jsonb) to authenticated;

commit;

-- Текшириш (алоҳида ишга туширинг):
-- select proname, pronargs from pg_proc where proname in ('product_propose', 'product_decide', 'seller_proposals', 'admin_product_decide');   -- 5 қатор
-- select last_value from public.product_proposal_seq;
