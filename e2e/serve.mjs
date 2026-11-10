// Сайтни GitHub Pages каби /Tamir-Test/ йўлида беради (config.js шу йўлга қараб «test» муҳитни танлайди).
// Фақат e2e учун; сарлавҳалар йўқ — CSP саҳифадаги <meta> дан олинади (Pages'даги каби).
import { createServer } from "node:http";
import { readFileSync, existsSync, statSync } from "node:fs";
import { join, extname, dirname, normalize } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
const PREFIX = "/Tamir-Test";
const PORT = Number(process.env.PORT || 4173);
const TYPES = { ".html": "text/html; charset=utf-8", ".js": "text/javascript", ".css": "text/css", ".png": "image/png",
  ".webmanifest": "application/manifest+json", ".json": "application/json", ".svg": "image/svg+xml" };

createServer((req, res) => {
  let p = decodeURIComponent(new URL(req.url, "http://x").pathname);
  if (p === "/" || p === PREFIX) { res.writeHead(302, { location: PREFIX + "/" }); res.end(); return; }
  if (!p.startsWith(PREFIX + "/")) { res.writeHead(404); res.end(); return; }
  p = p.slice(PREFIX.length);
  if (p.endsWith("/")) p += "index.html";
  const f = normalize(join(ROOT, p));
  if (!f.startsWith(ROOT) || f.includes("/node_modules/") || f.includes("/.git/") || !existsSync(f) || !statSync(f).isFile()) { res.writeHead(404); res.end(); return; }
  res.writeHead(200, { "content-type": TYPES[extname(f)] || "application/octet-stream" });
  res.end(readFileSync(f));
}).listen(PORT, "127.0.0.1", () => console.log(`serve: http://127.0.0.1:${PORT}${PREFIX}/`));
