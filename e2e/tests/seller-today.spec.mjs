// Дўкон кабинети «Бугун»: ☑️ белгиси сервер кутмасдан дарҳол чизилади (олдин ҳар босишда бутун рўйхат серверга қайта сўраларди),
// экран «фақат ўзгарган жойни янгилаш» усулида (dom-patch.js) — карточка ўчирилиб қайта яратилмайди.
import { test, expect } from "@playwright/test";
import { createGateway, PROD_HOST, E2E_SELLER_SES } from "../gateway.mjs";

let gw;
test.beforeEach(async ({ context }) => {
  gw = createGateway(); await gw.install(context);
  await context.addInitScript((ses) => { try { localStorage.setItem("sel_ses", ses); } catch (e) {} }, E2E_SELLER_SES);
});
test.afterEach(async () => {
  expect(gw.blocked.filter((u) => u.includes(PROD_HOST)), "prod базага сўров кетмаслиги керак").toEqual([]);
  await gw.pool.end();
});

test("☑️ белгиси дарҳол, серверга бормасдан; карточка ўша-ўша", async ({ page }) => {
  const errors = []; page.on("pageerror", (e) => errors.push(e.message));
  let calls = 0;
  const order = { no: 501, msg_id: 77, slot: "Бугун 14:00", confirmed: true, ready: false, lines: [
    { line_no: 1, name: "Цемент М400", qty: 2, unit: "қоп", price: 60000, says_yes: true, status: "ok", loaded: false },
    { line_no: 2, name: "Қум", qty: 1, unit: "қоп", price: 15000, says_yes: true, status: "ok", loaded: false }] };
  await page.route("**/functions/v1/tg-bot", async (route) => {
    let a = ""; try { a = JSON.parse(route.request().postData() || "{}").action; } catch (e) {}
    if (a !== "s_orders") return route.fallback();
    calls++; return route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify({ orders: [order], sc: true }) });
  });
  await page.goto("seller.html");
  const main = page.locator(".oacts .main");
  await expect(main).toContainText("0/2");
  const card = await page.locator("#today .list").first().elementHandle();
  const before = calls;
  await page.locator('[data-chk="77:1"]').click();
  await expect(main).toContainText("1/2");
  await page.locator('[data-chk="77:2"]').click();
  await expect(page.locator("[data-ordready='77']")).toBeVisible();
  expect(calls, "белги учун серверга сўров кетмади").toBe(before);
  await page.locator("[data-ordreload]").click();                    // «🔄 Янгилаш» — сервердан, лекин карточка қайта яратилмайди
  await expect.poll(() => calls).toBe(before + 1);
  await expect(page.locator("[data-ordready='77']")).toBeVisible();
  expect(await card.evaluate((el) => el.isConnected), "карточка ўша-ўша элемент").toBe(true);
  expect(errors).toEqual([]);
});
