-- Ta'mir: TEST базани тозалаш (А вариант). ФАҚАТ test лойиҳада (ta'mir test)!
-- Ўчади: буюртмалар ва уларга боғлиқ ҳамма нарса (қаторлар, харидлар, тўловлар, қайтаришлар, пул журнали),
--        ходимга тўловлар (баланслар шундан ҳисобланади, демак 0 бўлади), тикетлар, ҳодисалар, админ огоҳлантиришлари,
--        вақтинчалик кириш токенлари, ботга юборилган сўровлар жавоблари.
-- Қолади: каталог, нархлар ва нарх тарихи, бозорлар, парклар, тарифлар, сотувчи/йиғувчи/ҳайдовчилар ва уларнинг
--        Telegram боғланиши, мижоз профиллари, админлар ва PIN, созламалар (bot_secret ҳам), аудит журнали, изоҳлар,
--        кирган сессиялар (ҳеч ким қайта кириши шарт эмас).
-- Буюртма рақамлари 1037 дан давом этади (нолдан бошланмайди: ботдаги эски хабарлар билан адашмаслик учун).
-- Захира: ўчишдан олдин ҳамма нарса ops.bk_reset_* жадвалларига нусхаланади. Орқага қайтариш пастда.

begin;

create schema if not exists ops;
revoke all on schema ops from public, anon, authenticated;

do $$
declare t text;
begin
  foreach t in array array['orders','order_lines','order_msgs','purchases','payments','refunds','ledger','staff_payouts',
                           'tickets','ticket_msgs','events','admin_alerts','login_tokens','driver_login','collector_login'] loop
    execute format('drop table if exists ops.bk_reset_%s', t);
    execute format('create table ops.bk_reset_%s as table public.%I', t, t);
  end loop;
end $$;

alter table public.ledger disable trigger ledger_no_truncate;
alter table public.ledger disable trigger ledger_no_change;
truncate public.orders, public.order_lines, public.order_msgs, public.purchases, public.payments, public.refunds, public.ledger,
         public.staff_payouts, public.tickets, public.ticket_msgs, public.events, public.admin_alerts,
         public.login_tokens, public.driver_login, public.collector_login;
alter table public.ledger enable trigger ledger_no_truncate;
alter table public.ledger enable trigger ledger_no_change;

delete from net._http_response;

commit;

-- Текшириш (алоҳида Run):
-- select (select count(*) from public.orders) orders, (select count(*) from public.ledger) ledger,
--        (select count(*) from public.sellers) sellers, (select count(*) from public.products) products,
--        (select count(*) from public.staff_balance_v where earned > 0) balances;
-- Кутилган: orders 0, ledger 0, balances 0, sellers ва products аввалгидек.

-- Орқага қайтариш (керак бўлса, алоҳида Run):
-- begin;
-- alter table public.ledger disable trigger ledger_no_change;
-- insert into public.orders select * from ops.bk_reset_orders;
-- insert into public.order_msgs select * from ops.bk_reset_order_msgs;
-- insert into public.order_lines select * from ops.bk_reset_order_lines;
-- insert into public.purchases select * from ops.bk_reset_purchases;
-- insert into public.payments select * from ops.bk_reset_payments;
-- insert into public.refunds select * from ops.bk_reset_refunds;
-- insert into public.ledger select * from ops.bk_reset_ledger;
-- insert into public.staff_payouts select * from ops.bk_reset_staff_payouts;
-- insert into public.tickets select * from ops.bk_reset_tickets;
-- insert into public.ticket_msgs select * from ops.bk_reset_ticket_msgs;
-- insert into public.events select * from ops.bk_reset_events;
-- insert into public.admin_alerts select * from ops.bk_reset_admin_alerts;
-- alter table public.ledger enable trigger ledger_no_change;
-- commit;
