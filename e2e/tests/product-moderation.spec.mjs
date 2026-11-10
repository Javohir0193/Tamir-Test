// Янги товар таклифи ва модерацияси: файлда топилмаган товар → дўкон «таклиф қилиш» → админ рад этади (сабаб билан) ёки
// тузатиб тасдиқлайди → дўкон «Менинг таклифларим» да ҳолатни кўради, тасдиқланган товар харидор каталогида чиқади.
// Админ қарори SQL'даги ягона қоида (product_decide) орқали — панель ва бот шуни чақиради.
import { test, expect } from "@playwright/test";
import { createGateway, PROD_HOST, E2E_SELLER_ID, E2E_SELLER_SES } from "../gateway.mjs";

let gw, made = [];
test.beforeEach(async ({ context }) => {
  gw = createGateway(); await gw.install(context);
  await context.addInitScript((ses) => { try { localStorage.setItem("sel_ses", ses); } catch (e) {} }, E2E_SELLER_SES);
});
test.afterEach(async () => {
  // яратилган товарларни ўчириш (кейинги тест уларни файлдаги ном билан «ўхшаш» деб топмасин)
  if (made.length) await gw.query("delete from public.products where name = any($1)", [made]);
  made = [];
  expect(gw.blocked.filter((u) => u.includes(PROD_HOST)), "prod базага сўров кетмаслиги керак").toEqual([]);
  await gw.pool.end();
});

test("дўкон файлда топилмаган товарни таклиф қилади, админ қароридан кейин ҳолатни кўради", async ({ page }, info) => {
  const errors = []; page.on("pageerror", (e) => errors.push(e.message));
  const tag = `${info.project.name} ${Date.now() % 100000}`;   // ҳар ишга туширишда янги ном (дубликат бўлмасин)
  const good = `Ойна витраж E2E ${tag}`, bad = `Эшик тахта E2E ${tag}`;
  made = [good, bad];

  await page.goto("seller.html");
  await page.locator("[data-tab=prices]").click();
  await page.getByRole("button", { name: /Excel \/ CSV файлдан нарх юклаш/ }).click();
  await page.locator("#imptxt").fill(`Номи;Тавсиф;Ўлчов;Нарх\n${good};4 мм;м²;85000\n${bad};;дона;300000`);
  await page.getByRole("button", { name: "Текшириш" }).click();
  await expect(page.getByText("2 қатор:")).toContainText("2 топилмади");
  await page.getByRole("button", { name: /Топилмаганларни таклиф қилиш \(2\)/ }).click();
  await expect(page.locator("[data-pmunit]").first()).toHaveValue("м²");   // файлдаги «Ўлчов» устуни
  await page.getByRole("button", { name: "Админга юбориш" }).click();
  await expect(page.locator("#toast")).toContainText("2 та товар админга юборилди");

  // Базада: иккаласи нофаол, ким таклиф қилгани ва нархи бор
  const rows = (await gw.query("select id, name, unit, active, proposed_by from public.products where name = any($1) order by id", [[good, bad]])).rows;
  expect(rows.map((r) => [r.name, r.unit, r.active, Number(r.proposed_by)])).toEqual([[good, "м²", false, E2E_SELLER_ID], [bad, "дона", false, E2E_SELLER_ID]]);
  const [g, b] = rows.map((r) => r.id);
  expect(Number((await gw.query("select price from public.offers where seller_id = $1 and product_id = $2", [E2E_SELLER_ID, g])).rows[0].price)).toBe(85000);

  // Админ: биттасини тузатиб тасдиқлайди, иккинчисини сабаб билан рад этади
  await gw.query(`select public.product_decide($1, true, null, '{"spec": "4 мм, шаффоф"}'::jsonb, 'admin')`, [g]);
  await gw.query("select public.product_decide($1, false, 'Каталогда бор: «Эшик»', '{}'::jsonb, 'admin')", [b]);

  // Дўкон «Менинг таклифларим»
  await page.getByRole("button", { name: "Ёпиш" }).first().click();
  await page.getByRole("button", { name: /Менинг таклифларим/ }).click();
  const mine = page.locator("#mplist");
  await expect(mine.locator(".irow", { hasText: good })).toContainText("Каталогда");
  await expect(mine.locator(".irow", { hasText: good })).toContainText("4 мм, шаффоф");
  await expect(mine.locator(".irow", { hasText: bad })).toContainText("Рад этилди");
  await expect(mine.locator(".irow", { hasText: bad })).toContainText("Сабаб: Каталогда бор: «Эшик»");

  // Харидор каталоги: тасдиқланган товар бор, рад этилгани йўқ (нархи ҳам ўчган)
  const pub = (await gw.query("select id from public.catalog_public where id = any($1)", [[g, b]])).rows.map((r) => r.id);
  expect(pub).toEqual([g]);
  expect(Number((await gw.query("select count(*) from public.offers where product_id = $1", [b])).rows[0].count)).toBe(0);
  expect(errors).toEqual([]);
});
