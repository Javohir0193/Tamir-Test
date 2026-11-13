// Ҳайдовчи иловаси (driver.html): экран «фақат ўзгарган жойни янгилаш» усулида чизилади (dom-patch.js).
// Текширилади: галочкалар сервер жавобини кутмасдан белгиланади ва базага ёзилади (PR #75 тузатиши бузилмаган),
// ҳар 3 сониялик янгиланишда сарлавҳа ва карточкалар ўчирилиб қайта яратилмайди, «Йўлга чиқдим» тугмаси санаб боради.
import { test, expect } from "@playwright/test";
import { createGateway, PROD_HOST } from "../gateway.mjs";

const SES = "e2e-driver-session";
let gw, drv = 0, no = 0;
test.beforeEach(async ({ context }) => {
  gw = createGateway(); await gw.install(context);
  drv = (await gw.query("insert into public.sellers (name, role, status, car) values ('E2E Ҳайдовчи', 'driver', 'active', 'Damas') returning id")).rows[0].id;
  await gw.query("insert into public.driver_sessions (seller_id, token_hash) values ($1, encode(extensions.digest($2, 'sha256'), 'hex'))", [drv, SES]);
  no = (await gw.query(`insert into public.orders (user_id, customer_name, phone, items, mode, total, stage, market_id, driver_id, address)
                        values ($2, 'E2E Мижоз', '+998901112233', '[]', 'delivery', 700000, 1, 901, $1, 'Тошкент, 1-уй') returning no`, [drv, "00000000-0000-4000-8000-00000000e2e0"])).rows[0].no;
  await gw.query(`insert into public.order_lines (order_no, line_no, name, qty, unit, product_id, seller_id, price) values
                  ($1, 1, 'Бетон М200', 1, 'м³', 200, 9001, 690000), ($1, 2, 'Шағал', 2, 'қоп', null, 9001, 15000)`, [no]);
});
test.afterEach(async () => {
  await gw.query("delete from public.order_lines where order_no = $1", [no]);
  await gw.query("delete from public.orders where no = $1", [no]);
  await gw.query("delete from public.driver_sessions where seller_id = $1", [drv]);
  await gw.query("delete from public.sellers where id = $1", [drv]);
  expect(gw.blocked.filter((u) => u.includes(PROD_HOST)), "prod базага сўров кетмаслиги керак").toEqual([]);
  await gw.pool.end();
});

test("ҳайдовчи галочкаларни белгилайди, экран қайта яратилмайди", async ({ page, context }) => {
  const errors = []; page.on("pageerror", (e) => errors.push(e.message));
  await context.addInitScript((s) => { try { localStorage.setItem("drv_ses", s); localStorage.setItem("app_lang", "uz"); } catch (e) {} }, SES);
  await page.goto("./driver.html");
  await page.locator("button[data-t=mine]").click();
  const go = page.locator(`button[data-go="${no}"]`);
  await expect(go).toBeDisabled();
  await expect(go).toContainText("0/2");
  const h1 = await page.locator("header h1").elementHandle();
  const card = await go.elementHandle();

  const boxes = page.locator(`input[data-ld^="${no}:"]`);
  await boxes.nth(0).check();
  await expect(go).toContainText("1/2");                              // дарҳол, сервер кутмасдан
  await boxes.nth(1).check();
  await expect(go).toBeEnabled();
  await expect.poll(async () => (await gw.query("select count(*)::int as n from public.order_lines where order_no = $1 and loaded", [no])).rows[0].n).toBe(2);

  await page.waitForTimeout(3500);                                    // камида битта 3 сониялик янгиланиш
  await expect(boxes.nth(0)).toBeChecked();
  await expect(boxes.nth(1)).toBeChecked();
  expect(await h1.evaluate((el) => el.isConnected), "сарлавҳа қайта яратилмади").toBe(true);
  expect(await card.evaluate((el) => el.isConnected), "тугма ўша-ўша элемент").toBe(true);

  // Бошқа жойдан ўзгариш (масалан, админ бир қаторни бекор қилди) — фақат шу қатор янгиланади
  await gw.query("update public.order_lines set loaded = false where order_no = $1 and line_no = 2", [no]);
  await expect(boxes.nth(1)).not.toBeChecked({ timeout: 8000 });
  await expect(go).toBeDisabled();
  expect(await h1.evaluate((el) => el.isConnected)).toBe(true);
  expect(errors).toEqual([]);
});
