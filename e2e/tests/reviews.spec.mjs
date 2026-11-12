// Баҳолар (32-миграция): етказилган буюртмада харидор дўконга ва товарга юлдуз қўяди → базада сақланади →
// каталогда товар картасида ўртача баҳо (⭐) кўринади. Ҳамма текширув серверда (review_save), сайт фақат кўрсатади.
import { test, expect } from "@playwright/test";
import { createGateway, PROD_HOST } from "../gateway.mjs";

const UID = "00000000-0000-4000-8000-00000000e2e0";   // e2e/seed.sql даги кирган харидор
let gw, no = 0;
test.beforeEach(async ({ context }) => {
  gw = createGateway(); await gw.install(context);
  // олиб кетиш буюртмаси, 3-босқич (берилди), дўкон 9001, товар 200
  no = (await gw.query(`insert into public.orders (user_id, profile_id, customer_name, phone, items, mode, total, stage, market_id)
                        values ($1, 9001, 'E2E Харидор', '+998901112233', '[]', 'pickup', 700000, 3, 901) returning no`, [UID])).rows[0].no;
  await gw.query("update public.orders set pay_status = 'paid', paid_at = now() where no = $1", [no]);   // orders_pay_init қўйган «unpaid» ўрнига
  await gw.query("insert into public.order_lines (order_no, line_no, name, qty, product_id, seller_id, price) values ($1, 1, 'Бетон М200', 1, 200, 9001, 700000)", [no]);
});
test.afterEach(async () => {
  await gw.query("delete from public.reviews where order_no = $1", [no]);
  await gw.query("delete from public.order_lines where order_no = $1", [no]);
  await gw.query("delete from public.orders where no = $1", [no]);
  expect(gw.blocked.filter((u) => u.includes(PROD_HOST)), "prod базага сўров кетмаслиги керак").toEqual([]);
  await gw.pool.end();
});

test("харидор етказилган буюртмани баҳолайди, каталогда ⭐ кўринади", async ({ page }) => {
  const errors = []; page.on("pageerror", (e) => errors.push(e.message));
  await page.goto("./");
  await page.getByRole("button", { name: "Заказы" }).first().click();
  const row = page.locator(`[data-oopen="${no}"]`);          // компьютерда ёпиқ қатор, телефонда ҳамма буюртма очиқ
  if (await row.count()) await row.click();
  await page.locator(`[data-rateopen="${no}"]`).click();
  await page.locator(`[data-rstar="${no}:shop:9001:4"]`).click();
  await page.locator(`[data-ratet="${no}:shop:9001"]`).fill("Тез тайёрлади");
  await page.locator(`[data-rstar="${no}:product:200:5"]`).click();
  await page.locator(`[data-ratesend="${no}"]`).click();
  await expect(page.locator("#toast")).toContainText("Спасибо за оценку");

  const rows = (await gw.query("select seller_id, product_id, rating, body, status from public.reviews where order_no = $1 order by seller_id nulls last", [no])).rows;
  expect(rows.map((r) => [r.seller_id && Number(r.seller_id), r.product_id, r.rating, r.body, r.status]))
    .toEqual([[9001, null, 4, "Тез тайёрлади", "shown"], [null, 200, 5, "", "shown"]]);
  await expect(page.locator(`[data-rateopen="${no}"]`)).toContainText("Изменить оценку");

  await page.getByRole("button", { name: "Каталог" }).first().click();
  await page.getByRole("searchbox", { name: "Поиск по каталогу" }).fill("Бетон М200");
  await expect(page.locator(".card[data-pid='200'] .rtg")).toContainText("5.0");
  expect(errors).toEqual([]);
});
