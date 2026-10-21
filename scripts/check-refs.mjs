// Ҳар бир HTML саҳифа уланган маҳаллий файллар (script src, link href, manifest, иконкалар) мавжудлигини текширади.
// Ишга тушириш: node scripts/check-refs.mjs
import { readFileSync, existsSync, readdirSync } from "node:fs";

const pages = readdirSync(".").filter(f => f.endsWith(".html"));
const ATTR = /\b(?:src|href)\s*=\s*["']([^"'#?]+)/g;
let missing = 0;

for (const page of pages) {
  const html = readFileSync(page, "utf8");
  for (const [, ref] of html.matchAll(ATTR)) {
    if (/^(?:[a-z]+:|\/\/|\$\{)/i.test(ref) || ref.includes("${")) continue;   // ташқи ҳавола ёки шаблон
    const path = ref.replace(/^\.?\//, "");
    if (!path || path.endsWith("/")) continue;
    if (!existsSync(path)) { console.error(`✗ ${page}: ${ref} топилмади`); missing++; }
  }
}
for (const m of readdirSync(".").filter(f => f.endsWith(".webmanifest"))) {
  const j = JSON.parse(readFileSync(m, "utf8"));
  for (const i of j.icons || []) if (!/^[a-z]+:/i.test(i.src) && !existsSync(i.src.replace(/^\.?\//, ""))) { console.error(`✗ ${m}: ${i.src} топилмади`); missing++; }
}
if (missing) { console.error(`\n${missing} та файл йўқ`); process.exit(1); }
console.log(`✓ ${pages.length} саҳифа: барча маҳаллий файллар жойида`);
