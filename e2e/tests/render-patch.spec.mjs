// Тезлаштириш (dom-patch.js): саҳифа «фақат ўзгарган жойни янгилаш» усулида чизилади. Бу тест ҳар қадамда
// шу усулда чизилган экранни нолдан (innerHTML) чизилгани билан солиштиради: матн, ўзбекча таржима ва иконкалар бир хил бўлиши керак.
// Яна: буюртмалар саҳифаси янгиланганда элементлар ўчирилиб қайта яратилмаслиги (скрол ва фокус жойида қолади).
import { test, expect } from "@playwright/test";
import { createGateway, PROD_HOST } from "../gateway.mjs";

const UID = "00000000-0000-4000-8000-00000000e2e0";
let gw, no = 0;
test.beforeEach(async ({ context }) => {
  gw = createGateway(); await gw.install(context);
  no = (await gw.query(`insert into public.orders (user_id, profile_id, customer_name, phone, items, mode, total, stage, market_id)
                        values ($1, 9001, 'E2E Харидор', '+998901112233', '[]', 'pickup', 700000, 0, 901) returning no`, [UID])).rows[0].no;
});
test.afterEach(async () => {
  await gw.query("delete from public.orders where no = $1", [no]);
  expect(gw.blocked.filter((u) => u.includes(PROD_HOST)), "prod базага сўров кетмаслиги керак").toEqual([]);
  await gw.pool.end();
});

// #view ҳозирги кўриниши ↔ шу экранни бўш жойга қайта чизиш (paint биринчи марта innerHTML ишлатади)
async function compareFresh(page) {
  const snap = () => page.evaluate(() => new Promise((ok) => requestAnimationFrame(() => requestAnimationFrame(() => setTimeout(() => {
    const v = document.getElementById("view").cloneNode(true);
    v.querySelectorAll("[data-due]").forEach((e) => { e.textContent = ""; });   // «Осталось: 4:31» — вақт ўтгани учун фарқ қилади
    ok({ text: v.textContent.replace(/\s+/g, " ").trim(), sk: v.querySelectorAll("span.sk").length,
         attrs: [...v.querySelectorAll("[aria-label],[placeholder]")].map((e) => (e.getAttribute("aria-label") || "") + "|" + (e.getAttribute("placeholder") || "")).join(";") });
  }, 30)))));
  const patched = await snap();
  await page.evaluate(() => { const v = document.getElementById("view"); v.textContent = ""; rerenderNow(); });
  const fresh = await snap();
  expect(patched).toEqual(fresh);
}

for (const lang of ["ru", "uz"]) test(`қисман янгилаш тўлиқ чизиш билан бир хил (${lang})`, async ({ page, context }) => {
  const errors = []; page.on("pageerror", (e) => errors.push(e.message));
  await context.addInitScript((l) => { try { localStorage.setItem("lang", l); } catch (e) {} }, lang);
  await page.addInitScript(() => {   // тест учун: ҳозирги бўлимни қайта чизиш
    window.rerenderNow = () => { if (S.tab === "orders") renderOrders(); else show(S.tab); };
  });
  await page.goto("./");
  await expect(page.locator("[data-mk='901']:visible").first()).toBeVisible();
  await page.locator("[data-mk='901']:visible").first().click();
  await compareFresh(page);
  await page.locator("[data-tab=catalog]:visible").first().click();
  await compareFresh(page);
  const grp = page.locator("#view [data-grp]").first();
  if (await grp.isVisible()) { await grp.click(); await compareFresh(page); }
  await page.locator(".card [data-add]").first().click();
  await page.locator(".card [data-inc]").first().click();
  await compareFresh(page);
  await page.locator("[data-tab=cart]:visible").first().click();
  await compareFresh(page);
  await page.locator("[data-tab=orders]:visible").first().click();
  await expect(page.locator(`[data-ord="${no}"]`)).toBeVisible();
  await compareFresh(page);
  // Буюртма ўзгарди (босқич) → янгиланади, лекин бошқа элементлар ўша-ўша қолади
  await page.evaluate((n) => { window.__keep = document.querySelector(`[data-ord="${n}"] h2`); }, no);
  await gw.query("update public.orders set pay_status = 'paid', paid_at = now(), stage = 1 where no = $1", [no]);
  await page.evaluate(() => loadOrders());
  await expect.poll(() => page.evaluate((n) => document.querySelector(`[data-ord="${n}"] [data-pay]`) === null, no)).toBe(true);
  expect(await page.evaluate((n) => window.__keep === document.querySelector(`[data-ord="${n}"] h2`) && window.__keep.isConnected, no)).toBe(true);
  await compareFresh(page);
  await page.locator("[data-tab=home]:visible").first().click();
  await compareFresh(page);
  if (lang === "uz") {   // тил алмаштирилса ҳам ҳамма матн тўғри русчага қайтади
    await page.locator("[data-tab=orders]:visible").first().click();
    await page.evaluate(() => setLang("ru"));
    await compareFresh(page);
    await expect(page.locator(`[data-ord="${no}"] h2`)).toHaveText(`Заказ №${no}`);
  }
  expect(errors).toEqual([]);
});
