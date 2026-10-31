-- Ta'mir: эски аризадан ўтган дўконга картани админ киритади.
-- Нима учун: 18-сонгача дўкон аризасида карта сўралмаган, шундай дўконларда «Карта: йўқ», пул ўтказиб бўлмайди.
-- Нима ўзгаради: янги функция admin_shop_card(p_code, p_id, p_card, p_holder).
--   Рухсат: фақат 'payout' ҳуқуқи (эга ёки бухгалтер). Карта 16 рақам, эгасининг исми 3+ белги.
--   Аудит журналига эски ва янги карта фақат охирги 4 рақами билан ёзилади. Дўкон эгасига ботда хабар боради.
-- Нима ўзгармайди: жадваллар ва бошқа функциялар.
-- Орқага қайтариш: 20261031_19_admin_shop_card.down.sql
-- Тартиб: 18 дан кейин. SQL Editor'га тўлиқ қўйиб Run.

begin;

CREATE OR REPLACE FUNCTION public.admin_shop_card(p_code text, p_id bigint, p_card text, p_holder text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare s public.sellers; d text := regexp_replace(coalesce(p_card, ''), '\D', '', 'g'); h text := left(btrim(coalesce(p_holder, '')), 60);
begin
  perform public.admin_check(p_code); perform public.admin_need('payout');
  if length(d) <> 16 then raise exception 'bad_card'; end if;
  if length(h) < 3 then raise exception 'holder_required'; end if;
  select * into s from public.sellers where id = p_id and role = 'seller';
  if not found then raise exception 'unknown_key'; end if;
  update public.sellers set card = regexp_replace(d, '(\d{4})(?=\d)', '\1 ', 'g'), card_holder = h where id = p_id;
  perform public.admin_log('shop_card', 'seller', p_id::text,
    jsonb_build_object('card', public.mask_card(s.card), 'holder', s.card_holder), jsonb_build_object('card', public.mask_card(d), 'holder', h), null);
  if s.tg_chat_id is not null then
    perform public.bot_post(jsonb_build_object('dm', jsonb_build_array(jsonb_build_object('chat_id', s.tg_chat_id,
      'text', '💳 Дўконингизга тўлов картаси киритилди: •••• ' || right(d, 4) || '. Агар бу сизнинг картангиз бўлмаса, дарҳол администраторга ёзинг.'))));
  end if;
end $function$;

revoke all on function public.admin_shop_card(text, bigint, text, text) from public;
grant execute on function public.admin_shop_card(text, bigint, text, text) to authenticated;

commit;
