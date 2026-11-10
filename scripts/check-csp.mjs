// CSP текшируви: _headers даги сарлавҳалар билан ҳар бир саҳифани Chromium'да очади ва браузер блоклаган
// (securitypolicyviolation) нарсаларни санайди. Ташқи манбалар (CDN, Supabase, Telegram, шрифтлар) тармоққа
// чиқмасдан сохта жавоб билан алмаштирилади, аммо CSP уларни ҳақиқий манзили бўйича текширади.
// Ишлатиш:  node scripts/check-csp.mjs [--pages] [кутубхоналар_папкаси]
//   --pages — GitHub Pages каби сарлавҳасиз ишга туширади (фақат мета-тег CSP текширилади)
//   кутубхоналар_папкаси (ихтиёрий) — npm pack қилинган supabase-js@2.45.4 ва leaflet@1.9.4 турган жой;
//   берилмаса сохта кутубхона ишлатилади (CSP учун етарли, лекин харита каби динамик қисмлар текширилмайди).
// Playwright ва Chromium керак (CI'да йўқ, маҳаллий текширув).
import { createServer } from "node:http";
import { readFileSync, existsSync, readdirSync } from "node:fs";
import { join, extname, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { createRequire } from "node:module";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
const PAGES_MODE = process.argv.includes("--pages");     // GitHub Pages каби: сарлавҳасиз, фақат саҳифадаги <meta> CSP
const LIBS = process.argv.slice(2).find((a) => !a.startsWith("--")) || "";
const require = createRequire(import.meta.url);
let chromium;
try { ({ chromium } = require("playwright")); } catch { ({ chromium } = await import("playwright")); }

// _headers: «/йўл» қатори, кейин «  Ном: қиймат» қаторлари. Бир хил ном бир неча қоидадан келса — вергул билан (Netlify каби).
function parseHeaders() {
  const rules = []; let cur = null;
  for (const line of readFileSync(join(ROOT, "_headers"), "utf8").split("\n")) {
    if (!line.trim() || line.trim().startsWith("#")) continue;
    if (!/^\s/.test(line)) { cur = { path: line.trim(), h: [] }; rules.push(cur); continue; }
    const i = line.indexOf(":"); cur.h.push([line.slice(0, i).trim(), line.slice(i + 1).trim()]);
  }
  return rules;
}
const RULES = parseHeaders();
function headersFor(path) {
  const out = {};
  for (const r of RULES) {
    const ok = r.path === "/*" || r.path === path || (r.path.endsWith("/*") && path.startsWith(r.path.slice(0, -1)));
    if (!ok) continue;
    for (const [k, v] of r.h) out[k] = out[k] ? out[k] + ", " + v : v;
  }
  return out;
}
const TYPES = { ".html": "text/html; charset=utf-8", ".js": "text/javascript", ".css": "text/css", ".png": "image/png", ".webmanifest": "application/manifest+json", ".json": "application/json" };

const server = createServer((req, res) => {
  let p = decodeURIComponent(new URL(req.url, "http://x").pathname);
  if (p === "/") p = "/index.html";
  const f = join(ROOT, p);
  if (!f.startsWith(ROOT) || !existsSync(f)) { res.writeHead(404); res.end(); return; }
  res.writeHead(200, { "content-type": TYPES[extname(f)] || "application/octet-stream", ...(PAGES_MODE ? {} : headersFor(p)) });
  res.end(readFileSync(f));
});
await new Promise((r) => server.listen(0, "127.0.0.1", r));
const BASE = `http://127.0.0.1:${server.address().port}`;

function lib(rel) {
  if (!LIBS) return null;
  for (const d of readdirSync(LIBS)) { const f = join(LIBS, d, "package", rel); if (existsSync(f)) return readFileSync(f); }
  return null;
}
const FAKE_SB = "window.supabase={createClient:function(){var q=function(){return p};var p=new Proxy(function(){},{get:function(t,k){if(k==='then')return function(r){r({data:null,error:null})};return q},apply:function(){return p}});return p}};";
async function stubs(page) {
  await page.route(/^https?:\/\/(?!127\.0\.0\.1)/, async (route) => {
    const u = new URL(route.request().url());
    const ok = (body, type) => route.fulfill({ status: 200, contentType: type, body, headers: { "access-control-allow-origin": "*", "access-control-allow-headers": "*" } });
    if (u.hostname.endsWith(".supabase.co")) return ok(u.pathname.includes("/rpc/") ? "null" : "[]", "application/json");
    if (u.hostname === "cdn.jsdelivr.net" && u.pathname.includes("supabase-js")) return ok(lib("dist/umd/supabase.js") || FAKE_SB, "text/javascript");
    if (u.hostname === "cdnjs.cloudflare.com" && u.pathname.includes("leaflet")) {
      const name = u.pathname.split("/").pop();
      if (name.endsWith(".css")) return ok(lib("dist/leaflet.css") || "", "text/css");
      if (name.endsWith(".js")) return ok(lib("dist/leaflet.js") || "", "text/javascript");
      return ok(lib("dist/images/" + name) || Buffer.alloc(0), "image/png");
    }
    if (u.hostname === "telegram.org") return ok("window.Telegram={WebApp:{initData:'',ready(){},expand(){},onEvent(){},MainButton:{}}};", "text/javascript");
    if (u.hostname === "fonts.googleapis.com") return ok("", "text/css");
    if (/\.(png|jpg|svg)$/.test(u.pathname) || u.hostname.includes("tile.openstreetmap")) return ok(Buffer.alloc(0), "image/png");
    return ok("", "text/plain");
  });
}

const PAGES = ["/", "/index.html", "/admin.html", "/collector.html", "/driver.html", "/seller.html", "/register.html"];
const browser = await chromium.launch();
let bad = 0;
for (const path of PAGES) {
  const ctx = await browser.newContext({ serviceWorkers: "block", viewport: { width: 390, height: 844 } });
  const page = await ctx.newPage();
  const v = [];
  await page.exposeBinding("__cspv", (_, x) => v.push(x));
  await page.addInitScript(() => document.addEventListener("securitypolicyviolation",
    (e) => window.__cspv(`${e.effectiveDirective} ← ${e.blockedURI || "inline"} (${(e.sourceFile || "").split("/").pop()}:${e.lineNumber})`)));
  page.on("console", (m) => { if (m.type() === "error" && /Content Security Policy/i.test(m.text())) v.push(m.text().slice(0, 200)); });
  await stubs(page);
  const res = await page.goto(BASE + path, { waitUntil: "load" });
  const csp = PAGES_MODE ? await page.$eval('meta[http-equiv="Content-Security-Policy"]', (m) => m.content).catch(() => "")
    : res.headers()["content-security-policy"] || "";
  if (!csp) { console.log(`✗ ${path}: CSP сарлавҳаси йўқ`); bad++; }
  // Ҳар бир тугма/табни бир марта босиш — динамик юкланадиган манбалар (харита, xlsx) ҳам текширилсин.
  await page.waitForTimeout(3000);
  for (const sel of ["[data-tab]", "[data-go]", "[data-nav]", "button"]) {
    const els = await page.$$(sel);
    for (const el of els.slice(0, 15)) { try { await el.click({ timeout: 300, noWaitAfter: true }); await page.waitForTimeout(80); } catch {} }
  }
  await page.waitForTimeout(1500);
  const uniq = [...new Set(v)];
  console.log(`${uniq.length ? "✗" : "✓"} ${path}: ${uniq.length} та CSP бузилиши`);
  for (const x of uniq) console.log("    " + x);
  bad += uniq.length;
  await ctx.close();
}
// iframe ичида очиш: админ ҳеч ким ичида очилмаслиги, бошқа саҳифалар бегона сайт ичида очилмаслиги керак.
{
  const ctx = await browser.newContext(); const page = await ctx.newPage();
  await stubs(page);                    // кейин қўшилган route устун туради
  await page.route("https://evil.example/", (r) => r.fulfill({ status: 200, contentType: "text/html", body: `<iframe id=a src="${BASE}/admin.html"></iframe><iframe id=b src="${BASE}/seller.html"></iframe>` }));
  await page.goto("https://evil.example/"); await page.waitForTimeout(1500);
  for (const id of PAGES_MODE ? ["a"] : ["a", "b"]) {        // мета-тег frame-ancestors'ни билмайди: Pages'да фақат админ ҳимояланади (JS)
    const fr = await (await page.$("#" + id)).contentFrame();
    const loaded = fr && (await fr.evaluate(() => location.href.startsWith(location.origin) && getComputedStyle(document.documentElement).display !== "none").catch(() => false));
    console.log(`${loaded ? "✗" : "✓"} бегона сайт ичида ${id === "a" ? "admin" : "seller"}: ${loaded ? "ОЧИЛДИ" : "блокланди"}`);
    if (loaded) bad++;
  }
  await ctx.close();
}
await browser.close(); server.close();
if (bad) { console.log(`\nХАТО: ${bad}`); process.exit(1); }
console.log("\nOK: CSP ҳамма саҳифада бузилишсиз");
