// Асосий оқим: бозор танлаш → товар саватга → буюртма → «Тестовая оплата» → «Оплачено».
// Сайт ҳақиқий index.html, база — маҳаллий Postgres'даги ҳақиқий функциялар (gateway.mjs). Test/prod Supabase ишлатилмайди.
import { test, expect } from "@playwright/test";
import { createGateway, PROD_HOST } from "../gateway.mjs";

let gw;
test.beforeEach(async ({ context }) => { gw = createGateway(); await gw.install(context); });
test.afterEach(async () => {
  expect(gw.blocked.filter((u) => u.includes(PROD_HOST)), "prod базага сўров кетмаслиги керак").toEqual([]);
  await gw.pool.end();
});

test("харидор буюртма беради ва синов тўлови билан тўлайди", async ({ page }) => {
  const errors = []; page.on("pageerror", (e) => errors.push(e.message));
  const before = (await gw.query("select coalesce(max(no), 0) as n from public.orders")).rows[0].n;

  await page.goto("./");
  // 1) Бозор
  await page.getByText("E2E бозор", { exact: true }).first().click();
  // 2) Товар: қидирувдан «Бетон М200» → саватга
  await page.getByRole("button", { name: "Каталог" }).first().click();
  await page.getByRole("searchbox", { name: "Поиск по каталогу" }).fill("Бетон М200");
  const card = page.locator(".card[data-pid='200']");
  await card.locator("[data-add]").click();
  // 3) Сават: самовывоз (манзил/харита керак эмас), исм ва телефон профилдан келади
  await page.getByRole("button", { name: "Корзина" }).first().click();
  await expect(page.getByText("Вы вошли через Telegram")).toBeVisible();
  await page.locator("input[name=mode][value=pickup]").check();
  const send = page.locator("#copyOrder");
  await expect(send).toContainText("Оформить заказ");
  await send.click();
  // 4) Буюртма базада пайдо бўлди, сумма серверда ҳисобланди (энг арзон дўкон: 690 000)
  await expect.poll(async () => (await gw.query("select count(*)::int as n from public.orders where no > $1", [before])).rows[0].n).toBe(1);
  const o = (await gw.query("select no, goods_sum, pay_status, pay_amount, phone from public.orders where no > $1", [before])).rows[0];
  expect(Number(o.goods_sum)).toBe(690000);
  expect(o.pay_status).toBe("unpaid");
  expect(o.phone).toBe("+998901112233");
  // 5) «Заказы»: тўлов блоки ва синов тугмаси (test муҳитида)
  const testPay = page.locator(`[data-pay=test][data-no="${o.no}"]`);
  await expect(testPay).toBeVisible();
  await expect(testPay).toContainText("Тестовая оплата");
  await testPay.click();
  await expect(page.getByText("Оплата прошла")).toBeVisible();
  // 6) База: тўланди, payments'да битта «test» ёзуви, сумма = pay_amount
  const after = (await gw.query("select pay_status, pay_provider from public.orders where no = $1", [o.no])).rows[0];
  expect(after).toEqual({ pay_status: "paid", pay_provider: "test" });
  const pays = (await gw.query("select amount from public.payments where order_no = $1 and provider = 'test'", [o.no])).rows;
  expect(pays.map((p) => Number(p.amount))).toEqual([Number(o.pay_amount)]);
  await expect(testPay).toHaveCount(0);   // тўлангандан кейин тугма йўқолади
  expect(errors).toEqual([]);
});
