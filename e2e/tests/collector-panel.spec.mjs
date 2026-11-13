// Йиғувчи кабинети (collector.html): ҳар 3 сониялик текширувда экран «фақат ўзгарган жойни янгилаш» усулида чизилади (dom-patch.js).
// Бот (tg-bot) жавоблари шу тестда сохта: янги буюртма тушади → рўйхатга қўшилади, эски карточкалар ўчирилиб қайта яратилмайди;
// нархлар бўлимида қидирув майдони ёзиш пайтида алмашмайди (клавиатура ёпилмайди).
import { test, expect } from "@playwright/test";
import { createGateway, PROD_HOST } from "../gateway.mjs";

let gw;
test.beforeEach(async ({ context }) => {
  gw = createGateway(); await gw.install(context);
  await context.addInitScript(() => { try { localStorage.setItem("col_ses", "e2e-collector-session"); localStorage.setItem("app_lang", "uz"); } catch (e) {} });
});
test.afterEach(async () => {
  expect(gw.blocked.filter((u) => u.includes(PROD_HOST)), "prod базага сўров кетмаслиги керак").toEqual([]);
  await gw.pool.end();
});

test("янги буюртма тушади, эски карточкалар ўша-ўша; қидирув майдони алмашмайди", async ({ page }) => {
  const errors = []; page.on("pageerror", (e) => errors.push(e.message));
  const line = (n, st) => ({ line_no: n, name: "Товар " + n, qty: 1, unit: "дона", status: st, product_id: null, client_price: 1000, loaded: false });
  const D = { me: { name: "E2E Йиғувчи", market: "E2E бозор" }, sc: false, shops: [{ id: 1, name: "E2E дўкон", row: "1-қатор" }],
    products: [{ id: 99001, name: "Цемент Е2Е", spec: "қоп", unit: "қоп" }, { id: 99002, name: "Қум Е2Е", spec: "қоп", unit: "қоп" }], cats: [],
    open: [{ no: 601, n: 2, total: 50000, slot: "Бугун", address: "" }],
    my: [{ no: 600, customer: "Мижоз", slot: "Бугун", stage: 1, driver_id: null, lines: [line(1, "ready"), line(2, "pending")] }],
    earn: { due: 0, waiting: 0, held: 0, paid: 0 }, split: null };
  let sig = 1;
  await page.route("**/functions/v1/tg-bot", async (route) => {
    let a = ""; try { a = JSON.parse(route.request().postData() || "{}").action; } catch (e) {}
    const ok = (b) => route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify(b) });
    if (a === "c_load") return ok(D);
    if (a === "c_ping") return ok({ open: D.open.map((o) => o.no), sig: String(sig) });
    if (a === "c_offers") return ok({ offers: {} });
    return route.fallback();
  });
  await page.goto("collector.html");
  const mine = page.locator('[data-openo="600"]');
  await expect(mine).toContainText("1 / 2");
  const h1 = await page.locator("#app h1").elementHandle(), card = await mine.elementHandle();

  // янги буюртма ва «олинди» сони ўзгарди
  D.open = [...D.open, { no: 602, n: 1, total: 9000, slot: "Эртага", address: "" }];
  D.my[0].lines[1].status = "ready"; sig++;
  await expect(page.locator('[data-claim="602"]')).toBeVisible({ timeout: 8000 });
  await expect(mine).toContainText("2 / 2");
  expect(await h1.evaluate((el) => el.isConnected), "сарлавҳа қайта яратилмади").toBe(true);
  expect(await card.evaluate((el) => el.isConnected), "карточка ўша-ўша элемент").toBe(true);

  // нархлар: қидирув
  await page.locator("nav button[data-tab=prices]").click();
  await page.locator("#pshopSel").selectOption("1");
  const q = page.locator("#pq");
  await q.click();
  const qh = await q.elementHandle();
  await q.pressSequentially("цем", { delay: 20 });
  await expect(page.locator("[data-pp]")).toHaveCount(1);
  expect(await qh.evaluate((el) => el.isConnected && document.activeElement === el), "майдон ўша-ўша, фокусда").toBe(true);
  await expect(q).toHaveValue("цем");
  expect(errors).toEqual([]);
});
