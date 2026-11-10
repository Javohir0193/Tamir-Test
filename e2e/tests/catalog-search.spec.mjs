// Харидор қидируви: лотинда, сўз тартиби бошқача ёзилган сўров базадаги catalog_search орқали топилади (31-миграция).
import { test, expect } from "@playwright/test";
import { createGateway, PROD_HOST } from "../gateway.mjs";

let gw;
test.beforeEach(async ({ context }) => { gw = createGateway(); await gw.install(context); });
test.afterEach(async () => {
  expect(gw.blocked.filter((u) => u.includes(PROD_HOST)), "prod базага сўров кетмаслиги керак").toEqual([]);
  await gw.pool.end();
});

test("каталог қидируви: лотинча ва сўзлар аралаш", async ({ page }) => {
  const errors = []; page.on("pageerror", (e) => errors.push(e.message));
  const calls = []; page.on("request", (r) => { const m = r.url().match(/\/rpc\/(catalog_search|search_products)$/); if (m) calls.push(m[1]); });
  await page.goto("./");
  await page.getByText("E2E бозор", { exact: true }).first().click();
  await page.getByRole("button", { name: "Каталог" }).first().click();
  await page.getByRole("searchbox", { name: "Поиск по каталогу" }).fill("tovarniy beton m200");
  await expect(page.locator(".card[data-pid='200']")).toBeVisible();
  expect(calls).toContain("catalog_search");
  expect(calls).not.toContain("search_products");   // янги функция бор — эскисига тушмайди
  expect(errors).toEqual([]);
});
