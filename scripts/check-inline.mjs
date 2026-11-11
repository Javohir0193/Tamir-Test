// CSP script-src'да 'unsafe-inline' йўқ: браузер HTML ичидаги <script>...</script> ва onclick="..." каби
// атрибутларни ишга туширмайди. Шунинг учун бу текширув:
//   1) HTML саҳифаларда src'сиз (inline) ишга тушадиган <script> блоки бўлмасин — код алоҳида .js файлда бўлсин;
//   2) HTML ва JS файлларда (innerHTML учун ёзилган шаблонлар ҳам) on...="..." ҳодиса атрибутлари бўлмасин —
//      ўрнига addEventListener ёки el.onclick = ... ишлатинг.
// JSON каби ишга тушмайдиган турлар (type="application/json" ва ҳ.к.) рухсат.
import { readFileSync, readdirSync } from "node:fs";

let bad = 0;
const files = readdirSync(".").filter(f => f.endsWith(".html") || f.endsWith(".js"));
const HANDLER = /(?:^|[\s"'`<])on[a-z]{3,}\s*=\s*\\?["'`]/i;      // onclick="…", onload='…', onerror=\"…\"
for (const f of files) {
  const src = readFileSync(f, "utf8");
  if (f.endsWith(".html")) {
    for (const [, attrs, code] of src.matchAll(/<script(?![^>]*\bsrc=)([^>]*)>([\s\S]*?)<\/script>/gi)) {
      if (/type\s*=\s*["'](?!text\/javascript|module)/i.test(attrs)) continue;   // JSON ва бошқа турлар
      if (!code.trim()) continue;
      const line = src.slice(0, src.indexOf(code)).split("\n").length;
      console.error(`✗ ${f}:${line}: inline <script> — CSP уни блоклайди, кодни алоҳида .js файлга чиқаринг`); bad++;
    }
  }
  src.split("\n").forEach((l, i) => {
    const m = l.match(HANDLER);
    if (m && !/\.on[a-z]+\s*=/i.test(m[0])) { console.error(`✗ ${f}:${i + 1}: inline ҳодиса атрибути (${m[0].trim()}…) — addEventListener ишлатинг`); bad++; }
  });
}
if (bad) { console.error(`\n${bad} та inline скрипт/атрибут. Сабаб: CSP script-src 'unsafe-inline'сиз.`); process.exit(1); }
console.log(`✓ ${files.length} файл: inline <script> ва on...= атрибутлари йўқ (CSP 'unsafe-inline'сиз ишлайди)`);
