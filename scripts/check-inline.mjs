// HTML саҳифалар ичидаги <script> блокларининг JS синтаксисини текширади (кодни ишга туширмайди).
import { readFileSync, readdirSync } from "node:fs";
import vm from "node:vm";

let bad = 0;
for (const page of readdirSync(".").filter(f => f.endsWith(".html"))) {
  const html = readFileSync(page, "utf8");
  const blocks = [...html.matchAll(/<script(?![^>]*\bsrc=)([^>]*)>([\s\S]*?)<\/script>/gi)];
  blocks.forEach(([, attrs, code], i) => {
    if (/type\s*=\s*["'](?!text\/javascript|module)/i.test(attrs)) return;   // JSON ва бошқа турлар
    try { new vm.Script(code, { filename: `${page}#script${i + 1}` }); }
    catch (e) { console.error(`✗ ${page}, ${i + 1}-скрипт: ${e.message}`); bad++; }
  });
}
if (bad) process.exit(1);
console.log("✓ HTML ичидаги скриптлар синтаксиси тўғри");
