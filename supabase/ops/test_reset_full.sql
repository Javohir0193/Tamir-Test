-- Ta'mir: TEST базани ТЎЛИҚ тозалаш (Б вариант). ФАҚАТ test лойиҳада (ta'mir test)!
-- Мақсад: ҳамма қайтадан рўйхатдан ўтади (дўкон, йиғувчи, ҳайдовчи, мижоз).
-- Ўчади: test_reset_data.sql даги ҳамма нарса (буюртмалар, тўловлар, пул журнали, тикетлар, ҳодисалар, огоҳлантиришлар)
--        + админдан бошқа ҳамма ходимлар (sellers: seller/collector/driver) ва уларнинг сессиялари,
--        дўкон нархлари (offers) ва нарх тарихи, админ бўлмаган мижоз профиллари ва қурилмалари.
-- Қолади: админлар (sellers.role = 'admin', admin_users, admin_sessions ва админ профили), PIN ва кириш,
--        каталог (products, categories, base_price), бозорлар, парклар, тарифлар, созламалар (bot_secret ҳам),
--        аудит журнали ва изоҳлар (ўзгармас жадваллар).
-- Бир телефон рақами билан бир нечта ролда рўйхатдан ўтиш базада чекланмаган (phone бўйича unique йўқ),
-- бот ҳам бир Telegram ҳисобдан дўкон, йиғувчи ва ҳайдовчини алоҳида-алоҳида қабул қилади.
-- Буюртма рақамлари давом этади (нолдан бошланмайди: ботдаги эски хабарлар билан адашмаслик учун).
-- Захира: ўчишдан олдин ҳамма нарса ops.bk_full_* жадвалларига нусхаланади. Орқага қайтариш пастда.

begin;

create schema if not exists ops;
revoke all on schema ops from public, anon, authenticated;

do $$
declare t text;
begin
  foreach t in array array['orders','order_lines','order_msgs','purchases','payments','refunds','ledger','staff_payouts',
                           'tickets','ticket_msgs','events','admin_alerts','login_tokens','driver_login','collector_login',
                           'driver_sessions','collector_sessions','offers','price_history','sellers','profiles','profile_devices'] loop
    execute format('drop table if exists ops.bk_full_%s', t);
    execute format('create table ops.bk_full_%s as table public.%I', t, t);
  end loop;
end $$;

-- 1. Буюртмалар ва пул (test_reset_data.sql билан бир хил)
alter table public.ledger disable trigger ledger_no_truncate;
alter table public.ledger disable trigger ledger_no_change;
truncate public.orders, public.order_lines, public.order_msgs, public.purchases, public.payments, public.refunds, public.ledger,
         public.staff_payouts, public.tickets, public.ticket_msgs, public.events, public.admin_alerts,
         public.login_tokens, public.driver_login, public.collector_login;
alter table public.ledger enable trigger ledger_no_truncate;
alter table public.ledger enable trigger ledger_no_change;

-- 2. Ходимлар: админдан бошқа ҳаммаси, сессиялари ва нархлари билан
truncate public.driver_sessions, public.collector_sessions, public.offers, public.price_history;
delete from public.sellers where role <> 'admin';

-- 3. Мижоз профиллари: админга боғланганидан бошқаси (қурилмалар cascade билан ўчади)
delete from public.profiles p where not exists (select 1 from public.admin_users a where a.profile_id = p.id);

delete from net._http_response;

commit;

-- Текшириш (алоҳида Run):
-- select (select count(*) from public.orders) orders, (select count(*) from public.offers) offers,
--        (select count(*) from public.sellers where role <> 'admin') staff, (select count(*) from public.sellers where role = 'admin') admins,
--        (select count(*) from public.profiles) profiles, (select count(*) from public.products) products;
-- Кутилган: orders 0, offers 0, staff 0, admins аввалгидек (1+), products аввалгидек.

-- Орқага қайтариш (керак бўлса, алоҳида Run):
-- begin;
-- alter table public.ledger disable trigger ledger_no_change;
-- insert into public.profiles select * from ops.bk_full_profiles p where not exists (select 1 from public.profiles x where x.id = p.id);
-- insert into public.profile_devices select * from ops.bk_full_profile_devices d where not exists (select 1 from public.profile_devices x where x.profile_id = d.profile_id);
-- insert into public.sellers select * from ops.bk_full_sellers s where s.role <> 'admin';
-- insert into public.offers select * from ops.bk_full_offers;
-- insert into public.price_history select * from ops.bk_full_price_history;
-- insert into public.driver_sessions select * from ops.bk_full_driver_sessions;
-- insert into public.collector_sessions select * from ops.bk_full_collector_sessions;
-- insert into public.orders select * from ops.bk_full_orders;
-- insert into public.order_msgs select * from ops.bk_full_order_msgs;
-- insert into public.order_lines select * from ops.bk_full_order_lines;
-- insert into public.purchases select * from ops.bk_full_purchases;
-- insert into public.payments select * from ops.bk_full_payments;
-- insert into public.refunds select * from ops.bk_full_refunds;
-- insert into public.ledger select * from ops.bk_full_ledger;
-- insert into public.staff_payouts select * from ops.bk_full_staff_payouts;
-- insert into public.tickets select * from ops.bk_full_tickets;
-- insert into public.ticket_msgs select * from ops.bk_full_ticket_msgs;
-- insert into public.events select * from ops.bk_full_events;
-- insert into public.admin_alerts select * from ops.bk_full_admin_alerts;
-- alter table public.ledger enable trigger ledger_no_change;
-- commit;
