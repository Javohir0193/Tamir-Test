// Дўкон кабинети: Excel (.xlsx) файлдан нарх юклаш → бозор нархи билан текшириш → «Сақлаш» → базада нарх ва нарх тарихи.
// Сайт ҳақиқий seller.html; бот ўрнида gateway.mjs даги оддий нусха, нарх эса ҳақиқий SQL функциялар орқали ёзилади.
import { test, expect } from "@playwright/test";
import { createGateway, PROD_HOST, E2E_SELLER_ID, E2E_SELLER_SES } from "../gateway.mjs";
import { makeXlsx } from "../xlsx-fixture.mjs";

const PIDS = [202, 203, 204];   // seed.sql: 204 да бошқа дўконнинг нархи 100 000 (бозор медианаси)
let gw, hist0;
// нархлар аввалги ҳолига (бошқа тестлар учун); price_history фақат қўшилади — шу тестдаги ёзувлар id бўйича ажратилади
const cleanup = () => gw.query("delete from public.offers where seller_id = $1 and product_id = any($2)", [E2E_SELLER_ID, PIDS]);
test.beforeEach(async ({ context }) => {
  gw = createGateway(); await gw.install(context); await cleanup();
  hist0 = (await gw.query("select coalesce(max(id), 0) as n from public.price_history")).rows[0].n;
  await context.addInitScript((ses) => { try { localStorage.setItem("sel_ses", ses); } catch (e) {} }, E2E_SELLER_SES);
});
test.afterEach(async () => {
  expect(gw.blocked.filter((u) => u.includes(PROD_HOST)), "prod базага сўров кетмаслиги керак").toEqual([]);
  await cleanup(); await gw.pool.end();
});

test("дўкон Excel файлдан нарх юклайди, бозордан кескин фарқ қилган нарх белгиланмайди", async ({ page }) => {
  const errors = []; page.on("pageerror", (e) => errors.push(e.message));
  await page.goto("seller.html");
  await page.locator("[data-tab=prices]").click();
  await page.getByRole("button", { name: /Excel \/ CSV файлдан нарх юклаш/ }).click();

  // Намуна файл: сарлавҳа ва дўконнинг товарлари
  const dl = page.waitForEvent("download");
  await page.getByRole("button", { name: /Намуна файл/ }).click();
  const tpl = await (await dl).createReadStream().then((s) => new Promise((ok) => { let b = ""; s.on("data", (c) => b += c); s.on("end", () => ok(b)); }));
  expect(tpl.split(/\r?\n/)[0]).toBe("﻿ID;Номи;Тавсиф;Ўлчов;Нарх;Бор");
  expect(tpl).toContain("\n202;");

  // Excel: ID бўйича 2 та аниқ, 1 та бозордан 10 баравар қиммат, 1 та каталогда йўқ
  const file = makeXlsx([
    ["ID", "Номи", "Нарх", "Бор"],
    [202, "Песок мытый", 31000, "бор"],
    [203, "Ганч", "28 500 сўм", "йўқ"],
    [204, "Пескобетон М300", 1000000, "бор"],
    ["", "Ойнаванд эшик XYZ-9000", 5000, ""],
  ]);
  await page.locator("#impfile").setInputFiles({ name: "narxlar.xlsx", mimeType: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", buffer: file });
  await expect(page.getByText("4 қатор:")).toContainText("2 аниқ · 1 шубҳали · 1 топилмади");
  await expect(page.getByText(/Бозорда ~100 000 сўм, сизники \+900%/)).toBeVisible();
  await page.getByRole("button", { name: "Нархларга қўйиш (2)" }).click();

  await page.locator("#save").click();
  await expect(page.locator("#toast")).toContainText("2 та нарх сақланди");
  await expect(page.locator("#save")).toHaveText("Ўзгаришлар йўқ");

  const offers = (await gw.query("select product_id, price::int, in_stock from public.offers where seller_id = $1 and product_id = any($2) order by product_id", [E2E_SELLER_ID, PIDS])).rows;
  expect(offers).toEqual([{ product_id: 202, price: 31000, in_stock: true }, { product_id: 203, price: 28500, in_stock: false }]);
  const hist = (await gw.query("select product_id, source from public.price_history where seller_id = $1 and product_id = any($2) and id > $3 order by product_id", [E2E_SELLER_ID, PIDS, hist0])).rows;
  expect(hist).toEqual([{ product_id: 202, source: "seller_file" }, { product_id: 203, source: "seller_file" }]);
  expect(errors).toEqual([]);
});
