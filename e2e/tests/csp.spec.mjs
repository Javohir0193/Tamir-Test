// CSP: script-src'да 'unsafe-inline' йўқ. Ҳар саҳифа (GitHub Pages каби, CSP <meta> дан) браузер блоклаган
// нарсасиз очилиши ва ўз коди (page-*.js) ишга тушиши керак. Inline <script> ёки onclick="…" қолса — шу ерда йиқилади.
import { test, expect } from "@playwright/test";
import { createGateway } from "../gateway.mjs";

let gw;
test.beforeEach(async ({ context }) => { gw = createGateway(); await gw.install(context); });
test.afterEach(async () => { await gw.pool.end(); });

// Саҳифа ва унинг коди юклангани белгиси (page-*.js даги глобал функция ёки ўзгарувчи)
const PAGES = [
  ["index.html", "typeof loadMarkets === 'function'"],
  ["admin.html", "typeof draw === 'function'"],
  ["seller.html", "typeof render === 'function'"],
  ["collector.html", "typeof refreshData === 'function'"],
  ["driver.html", "typeof load === 'function'"],
  ["register.html", "typeof draw === 'function'"],
];

for (const [path, ready] of PAGES) {
  test(`CSP: ${path} inline скриптсиз, бузилишсиз ишлайди`, async ({ page }) => {
    const v = [];
    await page.exposeBinding("__cspv", (_, x) => v.push(x));
    await page.addInitScript(() => document.addEventListener("securitypolicyviolation",
      (e) => window.__cspv(`${e.effectiveDirective} ← ${e.blockedURI || "inline"} (${(e.sourceFile || "").split("/").pop()}:${e.lineNumber})`)));
    await page.goto(path);
    const csp = await page.locator('meta[http-equiv="Content-Security-Policy"]').getAttribute("content");
    expect(csp).toMatch(/script-src 'self'/);
    expect(csp.match(/script-src[^;]*/)[0]).not.toContain("'unsafe-inline'");
    await expect.poll(() => page.evaluate(ready), { message: "саҳифа коди ишга тушмади" }).toBe(true);
    await page.waitForTimeout(500);
    expect(v, "CSP бузилишлари").toEqual([]);
  });
}
