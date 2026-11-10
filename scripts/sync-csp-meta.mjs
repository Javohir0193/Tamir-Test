// CSP'ни ҳар бир HTML саҳифа ичига <meta http-equiv="Content-Security-Policy"> қилиб ёзади.
// Нима учун: test сайт GitHub Pages'да (javohir0193.github.io/Tamir-Test/) — у _headers'ни ўқимайди, сарлавҳа қўйиб бўлмайди.
// Манба битта: _headers даги «/*» қоидасининг Content-Security-Policy қатори. Мета-тегда ишламайдиган
// frame-ancestors олиб ташланади (уни Netlify сарлавҳаси ва admin.html'даги iframe ҳимояси беради).
// Ишлатиш:  node scripts/sync-csp-meta.mjs          — саҳифаларни янгилайди
//           node scripts/sync-csp-meta.mjs --check  — фақат текширади (CI): _headers билан фарқ бўлса хато
import { readFileSync, writeFileSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
const PAGES = ["index.html", "admin.html", "collector.html", "driver.html", "seller.html", "register.html"];
const CHECK = process.argv.includes("--check");

const hdr = readFileSync(join(ROOT, "_headers"), "utf8");
const block = hdr.slice(hdr.indexOf("\n/*\n"));
const m = block.match(/^\s+Content-Security-Policy:\s*(.+)$/m);
if (!m) { console.error("✗ _headers: /* қоидасида Content-Security-Policy топилмади"); process.exit(1); }
const csp = m[1].split(";").map((s) => s.trim()).filter((s) => s && !/^frame-ancestors\b/.test(s)).join("; ");
const tag = `<meta http-equiv="Content-Security-Policy" content="${csp}">`;
const RE = /<meta http-equiv="Content-Security-Policy" content="[^"]*">/;

let bad = 0;
for (const p of PAGES) {
  const f = join(ROOT, p), s = readFileSync(f, "utf8");
  const cur = s.match(RE);
  if (cur && cur[0] === tag) { console.log(`✓ ${p}`); continue; }
  if (CHECK) { console.log(`✗ ${p}: CSP мета-тег ${cur ? "_headers билан фарқ қилади" : "йўқ"}`); bad++; continue; }
  const out = cur ? s.replace(RE, tag) : s.replace('<meta charset="utf-8">', '<meta charset="utf-8">\n' + tag);
  if (out === s) { console.log(`✗ ${p}: <meta charset="utf-8"> топилмади`); bad++; continue; }
  writeFileSync(f, out); console.log(`↻ ${p}: янгиланди`);
}
if (bad) { console.log(`\nХАТО: ${bad}. Тузатиш: node scripts/sync-csp-meta.mjs`); process.exit(1); }
