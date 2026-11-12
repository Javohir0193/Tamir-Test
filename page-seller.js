// Кабинет дўкона: быстрый ввод цен. Открывается кнопкой «🏷 Нархларим» в боте @tamir_sotuvchi_bot
// или в браузере: «Telegram орқали кириш» (как у ҳайдовчи / йиғувчи).
const API = (window.TAMIR_CONFIG || {}).botApi || "https://agajmytkjpkihvaurqij.supabase.co/functions/v1/tg-bot";
const TG = window.Telegram && window.Telegram.WebApp;
const IN_TG = !!(TG && TG.initData);
let SES = ""; try { SES = localStorage.getItem("sel_ses") || ""; } catch (e) {}
const TC = window.TAMIR_CATALOG || { core:[], items:[], units:{} };
// узбекские названия и примерная цена из каталога
const UZ = new Map();
(TC.core || []).forEach(([id, base, n, s]) => UZ.set(id, { base, n, s }));
(TC.items || []).forEach(x => UZ.set(x[0], { base:x[5], n:x[7] || x[3], s:x[8] || x[4] }));
const UNIT = Object.assign({ "мешок":"қоп", "шт":"дона", "упак.":"қадоқ", "ведро":"челак", "набор":"тўплам", "пачка":"пачка" }, TC.units || {});
const PAGE = 60;
const S = { tab:"today", data:null, cat:"all", st:"all", q:"", pct:0, edits:{}, fromFile:{}, shown:PAGE };
const fmt = n => Math.round(n).toLocaleString("ru-RU").replace(/ /g, " ");
const num = s => +String(s).replace(/[^\d]/g, "") || 0;
const esc = s => String(s ?? "").replace(/[&<>"]/g, c => ({ "&":"&amp;", "<":"&lt;", ">":"&gt;", '"':"&quot;" }[c]));
const $ = id => document.getElementById(id);
function toast(t){ const el = $("toast"); el.textContent = t; el.classList.add("show"); clearTimeout(toast.t); toast.t = setTimeout(() => el.classList.remove("show"), 2200); }

async function call(body){
  const r = await fetch(API, { method:"POST", headers:Object.assign({ "content-type":"application/json" }, IN_TG ? { "x-init-data":TG.initData } : { "x-sel-session":SES }), body:JSON.stringify(body) });
  const j = await r.json().catch(() => ({}));
  if (r.status === 409 && j.error === "reg" && !IN_TG) { location.href = "register.html?role=seller"; throw new Error("reg"); }   // ариза тугалланмаган: ариза шаклига
  if (r.status === 401 && !IN_TG) { dropSes(); loginView("Сессия тугади, қайта киринг."); throw new Error("auth"); }
  if (!r.ok) throw new Error(j.error || "Хато. Қайта уриниб кўринг.");
  return j;
}
const cur = p => S.edits[p.id] ?? S.data.offers[p.id] ?? null;
const nameOf = p => (UZ.get(p.id) || {}).n || p.name;
const specOf = p => (UZ.get(p.id) || {}).s || p.spec;
const unitOf = p => UNIT[p.unit] || p.unit;
// тавсия: бошқа дўконлардаги энг арзон нарх, бўлмаса каталогдаги тахминий нарх
const suggest = p => { const b = p.best || (UZ.get(p.id) || {}).base || 0; return b ? Math.max(100, Math.round(b * (1 + S.pct / 100) / 100) * 100) : 0; };

function filtered(){
  const sNorm = s => String(s || "").toLowerCase().replace(/ё/g, "е").replace(/[ʼ'`ʻ’]/g, ""), sHit = (hay, q) => { const w = sNorm(q).split(/\s+/).filter(Boolean), h = sNorm(hay); return w.every(x => h.includes(x)); };
  const q = S.q.trim();
  return S.data.products.filter(p => (S.cat === "all" || p.cat === S.cat)
    && (!q || sHit(nameOf(p) + " " + p.name + " " + specOf(p), q))
    && (S.st === "all" || (S.st === "none" ? !cur(p) : !!cur(p))));
}
function itemHTML(p){
  const o = cur(p), on = o ? o.in_stock : true, sg = suggest(p);
  const hint = !o ? (p.best ? `Бошқаларда энг арзон: ${fmt(p.best)}` : "Ҳали ҳеч ким сотмаяпти")
    : p.best == null ? "Фақат сизда" : o.price <= p.best ? `✓ Сизники энг арзон` : `Бошқаларда арзонроқ: ${fmt(p.best)}`;
  const cls = !o ? "" : (p.best == null || o.price <= p.best) ? "ok" : "warn";
  return `<div class="item ${o && !on ? "off" : ""}" data-item="${p.id}">
    <div class="nm">${esc(nameOf(p))}<small>${esc(specOf(p))}</small></div>
    <div class="price"><input inputmode="numeric" enterkeyhint="next" data-id="${p.id}" class="${o ? "set" : ""}" value="${o ? fmt(o.price) : ""}" placeholder="нарх" aria-label="Нарх: ${esc(nameOf(p))}"><span>/${esc(unitOf(p))}</span></div>
    <div class="row2"><span class="hint ${cls}">${hint}</span>
      ${!o && sg ? `<button class="sug" data-sug="${p.id}">⤵ ${fmt(sg)}</button>` : ""}
      ${o ? `<span class="sw"><button class="y" data-st="${p.id}:1" aria-pressed="${on}">Бор</button><button class="n" data-st="${p.id}:0" aria-pressed="${!on}">Йўқ</button></span>` : ""}</div>
  </div>`;
}
const placeLine = x => { const t = [x.market, x.row && x.row !== x.shop ? x.row : ""].filter(Boolean).join(" · "); return `<small>📍 ${t ? esc(t) : "бозор кўрсатилмаган"}</small>`; };
const TABS = [["today", "📋 Бугун"], ["prices", "🏷 Нархлар"], ["acct", "💰 Ҳисоб"]];
const tabsHTML = () => `<nav class="tabs">${TABS.map(([id, n]) => `<button data-tab="${id}" aria-pressed="${S.tab === id}">${n}</button>`).join("")}${IN_TG ? "" : `<button class="out" data-out aria-label="Чиқиш" title="Чиқиш">⎋</button>`}</nav>`;
// Тепадаги панел: ҳайдовчи иловаси каби логотип + дўкон/исм + бўлимлар (фақат кўриниш)
const LOGO = `<h1 class="qx" aria-label="Ta'mir Seller"><span class="qx-i qx-star qx-sub" aria-hidden="true"><svg viewBox="20 26 160 152"><defs><linearGradient id="gqs" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#FDBA74"/><stop offset=".35" stop-color="#F97316"/><stop offset="1" stop-color="#C2410C"/></linearGradient></defs><rect x="36" y="56" width="128" height="116" rx="10" fill="url(#gqs)"/><rect x="26" y="28" width="148" height="10" rx="4" fill="#7C2D12"/><path d="M30 36 H58 V60 A14 14 0 0 1 30 60 Z" fill="#EA580C"/><path d="M58 36 H86 V60 A14 14 0 0 1 58 60 Z" fill="#FDBA74"/><path d="M86 36 H114 V60 A14 14 0 0 1 86 60 Z" fill="#EA580C"/><path d="M114 36 H142 V60 A14 14 0 0 1 114 60 Z" fill="#FDBA74"/><path d="M142 36 H170 V60 A14 14 0 0 1 142 60 Z" fill="#EA580C"/><g transform="translate(62 84) scale(.38)"><path d="M135.97,13.16 L150.87,49.13 L186.84,64.03 L171.94,100.00 L186.84,135.97 L150.87,150.87 L135.97,186.84 L100.00,171.94 L64.03,186.84 L49.13,150.87 L13.16,135.97 L28.06,100.00 L13.16,64.03 L49.13,49.13 L64.03,13.16 L100.00,28.06Z" fill="#fff"/><path d="M128.32,31.63 L140.05,59.95 L168.37,71.68 L156.64,100.00 L168.37,128.32 L140.05,140.05 L128.32,168.37 L100.00,156.64 L71.68,168.37 L59.95,140.05 L31.63,128.32 L43.36,100.00 L31.63,71.68 L59.95,59.95 L71.68,31.63 L100.00,43.36Z" fill="none" stroke="#EA580C" stroke-opacity=".35" stroke-width="4"/><g transform="translate(22 14) scale(0.78)" fill="#EA580C"><rect x="50" y="58" width="20" height="38" rx="5"/><rect x="66" y="64" width="62" height="26" rx="3"/><path d="M124 64 Q150 62 160 92 Q161 97 156 96 Q146 82 130 84 V90 H124 Z"/><path d="M92 88 H108 V112 H92 Z"/><rect x="89" y="108" width="22" height="58" rx="9"/></g></g></svg></span><span class="qx-t"><span class="qx-w" aria-hidden="true"><svg class="qx-ht" viewBox="48 56 114 112"><g fill="#F97316"><rect x="50" y="58" width="20" height="38" rx="5"/><rect x="66" y="64" width="62" height="26" rx="3"/><path d="M124 64 Q150 62 160 92 Q161 97 156 96 Q146 82 130 84 V90 H124 Z"/><path d="M92 88 H108 V112 H92 Z"/><rect x="89" y="108" width="22" height="58" rx="9"/></g></svg>a<svg class="qx-ap" viewBox="0 0 40 40"><path d="M27.27,2.45 L30.28,9.72 L37.55,12.73 L34.54,20.00 L37.55,27.27 L30.28,30.28 L27.27,37.55 L20.00,34.54 L12.73,37.55 L9.72,30.28 L2.45,27.27 L5.46,20.00 L2.45,12.73 L9.72,9.72 L12.73,2.45 L20.00,5.46Z" fill="#F97316"/></svg>mir</span><em>Seller</em></span></h1>`;
const hdr = (x, stat) => `<header><div class="hrow"><div class="hl">${LOGO}<small>🏪 ${esc(x.shop)} · ${esc(x.name)}</small>${placeLine(x)}</div>${stat || ""}</div>${tabsHTML()}</header>`;
function render(keepFocus){
  if (S.tab === "today") {
    const d = S.data;
    $("app").innerHTML = `${hdr(d.seller)}<div id="today"><div class="msg">Юкланмоқда…</div></div>`;
    updateBar(); return;
  }
  if (S.tab === "acct") {
    const d = S.data;
    const pb = TamirPush.btn("", "display:block;width:100%;margin:0 0 10px;padding:12px;border-radius:12px;background:#fff;border:1px solid rgba(31,36,48,.13);font:inherit;font-weight:600;color:#1F2430");
    $("app").innerHTML = `${hdr(d.seller)}${pb}<div id="acct"><div class="msg">Юкланмоқда…</div></div>`;
    updateBar(); acctLoad(); return;
  }
  renderPrices(keepFocus);
}
function renderPrices(keepFocus){
  const d = S.data, list = filtered(), priced = d.products.filter(p => cur(p)).length;
  const empty = list.filter(p => !cur(p)).length;
  const cats = [{ id:"all", name:"Ҳаммаси" }, ...d.cats.filter(c => d.products.some(p => p.cat === c.id))];
  $("app").innerHTML = `
    ${hdr(d.seller, `<div class="stat"><b>${priced} / ${d.products.length}</b>нархланган</div>`)}
    <button class="chip" data-imp style="margin:0 0 8px;background:var(--ink);color:#fff">📄 Excel / CSV файлдан нарх юклаш</button>
    <button class="chip" data-newp style="margin:0 0 8px;background:var(--card)">➕ Каталогда йўқ товарни таклиф қилиш</button>
    <button class="chip" data-myprops style="margin:0 0 8px;background:var(--card)">📋 Менинг таклифларим</button>
    <label class="search"><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#8A9099" stroke-width="2"><circle cx="11" cy="11" r="7"/><path d="m20 20-3.5-3.5"/></svg>
      <input id="q" type="search" placeholder="Товар қидириш…" value="${esc(S.q)}"></label>
    <div class="chips">${cats.map(c => `<button class="chip" data-cat="${c.id}" aria-pressed="${S.cat === c.id}">${esc(c.name)}</button>`).join("")}</div>
    <div class="chips">${[["all", "Барча товарлар"], ["none", "Нархсиз"], ["set", "Нархланган"]].map(([id, n]) => `<button class="chip" data-stf="${id}" aria-pressed="${S.st === id}">${n}</button>`).join("")}</div>
    ${empty ? `<div class="fast"><b>⚡ Тез тўлдириш</b>
      <p>Пастдаги ${empty} та нархсиз товарга тавсия нарх бир босишда қўйилади (бозордаги энг арзон ёки тахминий нарх). Кейин фақат керакларини тузатасиз.</p>
      <div class="row">${[-10, -5, 0, 5, 10].map(v => `<button class="pct" data-pct="${v}" aria-pressed="${S.pct === v}">${v > 0 ? "+" : ""}${v}%</button>`).join("")}
      <button class="go" data-fill>Қўйиш (${empty})</button></div></div>` : ""}
    <p class="hint" style="margin:6px 2px 8px">Нарх ёзиб, «Кейинги» ни босинг — кейинги товарга ўтади. Сотмаган товарни бўш қолдиринг.</p>
    <div class="list">${list.slice(0, S.shown).map(itemHTML).join("") || `<div class="msg">Ҳеч нарса топилмади.</div>`}</div>
    ${list.length > S.shown ? `<button class="more" data-more>Яна кўрсатиш (${list.length - S.shown})</button>` : ""}`;
  updateBar();
  if (keepFocus) { const q = $("q"); q.focus(); q.setSelectionRange(q.value.length, q.value.length); }
}
// обновляем строку на месте, не пересоздавая поле ввода (иначе на телефоне закрывается клавиатура)
function refresh(id){
  const p = S.data.products.find(x => x.id === id), el = document.querySelector(`[data-item="${id}"]`);
  if (p && el) {
    const t = document.createElement("div"); t.innerHTML = itemHTML(p); const n = t.firstElementChild;
    el.className = n.className;
    el.querySelector(".row2").replaceWith(n.querySelector(".row2"));
    const inp = el.querySelector("input"), ni = n.querySelector("input");
    inp.className = ni.className; if (document.activeElement !== inp) inp.value = ni.value;
  }
  updateBar();
}
function updateBar(){
  const n = Object.keys(S.edits).length;
  $("bar").hidden = S.tab !== "prices"; $("save").disabled = !n;
  $("save").textContent = n ? `Сақлаш (${n} та ўзгариш)` : "Ўзгаришлар йўқ";
}
function setEdit(id, patch){
  const base = S.data.offers[id] ?? null, now = { ...(S.edits[id] ?? base ?? { price:0, in_stock:true }), ...patch };
  if (base && now.price === base.price && now.in_stock === base.in_stock) delete S.edits[id];
  else if (!base && !now.price) delete S.edits[id];
  else S.edits[id] = now;
}

document.addEventListener("click", e => {
  const b = e.target.closest("button"); if (!b) return;
  if (b.dataset.cat) { S.cat = b.dataset.cat; S.shown = PAGE; render(); }
  else if (b.dataset.stf) { S.st = b.dataset.stf; S.shown = PAGE; render(); }
  else if ("imp" in b.dataset) openImp();
  else if ("newp" in b.dataset) openNewP();
  else if ("myprops" in b.dataset) openMyProps();
  else if ("out" in b.dataset) { dropSes(); loginView(); }
  else if (b.dataset.pct) { S.pct = +b.dataset.pct; render(); }
  else if ("more" in b.dataset) { S.shown += PAGE; render(); }
  else if (b.dataset.sug) { const p = S.data.products.find(x => x.id === +b.dataset.sug); setEdit(p.id, { price:suggest(p), in_stock:true }); refresh(p.id); }
  else if (b.dataset.st) { const [id, v] = b.dataset.st.split(":"); setEdit(+id, { in_stock: v === "1" }); refresh(+id); }
  else if ("fill" in b.dataset) {
    let n = 0; for (const p of filtered()) if (!cur(p)) { const v = suggest(p); if (v) { setEdit(p.id, { price:v, in_stock:true }); n++; } }
    render(); toast(`⚡ ${n} та товарга нарх қўйилди. Текширинг ва «Сақлаш» ни босинг.`);
  }
});
document.addEventListener("input", e => { if (e.target.id === "q") { S.q = e.target.value; S.shown = PAGE; render(true); } });
document.addEventListener("change", e => { const id = e.target.dataset.id; if (!id) return; setEdit(+id, { price:num(e.target.value) }); refresh(+id); });
document.addEventListener("keydown", e => {   // Enter / «Кейинги» → следующее поле цены
  const id = e.target.dataset && e.target.dataset.id; if (!id || e.key !== "Enter") return;
  e.preventDefault();
  const ins = [...document.querySelectorAll("input[data-id]")], i = ins.indexOf(e.target), next = ins[i + 1];
  setEdit(+id, { price:num(e.target.value) }); refresh(+id);
  if (next) { next.focus(); next.scrollIntoView({ block:"center", behavior:"smooth" }); } else e.target.blur();
});
$("save").addEventListener("click", async () => {
  const a = document.activeElement; if (a && a.dataset && a.dataset.id) { setEdit(+a.dataset.id, { price:num(a.value) }); a.blur(); }
  const offers = Object.entries(S.edits).map(([id, o]) => Object.assign({ product_id:+id, price:o.price, in_stock:o.in_stock }, S.fromFile[id] ? { src:"file" } : {}));
  if (!offers.length) return;
  $("save").disabled = true; $("save").textContent = "Сақланмоқда…";
  try {
    const res = await call({ action:"save", offers });
    for (const o of offers) { if (o.price) S.data.offers[o.product_id] = { price:o.price, in_stock:o.in_stock }; else delete S.data.offers[o.product_id]; }
    S.edits = {}; S.fromFile = {}; render();
    toast(res.skipped ? `✓ ${offers.length - res.skipped} та сақланди, ${res.skipped} таси ўтказилди (товар каталогда йўқ ёки нарх нотўғри)` : `✓ ${offers.length} та нарх сақланди`);
    if (res.skipped) boot();   // сервер ёзмаганларини экрандан ҳам олиб ташлаш
    if (TG && TG.HapticFeedback) TG.HapticFeedback.notificationOccurred("success");
  } catch (err) { toast(err.message); updateBar(); }
});

// ===== Файлдан (CSV / Excel'дан нусха) нарх юклаш: номи бўйича каталогдаги товарга мослаштирилади, сўнг одатдаги «Сақлаш» орқали ёзилади =====
// Кирилл ва лотин ёзувини битта «калит»га келтириш (supabase search_key_norm билан бир хил қоида)
const KEYMAP = { "щ":"sh","ш":"sh","ч":"ch","ё":"yo","ю":"yu","я":"ya","ц":"s","ж":"j","ў":"o","ғ":"g","қ":"q","ҳ":"h" };
const KEYTR = {}; "абвгдезийклмнопрстуфхыэ".split("").forEach((c, i) => KEYTR[c] = "abvgdeziyklmnoprstufxie"[i]);
function skey(t){
  let x = String(t || "").toLowerCase().replace(/[щшчёюяцжўғқҳ]/g, c => KEYMAP[c]).replace(/[а-яё]/g, c => KEYTR[c] ?? "");
  x = x.replace(/[^a-z0-9]+/g, " ").trim();
  return x.replace(/ch/g, "#").replace(/c/g, "s").replace(/#/g, "ch").replace(/ts/g, "s").replace(/kh/g, "x").replace(/ye/g, "e").replace(/yo/g, "e");
}
const toks = k => new Set(k.split(" ").filter(Boolean));
function parseTable(text){
  const t = String(text || "").replace(/^﻿/, "").replace(/\r/g, "");
  const first = t.split("\n").find(l => l.trim()) || "";
  const dl = [["\t", first.split("\t").length], [";", first.split(";").length], [",", first.split(",").length]].sort((a, b) => b[1] - a[1])[0][0];
  const rows = []; let row = [], cell = "", q = false;
  for (let i = 0; i < t.length; i++){
    const c = t[i];
    if (q){ if (c === '"'){ if (t[i + 1] === '"'){ cell += '"'; i++; } else q = false; } else cell += c; }
    else if (c === '"') q = true;
    else if (c === dl){ row.push(cell); cell = ""; }
    else if (c === "\n"){ row.push(cell); rows.push(row); row = []; cell = ""; }
    else cell += c;
  }
  row.push(cell); rows.push(row);
  return rows.filter(r => r.some(x => x.trim()));
}
// Қатордан: нарх = охирги рақамли катак (мас. «45 000», «45000,00 сўм»), ном = энг узун матнли катак
function pickRow(cells){
  let price = 0, name = "";
  for (const c of cells){
    const v = c.trim(); if (!v) continue;
    const n = v.replace(/\s| /g, "").replace(/(сум|сўм|so'm|som|uzs)$/i, "");
    if (/^\d+([.,]\d+)?$/.test(n)) price = Math.round(parseFloat(n.replace(",", ".")));
    else if (v.length > name.length) name = v;
  }
  return { name, price };
}
function matchProduct(name){
  const qk = skey(name), qt = toks(qk); if (!qt.size) return null;
  let best = null;
  for (const p of S.data.products){
    for (const nm of [p.name + " " + p.spec, nameOf(p) + " " + specOf(p), p.name, nameOf(p)]){
      const pk = skey(nm); if (!pk) continue;
      if (pk === qk) return { p, score:1 };
      const pt = toks(pk); let inter = 0; qt.forEach(w => { if (pt.has(w)) inter++; });
      const sc = inter / (qt.size + pt.size - inter);
      if (!best || sc > best.score) best = { p, score:sc };
    }
  }
  return best;
}
// Сарлавҳали жадвал (намуна файл каби): ID / Номи / Нарх / Бор устунлари номидан топилади. Сарлавҳасиз — эски усул (ном + нарх).
const HDR = { id:/^(id|№|код|kod|артикул)$/i, name:/^(ном|номи|nomi|товар|tovar|наимен|назв|name|mahsulot|маҳсулот)/i, spec:/^(тавсиф|tavsif|описан|spec)/i,
  price:/(нарх|narx|цена|price|сўм|сум)/i, stock:/^(бор|bor|налич|stock|mavjud|мавжуд)/i, unit:/^(ўлчов|o['ʻ’`]?lchov|ед|единиц|unit)/i };
function findHdr(cells){
  const h = {}; cells.forEach((c, i) => { const v = String(c).trim(); for (const k in HDR) if (h[k] === undefined && HDR[k].test(v)) { h[k] = i; break; } });
  return h.price !== undefined && (h.name !== undefined || h.id !== undefined) ? h : null;
}
const priceOf = v => { const n = String(v ?? "").replace(/\s| /g, "").replace(/(сум|сўм|so'm|som|uzs)$/i, ""); return /^\d+([.,]\d+)?$/.test(n) ? Math.round(parseFloat(n.replace(",", "."))) : 0; };
const stockOf = v => !/^(йўқ|йук|йо[кқ]|yo['ʻ’`]?q|нет|no|0|-|false|х)$/i.test(String(v ?? "").trim());
function rowsToImp(rows){
  const out = []; let hdr = null, seen = false, first = true;
  const byId = new Map(S.data.products.map(p => [p.id, p]));
  for (const cells of rows.slice(0, 2000)){
    if (!seen){ seen = true; hdr = findHdr(cells); if (hdr) continue; }
    let id = 0, name = "", price = 0, stock = true, nm = "", sp = "", unit = "";
    if (hdr){
      id = hdr.id !== undefined ? +String(cells[hdr.id] ?? "").replace(/\D/g, "") || 0 : 0;
      nm = String(cells[hdr.name] ?? "").trim(); sp = hdr.spec !== undefined ? String(cells[hdr.spec] ?? "").trim() : "";
      unit = hdr.unit !== undefined ? String(cells[hdr.unit] ?? "").trim() : "";
      name = nm + (sp ? " " + sp : "");
      price = priceOf(cells[hdr.price]); stock = hdr.stock !== undefined ? stockOf(cells[hdr.stock]) : true;
    } else ({ name, price } = pickRow(cells));
    const wasFirst = first; first = false;
    if (!price && !name.trim() && !id) continue;
    if (!price && !hdr && wasFirst) continue;   // сарлавҳасиз жадвалнинг биринчи матнли қатори — сарлавҳа
    if (!price){ if (name || id) out.push({ name:name || "#" + id, price:0, m:null, on:false }); continue; }   // нархи бўш қатор: ўтказилади
    const m = id && byId.has(id) ? { p:byId.get(id), score:1 } : name ? matchProduct(name) : null;
    const st = !m ? "no" : m.score >= 0.8 ? "ok" : m.score >= 0.5 ? "warn" : "no";
    out.push({ name:name || "#" + id, nm:nm || name, sp, unit, price, stock, m: st === "no" ? null : m, st, on: st === "ok" });
  }
  return out;
}
const buildImp = text => rowsToImp(parseTable(text));
// Сервер текшируви: бозордаги нарх (бошқа дўконлар медианаси) билан солиштириш. Бот эски бўлса — жимгина ўтказиб юборилади.
async function checkImp(){
  const I = S.imp, rows = I.rows.filter(r => r.m && r.price);
  if (!rows.length) return;
  try {
    const res = await call({ action:"imp_check", rows:rows.map(r => ({ product_id:r.m.p.id, price:r.price })) });
    (res.rows || []).forEach((c, i) => { const r = rows[i]; if (!r || !c) return; r.chk = c;
      if (c.st === "err_price" || c.st === "err_product") { r.on = false; r.st = "no"; }
      else if (c.st === "warn") { r.on = false; r.st = "warn"; } });
  } catch (e) { /* текширувсиз ҳам ишлайди */ }
}
function tplCSV(){   // намуна: менинг товарларим, ҳозирги нархим билан — Excel'да тўлдириб, қайта юкланади
  const q = v => { const t = String(v ?? ""); return /[;"\n]/.test(t) ? '"' + t.replace(/"/g, '""') + '"' : t; };
  const lines = [["ID", "Номи", "Тавсиф", "Ўлчов", "Нарх", "Бор"].join(";")];
  [...S.data.products].sort((a, b) => String(a.cat).localeCompare(b.cat) || nameOf(a).localeCompare(nameOf(b))).forEach(p => {
    const o = cur(p); lines.push([p.id, nameOf(p), specOf(p), unitOf(p), o ? o.price : "", o ? (o.in_stock ? "бор" : "йўқ") : ""].map(q).join(";"));
  });
  const a = document.createElement("a");
  a.href = URL.createObjectURL(new Blob(["﻿" + lines.join("\r\n")], { type:"text/csv;charset=utf-8" }));
  a.download = "narxlarim-" + new Date().toISOString().slice(0, 10) + ".csv"; document.body.appendChild(a); a.click(); a.remove();
}
function impHTML(){
  const I = S.imp, rows = I.rows || [], on = rows.filter(r => r.on).length;
  const ok = rows.filter(r => r.st === "ok").length, wr = rows.filter(r => r.st === "warn").length, no = rows.length - ok - wr;
  return `<div class="imp" data-impbg><div>
    <h2>📄 Файлдан нарх юклаш</h2>
    <p class="hint" style="margin:0 0 8px">Энг осони: намуна файлни юклаб олинг (унда ҳамма товарларингиз бор), Excel'да «Нарх» ва «Бор» устунларини тўлдириб, шу ерда танланг. Ўз жадвалингиз ҳам бўлади: товар номи ва нарх устунлари керак (.xlsx ёки .csv), ёки жадвалдан нусха олиб пастга қўйинг.</p>
    <div class="acts" style="margin:0 0 8px"><button data-imptpl>⬇ Намуна файл (менинг товарларим)</button>
    <label class="filebtn" style="display:inline-block">📁 Файл танлаш<input type="file" id="impfile" accept=".xlsx,.csv,.tsv,.txt,text/csv,text/plain,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" hidden></label></div>
    <textarea id="imptxt" placeholder="Цемент М400 50 кг;62000&#10;Кирпич қизил;1200">${esc(I.text || "")}</textarea>
    <div class="acts"><button data-impgo>Текшириш</button><button data-impclose>Ёпиш</button></div>
    ${rows.length ? `<p class="hint" style="margin:4px 0 8px">${rows.length} қатор: <b style="color:var(--ok)">${ok} аниқ</b> · <b style="color:var(--warn)">${wr} шубҳали</b> · ${no} топилмади. Шубҳалилар (номи ноаниқ ёки нархи бозордан жуда фарқ қилади) белгиланмаган: текшириб, тўғри бўлса ўзингиз белгиланг.</p>
      <div style="border-radius:12px;overflow:hidden">${rows.map((r, i) => `<label class="irow ${r.m ? "" : "no"}">
        <input type="checkbox" data-impck="${i}" ${r.on ? "checked" : ""} ${r.m ? "" : "disabled"}>
        <span>${esc(r.name)}<small>${r.m ? "→ " + esc(nameOf(r.m.p)) + " · " + esc(specOf(r.m.p)) : r.note ? esc(r.note) : r.price ? "каталогдан топилмади: янги товар сифатида таклиф қилишингиз мумкин" : "нарх ёзилмаган (ўтказиб юборилади)"}${r.chk && r.chk.st === "warn" ? `<br><span style="color:var(--warn)">⚠ Бозорда ~${fmt(r.chk.med)} сўм, сизники ${r.chk.dev > 0 ? "+" : ""}${r.chk.dev}%</span>` : ""}${r.m && r.stock === false ? " · йўқ" : ""}</small></span>
        <b class="${r.st || "no"}">${r.price ? fmt(r.price) : ""}</b></label>`).join("")}</div>
      <div class="acts"><button class="main" data-impapply ${on && !I.checking ? "" : "disabled"}>${I.checking ? "Бозор нархи текширилмоқда…" : `Нархларга қўйиш (${on})`}</button>
        ${rows.some(r => !r.m && r.price && !r.sent) ? `<button data-impprop>➕ Топилмаганларни таклиф қилиш (${rows.filter(r => !r.m && r.price && !r.sent).length})</button>` : ""}</div>
      <p class="hint">Бу фақат рўйхатга қўяди; ёзиш учун кейин пастдаги «Сақлаш» тугмасини босасиз.</p>` : ""}
  </div></div>`;
}
function openImp(){ S.imp = { rows:[], text:"" }; showImp(); }
// Сервер текшируви (бозор нархи) тугагунча «Нархларга қўйиш» ёпиқ: акс ҳолда шубҳали нарх белгиланган ҳолда кетиб қолади
async function impChecked(){ const I = S.imp; I.checking = (I.checking || 0) + 1; showImp(); try { await checkImp(); } finally { I.checking--; } if (S.imp === I) showImp(); }
function showImp(){ let el = $("impwrap"); if (!el){ el = document.createElement("div"); el.id = "impwrap"; document.body.appendChild(el); } el.innerHTML = impHTML(); }
function closeImp(){ const el = $("impwrap"); if (el) el.remove(); S.imp = null; }
document.addEventListener("click", e => {
  if (!S.imp) return; const t = e.target;
  if (t.hasAttribute("data-impclose") || t.hasAttribute("data-impbg")) closeImp();
  else if (t.hasAttribute("data-imptpl")) tplCSV();
  else if (t.hasAttribute("data-impprop")) openPropMany();
  else if (t.hasAttribute("data-impgo")){ const ta = $("imptxt"); S.imp.text = ta.value; S.imp.rows = buildImp(ta.value); if (!S.imp.rows.length) toast("Қатор топилмади: ном ва нарх устунлари керак"); impChecked(); }
  else if (t.hasAttribute("data-impapply")){
    if (S.imp.checking) return;
    // шубҳали нарх (бозордан кескин фарқ) фақат дўкон ўзи белгилаган бўлса ўтади
    let n = 0; for (const r of S.imp.rows) if (r.on && r.m && !(r.chk && r.chk.st === "warn" && !r.byHand)){ setEdit(r.m.p.id, { price:r.price, in_stock:r.stock !== false }); if (S.edits[r.m.p.id]) S.fromFile[r.m.p.id] = true; n++; }
    closeImp(); render(); toast(`✓ ${n} та нарх рўйхатга қўйилди. Текшириб «Сақлаш» ни босинг.`);
  }
});
document.addEventListener("change", e => {
  if (!S.imp) return; const t = e.target;
  if (t.dataset.impck !== undefined){ const r = S.imp.rows[+t.dataset.impck]; r.on = t.checked; r.byHand = t.checked; S.imp.text = $("imptxt").value; showImp(); }
  else if (t.id === "impfile" && t.files[0]){
    const f = t.files[0];
    if (f.size > 5 * 1024 * 1024) { toast("Файл жуда катта (5 МБ гача)"); return; }
    f.arrayBuffer().then(async buf => {
      if (window.TamirXlsx && TamirXlsx.isXlsx(buf)) {   // .xlsx: биринчи варақ
        const rows = await TamirXlsx.read(buf);
        S.imp.text = rows.map(r => r.map(c => String(c).replace(/[\t\n]/g, " ")).join("\t")).join("\n"); S.imp.rows = rowsToImp(rows);
      } else {
        let txt = new TextDecoder("utf-8").decode(buf);
        if (txt.includes("�")) txt = new TextDecoder("windows-1251").decode(buf);   // Excel'нинг эски CSV кодировкаси
        S.imp.text = txt; S.imp.rows = buildImp(txt);
      }
      if (!S.imp.rows.length) toast("Қатор топилмади: ном ва нарх устунлари керак");
      impChecked();
    }).catch(e => toast(e && e.message === "no_inflate" ? "Бу қурилмада .xlsx ўқилмайди: Excel'да «CSV» қилиб сақланг" : e && e.message === "too_big" ? "Файл жуда катта" : "Файлни ўқиб бўлмади (.xlsx ёки .csv керак)"));
  }
});

// ===== Файлда топилмаган қаторлар → бирданига янги товар таклифи (админ тасдиқлагач каталогга чиқади, нарх шу заҳоти сақланади) =====
const UNITS = ["дона", "қоп", "кг", "тонна", "м", "м²", "м³", "литр", "рулон", "қадоқ"];
function openPropMany(){
  const list = S.imp.rows.map((r, i) => ({ r, i })).filter(x => !x.r.m && x.r.price && !x.r.sent).slice(0, 50);
  const el = document.createElement("div"); el.id = "pmwrap";
  el.innerHTML = `<div class="imp" data-pmbg><div>
    <h2>➕ Янги товарлар таклифи (${list.length})</h2>
    <p class="hint" style="margin:0 0 8px">Булар каталогда топилмади. Белгиланганлари админга боради: тасдиқлагач мижозларга кўринади, нархингиз шу заҳоти сақланади. Аввал қидирувдан текширинг: товар бошқача номда бўлиши мумкин.</p>
    <label class="field">Тоифа (ҳаммаси учун)<select id="pm_cat">${S.data.cats.map(c => `<option value="${esc(c.id)}">${esc(c.name)}</option>`).join("")}</select></label>
    <div style="border-radius:12px;overflow:hidden">${list.map(({ r, i }) => `<label class="irow">
      <input type="checkbox" data-pmck="${i}" checked>
      <span>${esc(r.nm || r.name)}<small>${esc(r.sp || "")}</small></span>
      <span style="display:flex;gap:6px;align-items:center"><input data-pmunit="${i}" value="${esc(r.unit || "дона")}" list="pm_units" maxlength="15" style="width:72px;border:1px solid var(--line);border-radius:8px;padding:4px 6px"><b>${fmt(r.price)}</b></span></label>`).join("")}</div>
    <datalist id="pm_units">${UNITS.map(u => `<option value="${u}">`).join("")}</datalist>
    <div class="acts"><button class="main" data-pmsend>Админга юбориш</button><button data-pmclose>Ёпиш</button></div>
  </div></div>`;
  document.body.appendChild(el);
}
document.addEventListener("click", async e => {
  const t = e.target, w = $("pmwrap"); if (!w) return;
  if (t.hasAttribute("data-pmclose") || t.hasAttribute("data-pmbg")) w.remove();
  else if (t.hasAttribute("data-pmsend")){
    const idx = [...w.querySelectorAll("[data-pmck]")].filter(x => x.checked).map(x => +x.dataset.pmck);
    if (!idx.length) { toast("Ҳеч нарса белгиланмаган"); return; }
    const rows = idx.map(i => { const r = S.imp.rows[i]; return { name:r.nm || r.name, spec:r.sp || "", unit:(w.querySelector(`[data-pmunit="${i}"]`).value || "дона").trim(), price:r.price }; });
    const nu = rows.find(r => !/\p{L}/u.test(r.unit)); if (nu) { toast(`«${nu.name}»: ўлчов сўз билан (дона, қоп, кг, м²…)`); return; }
    t.disabled = true;
    try {
      const res = await call({ action:"propose_many", cat:$("pm_cat").value, rows });
      let ok = 0; const bad = [];
      (res.rows || []).forEach((x, k) => { const r = S.imp.rows[idx[k]]; if (x.ok) { ok++; r.sent = true; r.note = "админга юборилди"; } else { r.note = x.error; bad.push(r.nm + ": " + x.error); } });
      w.remove(); if (S.imp) showImp();
      toast(bad.length ? `✓ ${ok} та юборилди, ${bad.length} таси йўқ: ${bad[0]}` : `✓ ${ok} та товар админга юборилди`);
    } catch (err) { t.disabled = false; toast(err.message); }
  }
});
// ===== Менинг таклифларим: кутилмоқда / каталогга қўшилди / рад этилди (сабаби билан) =====
const PROPST = { wait:["⏳ Кутилмоқда", "var(--warn)"], ok:["✅ Каталогда", "var(--ok)"], no:["❌ Рад этилди", "#C0392B"] };
async function openMyProps(){
  const el = document.createElement("div"); el.id = "mpwrap";
  el.innerHTML = `<div class="imp" data-mpbg><div><h2>📋 Менинг таклифларим</h2><div id="mplist" class="hint">Юкланмоқда…</div><div class="acts"><button data-mpclose>Ёпиш</button></div></div></div>`;
  document.body.appendChild(el);
  try {
    const { list = [] } = await call({ action:"s_proposals" });
    $("mplist").innerHTML = list.length ? `<div style="border-radius:12px;overflow:hidden">${list.map(x => `<div class="irow" style="grid-template-columns:1fr auto">
      <span>${esc(x.name)}<small>${esc([x.spec, x.unit].filter(Boolean).join(" · "))}${x.st === "no" && x.reason ? `<br>Сабаб: ${esc(x.reason)}` : ""}</small></span>
      <b style="color:${PROPST[x.st][1]}">${PROPST[x.st][0]}</b></div>`).join("")}</div>` : "Ҳали таклиф юбормагансиз.";
  } catch (err) { $("mplist").textContent = err.message; }
}
document.addEventListener("click", e => { const w = $("mpwrap"); if (w && (e.target.hasAttribute("data-mpclose") || e.target.hasAttribute("data-mpbg"))) w.remove(); });

// ===== Каталогда йўқ янги товарни таклиф қилиш: админга бориб, тасдиқлангач каталогга чиқади (нархингиз шу заҳоти сақланади) =====
function openNewP(){
  const el = document.createElement("div"); el.id = "newpwrap";
  el.innerHTML = `<div class="imp" data-npbg><div>
    <h2>➕ Янги товар таклифи</h2>
    <p class="hint" style="margin:0 0 8px">Аввал қидирувдан текширинг: товар каталогда бўлса, шунчаки нарх қўйинг. Янги товарни админ тасдиқлагач мижозларга кўринади.</p>
    <label class="field">Номи<input id="npn_name" maxlength="80" placeholder="Мас.: Қум (ювилган)"></label>
    <label class="field">Тавсиф (ихтиёрий)<input id="npn_spec" maxlength="80" placeholder="Мас.: 1 м³, навли"></label>
    <label class="field">Тоифа<select id="npn_cat">${S.data.cats.map(c => `<option value="${esc(c.id)}">${esc(c.name)}</option>`).join("")}</select></label>
    <label class="field">Ўлчов<input id="npn_unit" maxlength="15" list="npn_units" placeholder="қоп, дона, м², кг…"><datalist id="npn_units"><option value="дона"><option value="қоп"><option value="кг"><option value="тонна"><option value="м"><option value="м²"><option value="м³"><option value="литр"><option value="рулон"><option value="қадоқ"></datalist></label>
    <label class="field">Сизнинг нархингиз, сўм (ихтиёрий)<input id="npn_price" inputmode="numeric" placeholder="45 000"></label>
    <div class="acts"><button class="main" data-npsend>Админга юбориш</button><button data-npclose>Ёпиш</button></div>
  </div></div>`;
  document.body.appendChild(el);
}
document.addEventListener("click", async e => {
  const t = e.target, w = $("newpwrap"); if (!w) return;
  if (t.hasAttribute("data-npclose") || t.hasAttribute("data-npbg")) w.remove();
  else if (t.hasAttribute("data-npsend")){
    const body = { action:"propose", name:$("npn_name").value.trim(), spec:$("npn_spec").value.trim(), cat:$("npn_cat").value, unit:$("npn_unit").value.trim(), price:num($("npn_price").value) };
    if (!body.name || !body.unit) { toast("Номи ва ўлчовини ёзинг"); return; }
    if (!/\p{L}/u.test(body.unit)) { toast("Ўлчов сўз билан: дона, қоп, кг, м²…"); return; }
    t.disabled = true;
    try { await call(body); w.remove(); toast("✓ Админга юборилди. Тасдиқлангач каталогда чиқади."); }
    catch (err) { t.disabled = false; toast(err.message); }
  }
});

// ===== Бугун: дўконнинг буюртмалари — ботдаги хабар билан бир хил тугмалар (Бор/Йўқ → Тасдиқлаш → Тайёр → Йиғувчига бердим / Машинага юкладим) =====
S.chk = S.chk || {};
const ST = { offered:"Тасдиқ кутилмоқда", confirmed:"Тасдиқланган", ready:"Тайёр" };
const left = t => { const m = Math.max(0, Math.round((t - Date.now()) / 60000)); return m ? `⏳ ${m} дақиқа қолди` : "⏳ вақт тугаяпти"; };
function ordCard(o){
  const sc = S.sc, done = o.lines.filter(l => l.loaded).length, all = o.lines.filter(l => l.says_yes !== false).length;
  const loadedAll = done === all && all > 0;
  const give = sc ? "🤝 Йиғувчига бердим" : "🚚 Машинага юкладим";
  const state = !o.confirmed ? "Бор товарни ✅, йўғини ❌ қилинг, кейин «Тасдиқлаш»" : !o.ready ? "Йиғинг, кейин «Тайёр»"
    : loadedAll ? (sc ? "Йиғувчига берилди ✅" : "Ҳаммаси машинага юкланди ✅") : sc ? "Тайёр. Йиғувчи келганда товарни беринг" : "Тайёр. Ҳайдовчи келганда машинага юкланг";
  const sum = o.lines.reduce((a, l) => a + (l.says_yes === false || l.status === "pending" ? 0 : (l.price || 0) * l.qty), 0);
  const yes = o.lines.filter(l => l.says_yes !== false).length;
  const rows = !o.confirmed
    ? o.lines.map((l, i) => `<button class="tg ${l.says_yes === false ? "no" : ""}" data-otg="${o.msg_id}:${l.line_no}" aria-pressed="${l.says_yes !== false}"><span>${i + 1}.</span><span>${esc(l.name)}<small>${fmt(l.qty)} ${esc(unitOf({ unit:l.unit }))}${l.price ? " · " + fmt(l.price) + " сўм" : ""}</small></span><span class="yn">${l.says_yes === false ? "❌ Йўқ" : "✅ Бор"}</span></button>`).join("")
    : !o.ready ? o.lines.filter(l => l.says_yes !== false && l.status !== "pending").map((l, i) => { const on = !!S.chk[o.msg_id + ":" + l.line_no]; return `<button class="tg ${on ? "" : "no"}" data-chk="${o.msg_id}:${l.line_no}" aria-pressed="${on}"><span>${on ? "☑️" : "⬜"}</span><span>${esc(l.name)}<small>${fmt(l.qty)} ${esc(unitOf({ unit:l.unit }))}${l.price ? " · " + fmt(l.price) + " сўм" : ""}</small></span><span class="yn">${on ? "Йиғилди" : "Йиғинг"}</span></button>`; }).join("")
    : o.lines.map(l => `<div class="irow" style="grid-template-columns:1fr auto"><span>${l.says_yes === false || l.status === "pending" ? "❌" : l.loaded ? "✅" : "⬜"} ${esc(l.name)}<small>${fmt(l.qty)} ${esc(unitOf({ unit:l.unit }))}${l.price ? " · " + fmt(l.price) + " сўм" : ""}</small></span><span class="hint">${esc(ST[l.status] || "")}${l.loaded ? (sc ? " · берилди" : " · юкланди") : ""}</span></div>`).join("");
  const who = sc && o.picker ? `🧺 Йиғувчи: ${esc(o.picker.name)}${o.picker.phone ? ` · <a href="tel:${esc(o.picker.phone)}">${esc(o.picker.phone)}</a>` : ""}`
    : o.driver ? `🚚 Ҳайдовчи: ${esc(o.driver.name)}${o.driver.car ? " · " + esc(o.driver.car) : ""}${o.driver.phone ? " · " + esc(o.driver.phone) : ""}` : "";
  const acts = !o.confirmed ? `<button class="main" data-ocf="${o.msg_id}">👍 Тасдиқлаш (${yes}/${o.lines.length} бор)</button>`
    : !o.ready ? (yes ? (() => { const need = o.lines.filter(l => l.says_yes !== false && l.status !== "pending"), got = need.filter(l => S.chk[o.msg_id + ":" + l.line_no]).length;
        return got === need.length ? `<button class="main" data-ordready="${o.msg_id}">📦 Тайёр</button>` : `<button class="main" disabled style="opacity:.5">☑️ Ҳаммасини белгиланг (${got}/${need.length})</button>`; })() : "")
    : !loadedAll ? `<button class="main" data-ordload="${o.msg_id}">${give}</button>` : "";
  return `<div class="list" style="margin-bottom:10px"><div class="irow" style="grid-template-columns:1fr auto"><span><b>№${o.no}</b> · ${esc(o.slot || "")}<small>${esc(state)}</small></span><b class="${o.ready ? "ok" : "warn"}">${!o.confirmed && o.until ? left(o.until) : o.ready ? "тайёр" : "кутилмоқда"}</b></div>
    ${rows}
    ${sum ? `<div class="irow" style="grid-template-columns:1fr auto"><span>Жами</span><b>${fmt(sum)} сўм</b></div>` : ""}
    ${who ? `<div class="irow" style="grid-template-columns:1fr"><span>${who}</span></div>` : ""}
    ${acts ? `<div class="oacts">${acts}</div>` : ""}</div>`;
}
async function todayLoad(){
  const w = $("today"); if (!w || S.tab !== "today") return;
  try {
    const r = await call({ action:"s_orders" }), list = r.orders || [];
    S.sc = !!r.sc;
    const isLoaded = o => { const a = o.lines.filter(l => l.says_yes !== false).length; return a > 0 && o.lines.filter(l => l.loaded).length === a; };
    const g = [
      ["🆕 Тасдиқ кутилмоқда", list.filter(o => !o.confirmed)],
      ["📦 Йиғиш керак", list.filter(o => o.confirmed && !o.ready)],
      [S.sc ? "🤝 Йиғувчига бериш" : "🚚 Машинага юклаш", list.filter(o => o.ready && !isLoaded(o))],
      [S.sc ? "✅ Берилган" : "✅ Юкланган", list.filter(o => o.ready && isLoaded(o))]];
    if (S.busy) return;
    w.innerHTML = `<div class="kpi">${g.slice(0, 3).map(([n, a]) => `<div><b>${a.length}</b>${n.replace(/^\S+\s/, "")}</div>`).join("")}</div>
      <div class="acts"><button data-ordreload>🔄 Янгилаш</button></div>
      ${list.length ? g.map(([n, a]) => a.length ? `<h3 class="sec">${n} · ${a.length}</h3>${a.map(ordCard).join("")}` : "").join("") : `<div class="msg">Ҳозирча фаол буюртма йўқ. Янги буюртма келса, шу ерда ва ботда кўринади — қайси биридан жавоб берсангиз ҳам бўлади.</div>`}`;
  } catch (err) { w.innerHTML = `<div class="msg">${esc(err.message)}</div>`; }
}
const PST = { paid:"Тўланди ✅", pending:"Тўлов кутилмоқда", rejected:"Рад этилган" };
async function acctLoad(){
  const w = $("acct"); if (!w) return;
  try {
    const a = await call({ action:"s_account" });
    const card = (t, x) => `<div class="fast" style="margin:0 0 10px"><b>${t}</b><small style="display:block;opacity:.7;margin:2px 0 6px">${x.count} та буюртма</small>
      <div class="irow" style="grid-template-columns:1fr auto"><span>📦 Материаллар суммаси</span><b>${fmt(x.total)}</b></div>
      <div class="irow" style="grid-template-columns:1fr auto"><span>🏛 Платформага комиссия</span><b class="warn">${x.commission ? "−" : ""}${fmt(x.commission)}</b></div>
      <div class="irow" style="grid-template-columns:1fr auto"><span>💳 Сизга тушади</span><b class="ok">${fmt(x.net)}</b></div></div>`;
    const hd = a.handed || { count:0, total:0, commission:0, net:0, list:[] }, acc = (a.all.net || 0) + hd.net, pd = (a.all.net || 0) + (hd.sent || 0);
    const hcard = `<div class="fast" style="margin:0 0 10px"><b>💰 Ҳисоб-китоб</b><small style="display:block;opacity:.7;margin:2px 0 6px">Товар йиғувчига топширилгач пул дарҳол ҳисобланади. Мижоз «Олдим» ни босгач тасдиқланади ва ўтказилади</small>
      <div class="irow" style="grid-template-columns:1fr auto"><span>🧾 Ҳисобланди</span><b>${fmt(acc)}</b></div>
      <div class="irow" style="grid-template-columns:1fr auto"><span>⏳ Мижоз «Олдим» ни кутяпти</span><b class="warn">${fmt(hd.waiting || 0)}</b></div>
      ${hd.held ? `<div class="irow" style="grid-template-columns:1fr auto"><span>⚠️ Мижоз эътироз билдирган</span><b class="warn">${fmt(hd.held)}</b></div>` : ""}
      <div class="irow" style="grid-template-columns:1fr auto"><span>✔️ Тасдиқланди (ўтказилади)</span><b>${fmt(hd.due != null ? hd.due : (hd.confirmed || 0))}</b></div>
      <div class="irow" style="grid-template-columns:1fr auto"><span>✅ Ўтказилди</span><b class="ok">${fmt(pd)}</b></div></div>
      ${hd.list.length ? `<h3 class="sec">Топширилган товарлар</h3><div class="list">${hd.list.map(r => `<div class="irow" style="grid-template-columns:1fr auto"><span><b>№${r.no}</b><small>${r.st === "free" ? "✔️ тасдиқланди" : r.st === "hold" ? "⚠️ эътироз" : "⏳ мижоз кутилмоқда"} · ${fmt(r.total)}${r.commission ? ` − комиссия ${r.pct}% (${fmt(r.commission)})` : ""}</small></span><b class="${r.st === "free" ? "ok" : "warn"}">${fmt(r.net)}</b></div>`).join("")}</div>` : ""}`;
    w.innerHTML = `${hcard}${card("Шу ой (сўм)", a.month)}${card("Бутун давр (сўм)", a.all)}
      ${a.pending.count ? `<div class="fast"><b>⏳ Тўлов кутилмоқда: ${a.pending.count} та</b><p>Материаллар ${fmt(a.pending.total == null ? a.pending.net : a.pending.total)} сўм${a.pending.commission ? `, платформага комиссия ${fmt(a.pending.commission)} сўм` : ""}. Админ тасдиқлагач ${fmt(a.pending.net)} сўм карталингизга тушади.</p></div>` : ""}
      <h3 class="sec">Тўловлар тарихи</h3>
      <div class="list">${a.history.length ? a.history.map(r => `<div class="irow" style="grid-template-columns:1fr auto"><span><b>№${r.no}</b> · ${esc(PST[r.status] || r.status)}<small>${new Date(r.at).toLocaleDateString("ru-RU")} · ${fmt(r.total)}${r.commission ? ` − комиссия ${r.pct}% (${fmt(r.commission)})` : ""}</small></span><b class="${r.status === "paid" ? "ok" : "warn"}">${fmt(r.net)}</b></div>`).join("") : `<div class="msg">Ҳали тўловлар йўқ.</div>`}</div>`;
  } catch (err) { w.innerHTML = `<div class="msg">${esc(err.message)}</div>`; }
}
function setTab(t){ S.tab = t; clearInterval(setTab.t); render(); if (t === "today") { todayLoad(); setTab.t = setInterval(todayLoad, 15000); } window.scrollTo(0, 0); }
document.addEventListener("click", async e => {
  const t = e.target.closest("button"); if (!t) return;
  if (t.dataset.tab) setTab(t.dataset.tab);
  else if (t.hasAttribute("data-ordreload")) todayLoad();
  else if (t.dataset.chk){ S.chk[t.dataset.chk] = !S.chk[t.dataset.chk]; if (TG && TG.HapticFeedback) TG.HapticFeedback.selectionChanged(); todayLoad(); }
  else if (t.dataset.ordready || t.dataset.ordload || t.dataset.ocf || t.dataset.otg){
    if (S.busy) return; S.busy = true; t.disabled = true;
    const [mid, ln] = String(t.dataset.otg || "").split(":");
    const body = t.dataset.otg ? { action:"s_toggle", msg_id:+mid, line_no:+ln } : t.dataset.ocf ? { action:"s_confirm", msg_id:+t.dataset.ocf }
      : { action: t.dataset.ordready ? "s_ready" : "s_loaded", msg_id:+(t.dataset.ordready || t.dataset.ordload) };
    try { const r = await call(body); toast(t.dataset.otg ? (r.on ? "✅ Бор" : "❌ Йўқ") : t.dataset.ocf ? "👍 Тасдиқланди" : "✓ Белгиланди"); if (TG && TG.HapticFeedback) TG.HapticFeedback.notificationOccurred("success"); }
    catch (err) { toast(err.message); }
    S.busy = false; todayLoad();
  }
});

function dropSes(){ SES = ""; S.data = null; clearInterval(setTab.t); try { localStorage.removeItem("sel_ses"); } catch (e) {} $("bar").hidden = true; }
function loginView(msg){
  TGLOGIN.view({ el:"app", wrap:"lgn", mu:"muted", title:"🏪 Дўкон кабинети", text:"Telegram ботдаги дўкон аккаунтингиз орқали киринг.", prefix:"slogin_", newFn:"col_login_new", checkFn:"col_login_check", msg,
    onOk: ses => { SES = ses; try { localStorage.setItem("sel_ses", SES); } catch (e) {} boot(); } });
}
async function boot(){
  if (!IN_TG && !SES) return loginView();
  try { S.data = await call({ action:"load" }); TamirPush.init({ app:"seller", base:"uz", token:() => SES, lang:() => "uz" }); setTab("today"); }
  catch (err) { if (err.message !== "auth" && err.message !== "reg") $("app").innerHTML = `<div class="msg">${esc(err.message)}</div>`; }
}
boot();
if (!IN_TG && "serviceWorker" in navigator) navigator.serviceWorker.register("sw.js").catch(() => {});
