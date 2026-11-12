window.__pull=function(){return refreshData()};
// Кабинет йиғувчи (сборщика рынка). Открывается из бота @tamir_sotuvchi_bot.
const API = (window.TAMIR_CONFIG || {}).botApi || "https://agajmytkjpkihvaurqij.supabase.co/functions/v1/tg-bot";
const TG = window.Telegram && window.Telegram.WebApp;
const IN_TG = !!(TG && TG.initData);
let SES = ""; try { SES = localStorage.getItem("col_ses") || ""; } catch (e) {}
const TC = window.TAMIR_CATALOG || { core:[], items:[], units:{} };
const UZ = new Map();
(TC.core || []).forEach(([id, base, n, s]) => UZ.set(id, { n, s }));
(TC.items || []).forEach(x => UZ.set(x[0], { n:x[7] || x[3], s:x[8] || x[4] }));
const UNIT = Object.assign({ "мешок":"қоп", "шт":"дона", "упак.":"қадоқ", "ведро":"челак", "набор":"тўплам" }, TC.units || {});
const S = { tab:"orders", d:null, open:null, shop:"", sel:{}, qty:{}, price:{}, pshop:"", poff:{}, pq:"", form:null };
const fmt = n => Math.round(n).toLocaleString("ru-RU").replace(/ /g, " ");
const num = s => +String(s).replace(",", ".").replace(/[^\d.]/g, "") || 0;
const esc = s => String(s ?? "").replace(/[&<>"]/g, c => ({ "&":"&amp;", "<":"&lt;", ">":"&gt;", '"':"&quot;" }[c]));
const $ = id => document.getElementById(id);
const ruMode = () => window.LG && LG.lang() === "ru";
const pname = (id, n) => ruMode() ? n : (UZ.get(id) || {}).n || n;
window.addEventListener("langchange", () => { try { if (S.d) render(); } catch (e) {} });
const unit = u => UNIT[u] || u;
function toast(t){ const el = $("toast"); el.textContent = t; el.classList.add("show"); clearTimeout(toast.t); toast.t = setTimeout(() => el.classList.remove("show"), 2400); }
async function call(body){
  const r = await fetch(API, { method:"POST", headers:Object.assign({ "content-type":"application/json" }, IN_TG ? { "x-init-data":TG.initData } : { "x-col-session":SES }), body:JSON.stringify(body) });
  const j = await r.json().catch(() => ({}));
  if (r.status === 401 && !IN_TG) { dropSes(); loginView("Сессия тугади, қайта киринг."); throw new Error("auth"); }
  if (!r.ok) throw new Error(j.error || "Хато. Қайта уриниб кўринг.");
  return j;
}
async function load(){ S.d = await call({ action:"c_load" }); }
const shopById = id => S.d.shops.find(s => s.id === +id);
const STG = ["Қабул қилинди", "Олинди", "Йиғилмоқда", "Йўлда", "Етказилди"];

// ---------- Буюртмалар ----------
function ordersHTML(){
  const d = S.d;
  return `<h1>🧺 Салом${d.me.name ? ", " + esc(d.me.name) : ""}!</h1>${d.me.market ? `<div class="muted" style="margin:-6px 0 8px">🏬 ${esc(d.me.market)}</div>` : ""}
    <h2>Янги буюртмалар (${d.open.length})</h2>
    ${d.open.map(o => `<div class="card"><div class="row"><div class="sp"><b>№${o.no}</b> · ${o.n} та товар · ${fmt(o.total)} сўм
      <div class="muted">🕒 ${esc(o.slot)}${o.address ? " · 📍 " + esc(o.address) : ""}</div></div>
      <button class="btn" data-claim="${o.no}">🙋 Мен оламан</button></div></div>`).join("") || `<div class="card muted">Ҳозирча янги буюртма йўқ.</div>`}
    <h2>Менинг буюртмаларим (${d.my.length})</h2>
    ${d.my.map(o => { const act = o.lines.filter(l => l.status !== "missing"), got = act.filter(l => d.sc ? l.loaded : l.status === "ready").length;
      return `<div class="card" data-openo="${o.no}" role="button"><div class="row"><div class="sp"><b>№${o.no}</b> · ${esc(o.customer)}
        <div class="muted">🕒 ${esc(o.slot)}</div></div><span class="pill ${o.stage >= 3 ? "g" : "y"}">${o.driver_id ? "Топширилди" : STG[o.stage]}</span></div>
        <div class="bar"><i style="width:${act.length ? Math.round(got / act.length * 100) : 0}%"></i></div><div class="muted" style="margin-top:4px">${got} / ${act.length} та олинди</div></div>`; }).join("") || `<div class="card muted">Сизда фаол буюртма йўқ.</div>`}`;
}
// shop_collect: дўконлар тайёрлайди, йиғувчи олиб кетади ва паркка беради — ботдаги «… дан олдим» / «Паркка бериш» билан бир хил
function pickupHTML(o){
  const act = o.lines.filter(l => l.status !== "missing" && l.shop_id), miss = o.lines.filter(l => l.status === "missing"), wait = o.lines.filter(l => l.status === "pending" || !l.shop_id && l.status !== "missing");
  const by = {}; act.forEach(l => (by[l.shop_id] = by[l.shop_id] || []).push(l));
  const got = act.filter(l => l.loaded).length, all = act.length > 0 && got === act.length && !wait.length;
  const map = o.lat ? `https://yandex.uz/maps/?pt=${o.lng},${o.lat}&z=17&l=map` : null;
  const shop = id => (o.shops || {})[id] || shopById(id) || {};
  return `<button class="btn ghost sm" data-back>← Буюртмалар</button>
    <h1 style="margin-top:10px">№${o.no} · ${esc(o.customer)}</h1>
    <div class="card"><div>📱 <a href="tel:${esc(o.phone)}">${esc(o.phone)}</a></div>
      ${o.address ? `<div>📍 ${esc(o.address)}${map ? ` · <a href="${map}" target="_blank">харита</a>` : ""}</div>` : ""}
      <div>🕒 ${esc(o.slot)}</div>${o.note ? `<div>💬 ${esc(o.note)}</div>` : ""}
      <div class="bar"><i style="width:${act.length ? Math.round(got / act.length * 100) : 0}%"></i></div>
      <div class="muted" style="margin-top:4px">${got} / ${act.length} та олинди${miss.length ? ` · ${miss.length} та топилмади` : ""}</div></div>
    <h2>🧺 Олиш рўйхати</h2>
    ${Object.entries(by).map(([sid, ls]) => { const s = shop(sid), taken = ls.every(l => l.loaded), ready = ls.every(l => l.status === "ready");
      return `<div class="card"><div class="row"><div class="sp"><b>🏪 ${esc(s.name || "Дўкон")}</b>${s.row ? ` · ${esc(s.row)}` : ""}${s.phone ? `<div class="muted">📱 <a href="tel:${esc(s.phone)}">${esc(s.phone)}</a></div>` : ""}</div>
        <span class="pill ${taken ? "g" : ready ? "y" : ""}">${taken ? "✅ Олинди" : ready ? "📦 Тайёр" : "⏳ Тайёрланмоқда"}</span></div>
        ${ls.map(l => `<div class="done-ln"><span>${esc(pname(l.product_id, l.name))} — ${fmt(l.qty)} ${esc(unit(l.unit))}</span><span>${l.loaded ? "✅" : ""}</span></div>`).join("")}
        ${ready && !taken && o.stage < 2 ? `<button class="btn" style="width:100%;margin-top:8px" data-pk="${sid}">✅ ${esc(s.name || "Дўкон")} дан олдим</button>` : ""}</div>`; }).join("")}
    ${wait.length ? `<div class="card muted">⏳ ${wait.length} та товар учун дўкон жавоби кутилмоқда.</div>` : ""}
    ${miss.length ? `<h2>❌ Топилмади (${miss.length})</h2><div class="card">${miss.map(l => `<div class="done-ln"><span>${esc(pname(l.product_id, l.name))} — ${fmt(l.qty)} ${esc(unit(l.unit))}</span></div>`).join("")}<div class="muted">Админ мижоз билан гаплашади.</div></div>` : ""}
    ${o.stage >= 2 ? `<div class="card"><span class="pill g">🚕 Паркка берилди</span> ${o.driver ? `<span class="muted">Ҳайдовчи: ${esc(o.driver.name || "")}${o.driver.car ? " · " + esc(o.driver.car) : ""}${o.driver.phone ? ` · <a href="tel:${esc(o.driver.phone)}">${esc(o.driver.phone)}</a>` : ""}</span>` : `<span class="muted">Ҳайдовчи кутилмоқда.</span>`}</div>`
      : all ? `<div class="card"><p class="muted" style="margin:0 0 8px">Ҳамма товар олинди. Машина турадиган жойга олиб бориб, тугмани босинг.</p>
      <button class="btn dark" style="width:100%" data-pf="1">🚕 Паркка (ҳайдовчига) бериш</button></div>` : ""}`;
}
function orderHTML(o){
  if (S.d.sc && o.mode !== "car") return pickupHTML(o);
  const pend = o.lines.filter(l => l.status === "pending"), wait = o.purchases.filter(p => p.status === "pending");
  const ready = o.lines.filter(l => l.status === "ready"), miss = o.lines.filter(l => l.status === "missing");
  const act = o.lines.filter(l => l.status !== "missing");
  const offShop = S.shop ? (S.shopOffers || {}) : {};
  const map = o.lat ? `https://yandex.uz/maps/?pt=${o.lng},${o.lat}&z=17&l=map` : null;
  const byShop = {}; ready.forEach(l => (byShop[l.shop_id] = byShop[l.shop_id] || []).push(l));
  const allDone = !pend.length && !wait.length && ready.length;
  return `<button class="btn ghost sm" data-back>← Буюртмалар</button>
    <h1 style="margin-top:10px">№${o.no} · ${esc(o.customer)}</h1>
    <div class="card"><div>📱 <a href="tel:${esc(o.phone)}">${esc(o.phone)}</a></div>
      ${o.address ? `<div>📍 ${esc(o.address)}${map ? ` · <a href="${map}" target="_blank">харита</a>` : ""}</div>` : ""}
      <div>🕒 ${esc(o.slot)}</div>${o.note ? `<div>💬 ${esc(o.note)}</div>` : ""}
      <div class="bar"><i style="width:${act.length ? Math.round(ready.length / act.length * 100) : 0}%"></i></div>
      <div class="muted" style="margin-top:4px">${ready.length} / ${act.length} та олинди${miss.length ? ` · ${miss.length} та топилмади` : ""}</div></div>
    ${pend.length ? `<h2>🛒 Олиш керак (${pend.length})</h2><div class="card">
      <label class="field">Қайси дўкондасиз?<select id="shopSel"><option value="">— дўконни танланг —</option>
        ${S.d.shops.map(s => `<option value="${s.id}" ${+S.shop === s.id ? "selected" : ""}>${esc(s.name)} · ${esc(s.row)}</option>`).join("")}
        <option value="new">➕ Янги дўкон қўшиш</option></select></label>
      ${pend.map(l => { const pr = S.price[l.line_no] ?? (l.product_id && offShop[l.product_id] ? offShop[l.product_id].price : l.client_price);
        return `<div class="ln"><input type="checkbox" data-sel="${l.line_no}" ${S.sel[l.line_no] ? "checked" : ""} aria-label="Танлаш">
        <div><div class="nm">${esc(pname(l.product_id, l.name))}</div><div class="muted">керак: ${fmt(l.qty)} ${esc(unit(l.unit))} · мижоз нархи ${fmt(l.client_price)}</div></div>
        <div class="in"><input inputmode="decimal" data-qty="${l.line_no}" value="${S.qty[l.line_no] ?? l.qty}" aria-label="Сони"><span class="muted">${esc(unit(l.unit))} ×</span>
          <input class="pr" inputmode="numeric" data-pr="${l.line_no}" value="${fmt(pr)}" aria-label="Нарх"><span class="muted">сўм</span>
          <button class="btn ghost sm" data-miss="${l.line_no}">❌ Топилмади</button></div></div>`; }).join("")}</div>` : ""}
    ${wait.length ? `<h2>⏳ Тўлов кутилмоқда</h2>${wait.map(p => `<div class="card"><b>${esc((shopById(p.shop_id) || {}).name)}</b> · ${fmt(p.total)} сўм · ${p.items.length} та
      <div class="muted">Админ тўлашини кутинг — тўланса, ботга хабар келади.</div></div>`).join("")}` : ""}
    ${ready.length ? `<h2>✅ Олинди (${ready.length})</h2>${Object.entries(byShop).map(([sid, ls]) => `<div class="card"><b>🏪 ${esc((shopById(sid) || {}).name)}</b>
      ${ls.map(l => `<div class="done-ln"><span>${esc(pname(l.product_id, l.name))} — ${fmt(l.qty)} ${esc(unit(l.unit))}</span><span>${fmt(l.price * l.qty)}</span></div>`).join("")}</div>`).join("")}` : ""}
    ${miss.length ? `<h2>❌ Топилмади (${miss.length})</h2><div class="card">${miss.map(l => `<div class="done-ln"><span>${esc(pname(l.product_id, l.name))} — ${fmt(l.qty)} ${esc(unit(l.unit))}</span>
      <button class="btn ghost sm" data-unmiss="${l.line_no}">Қайтариш</button></div>`).join("")}</div>` : ""}
    ${o.driver_id ? `<div class="card"><span class="pill g">🚚 Топширилди</span> <span class="muted">Чек-лист ва йўл — ботда.</span></div>`
      : allDone ? `<h2>📦 Ҳаммаси олинди — кимга топширасиз?</h2><div class="card">
      <p class="muted" style="margin:0 0 8px">Буюртма таксопаркка тушади — ҳайдовчини парк ўзи топади.</p></div>
      <h2>🚕 Таксопаркка бериш</h2><div class="card"><p class="muted" style="margin:0 0 8px">Юк ортиладиган жойни кўрсатинг: шу жой ҳайдовчига ва мижозга «А нуқта» бўлиб кўринади. Юк турган жойда туриб тугмани босинг.</p>
      <input id="fnote" placeholder="Жой таърифи (масалан: Гумбаз бозор, 3-дарвоза)" style="width:100%;margin-bottom:8px">
      <button class="btn dark" style="width:100%" data-fleet="1">🗺 Харитада жойни белгилаб, паркка бериш</button></div>` : ""}`;
}
function stickyOrder(o){
  const pend = o ? o.lines.filter(l => l.status === "pending" && S.sel[l.line_no]) : [];
  const el = $("sticky");
  if (!o || S.tab !== "orders" || S.d.sc || !o.lines.some(l => l.status === "pending")) { el.hidden = true; return; }
  const sum = pend.reduce((a, l) => a + num(S.qty[l.line_no] ?? l.qty) * num(S.price[l.line_no] ?? curPrice(l)), 0);
  el.hidden = false;
  el.innerHTML = `<button class="btn dark" data-buy ${!S.shop || S.shop === "new" || !pend.length ? "disabled" : ""}>💳 Тўловга юбориш${pend.length ? ` · ${pend.length} та · ${fmt(sum)} сўм` : ""}</button>`;
}
const curPrice = l => (l.product_id && S.shopOffers && S.shopOffers[l.product_id]) ? S.shopOffers[l.product_id].price : l.client_price;

// ---------- Нархлар ----------
function pricesHTML(){
  const sNorm = s => String(s || "").toLowerCase().replace(/ё/g, "е").replace(/[ʼ'`ʻ’]/g, ""), sHit = (hay, q) => { const w = sNorm(q).split(/\s+/).filter(Boolean), h = sNorm(hay); return w.every(x => h.includes(x)); };
  const q = S.pq.trim();
  const list = S.pshop ? S.d.products.filter(p => !q || sHit(pname(p.id, p.name) + " " + p.name, q)).slice(0, 80) : [];
  return `<h1>🏷 Нархлар</h1><div class="card"><label class="field" style="margin:0">Дўкон<select id="pshopSel"><option value="">— дўконни танланг —</option>
    ${S.d.shops.map(s => `<option value="${s.id}" ${+S.pshop === s.id ? "selected" : ""}>${esc(s.name)} · ${esc(s.row)}</option>`).join("")}</select></label></div>
    ${S.pshop ? `<label class="search"><input id="pq" type="search" placeholder="Товар қидириш…" value="${esc(S.pq)}"></label>
      <div class="card">${list.map(p => { const o = S.poff[p.id];
        return `<div class="pitem"><div><b>${esc(pname(p.id, p.name))}</b><div class="muted">${esc(ruMode() ? p.spec : (UZ.get(p.id) || {}).s || p.spec)}</div></div>
        <div class="row"><input inputmode="numeric" data-pp="${p.id}" class="${o ? "set" : ""}" value="${o ? fmt(o.price) : ""}" placeholder="нарх"><span class="muted">/${esc(unit(p.unit))}</span></div>
        ${o ? `<div style="grid-column:1/-1" class="row"><span class="muted sp">Сақланган ✓</span><span class="sw"><button class="y" data-pst="${p.id}:1" aria-pressed="${o.in_stock}">Бор</button><button class="n" data-pst="${p.id}:0" aria-pressed="${!o.in_stock}">Йўқ</button></span></div>` : ""}</div>`; }).join("") || `<div class="muted">Топилмади.</div>`}</div>
      <button class="btn" style="width:100%" data-newp>➕ Каталогда йўқ янги товар</button>` : `<div class="msg">Дўконни танланг, кейин унинг нархларини ёзасиз. Ҳар бир нарх дарров сақланади.</div>`}`;
}
function newProductHTML(){
  return `<button class="btn ghost sm" data-cancel>← Орқага</button><h1 style="margin-top:10px">➕ Янги товар</h1><div class="card">
    <label class="field">Тоифа<select id="np_cat">${S.d.cats.map(c => `<option value="${c.id}">${esc(c.name)}</option>`).join("")}</select></label>
    <label class="field">Номи<input id="np_name" placeholder="Масалан: Кафель елими Х"></label>
    <label class="field">Тавсифи<input id="np_spec" placeholder="Масалан: қоп 25 кг"></label>
    <label class="field">Ўлчов<input id="np_unit" placeholder="қоп, дона, м², рулон…"></label>
    <label class="field">Нархи (${esc((shopById(S.pshop) || {}).name || "")})<input id="np_price" inputmode="numeric"></label>
    <button class="btn dark" style="width:100%" data-npsave>Админга юбориш</button>
    <p class="muted">Админ тасдиқлагач, товар мижозлар каталогида пайдо бўлади.</p></div>`;
}
// ---------- Дўконлар ----------
function shopsHTML(){
  return `<h1>🏪 Дўконлар (${S.d.shops.length})</h1><button class="btn" style="width:100%;margin-bottom:10px" data-newshop>➕ Янги дўкон қўшиш</button>
    ${S.d.shops.map(s => `<div class="card"><b>${esc(s.name)}</b> · ${esc(s.row)}<div class="muted">📱 ${esc(s.phone || "—")} · 💳 ${esc(s.card || "карта йўқ")}</div></div>`).join("")}`;
}
function newShopHTML(){
  return `<button class="btn ghost sm" data-cancel>← Орқага</button><h1 style="margin-top:10px">➕ Янги дўкон</h1><div class="card">
    <label class="field">Дўкон номи<input id="ns_name" placeholder="Масалан: Азиз Строй"></label>
    <label class="field">Жойи (қатор, дўкон рақами)<input id="ns_row" placeholder="Масалан: 7-қатор, 15-дўкон"></label>
    <label class="field">Телефон<input id="ns_phone" type="tel" placeholder="+998 90 123 45 67"></label>
    <label class="field">Карта рақами (тўлов учун)<input id="ns_card" inputmode="numeric" placeholder="8600 0000 0000 0000"></label>
    <button class="btn dark" style="width:100%" data-nssave>Сақлаш</button></div>`;
}

const splitHTML = (sp) => !sp ? "" : `<div class="card"><h2>Хизмат ҳақи тақсимоти</h2><div class="kv"><span>Хизмат ҳақи (жами)</span><b>${fmt(sp.gross)} сўм</b><span>Платформа ҳиссаси</span><b>${sp.platform ? "−" : ""}${fmt(sp.platform)} сўм</b>${sp.accrued == null ? `<span>Сизга тушади</span><b>${fmt(sp.net)} сўм</b>` : `<span>Ҳисобланди</span><b>${fmt(sp.accrued)} сўм</b>${sp.confirmed == null ? "" : `<span>Мижоз тасдиғини кутмоқда</span><b>${fmt((sp.waiting || 0) + (sp.held || 0))} сўм</b><span>Тасдиқланди (ўтказилади)</span><b>${fmt(sp.due)} сўм</b>`}<span>Ўтказилди</span><b>${fmt(sp.paid)} сўм</b>`}</div><p class="muted">${sp.orders} та якунланган буюртма бўйича. Тўловлар онлайн, мижоздан буюртма вақтида ечилади.</p></div>`;
function earnHTML(){
  const e = S.d.earn;
  if (!e) return `<h1>💳 Ҳисоб</h1><div class="card muted">Ҳисоб ҳали кўринмайди: бот янгиланмаган.</div>`;
  return `<h1>💳 Ҳисоб</h1>${splitHTML(S.d.split)}<div class="card"><div class="kv"><span>Тўланиши керак</span><b>${fmt(e.due || 0)} сўм</b><span>Кутилмоқда (24 соат / мижоз тасдиғи)</span><b>${fmt((e.waiting || 0) + (e.held || 0))} сўм</b><span>Тўланган</span><b>${fmt(e.paid || 0)} сўм</b></div>
    <p class="muted">Ҳақ буюртма етказилгач, мижоз «Олдим» деганда ёки 24 соатдан кейин «Тўланиши керак»га ўтади.</p></div>${pushCard()}`;
}
// телефонга билдиришнома (Telegram ичида кўринмайди — у ерда бот хабари келади)
const pushCard = () => { const b = TamirPush.btn("btn ghost", "width:100%"); return b ? `<div class="card">${b}<p class="muted" style="margin:8px 0 0">Янги буюртма ва тўлов хабарлари телефон блокда бўлса ҳам келади.</p></div>` : ""; };
function render(){
  document.querySelectorAll("nav button").forEach(b => b.setAttribute("aria-current", b.dataset.tab === S.tab ? "page" : "false"));
  const o = S.open && S.d.my.find(x => x.no === S.open);
  let h;
  if (S.form === "shop") h = newShopHTML(); else if (S.form === "product") h = newProductHTML();
  else if (S.tab === "orders") h = o ? orderHTML(o) : ordersHTML();
  else if (S.tab === "prices") h = pricesHTML(); else if (S.tab === "earn") h = earnHTML(); else h = shopsHTML();
  $("app").innerHTML = h;
  stickyOrder(S.tab === "orders" && !S.form ? o : null);
}
let RAW = "";
async function refreshData(){ try { await load(); const raw = JSON.stringify(S.d); if (raw === RAW) return; if (!document.activeElement || !document.activeElement.matches("input,select,textarea")) { RAW = raw; const y = window.scrollY; render(); window.scrollTo(0, y); } } catch (e) {} }
async function loadShopOffers(id){ S.shopOffers = id && id !== "new" ? (await call({ action:"c_offers", shop_id:+id })).offers : {}; }
const LEAF = "https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/"; let leafletP = null;
function loadLeaflet(){ if (window.TAMIR_YMAPS) return loadYandexAsL(); if (window.L) return Promise.resolve();
  if (!leafletP) leafletP = new Promise((res, rej) => { const l = document.createElement("link"); l.rel = "stylesheet"; l.href = LEAF + "leaflet.min.css"; document.head.appendChild(l);
    const sc = document.createElement("script"); sc.src = LEAF + "leaflet.min.js"; sc.onload = res; sc.onerror = () => { leafletP = null; rej(new Error("map")); }; document.head.appendChild(sc); });
  return leafletP; }
async function pickPoint(onOk){
  const ov = document.createElement("div"); ov.className = "pick";
  ov.innerHTML = `<div class="pick-top"><b>Юк қаерда ортилади?</b><button class="x" type="button" id="pkx">✕</button></div>
    <div class="pick-mw"><div class="pick-map" id="pkMap"></div><div class="pin">${IC.pin()}</div></div>
    <div class="pick-bot"><button class="btn ghost" type="button" id="pkme">${IC.i("locate",18)} Менинг жойим</button><button class="btn dark" type="button" id="pkok">Тайёр — паркка бериш</button>
    <small>Харитани суриб, 📍 юк ортиладиган жойда турсин.</small></div>`;
  document.body.appendChild(ov);
  const close = () => ov.remove(); ov.querySelector("#pkx").onclick = close;
  try { await loadLeaflet(); } catch (e) { ov.querySelector("#pkMap").textContent = "Харита юкланмади. Интернетни текширинг."; return; }
  const map = L.map("pkMap", { zoomControl:false }); L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", { maxZoom:19, attribution:"© OpenStreetMap" }).addTo(map);
  map.setView([41.3111, 69.2797], 12);
  const me = () => navigator.geolocation && navigator.geolocation.getCurrentPosition(p => map.setView([p.coords.latitude, p.coords.longitude], 17), () => toast("Жойлашув аниқланмади — харитани қўлда суринг"), { enableHighAccuracy:true, timeout:8000 });
  ov.querySelector("#pkme").onclick = me; me();
  ov.querySelector("#pkok").onclick = () => { const c = map.getCenter(); close(); onOk(+c.lat.toFixed(6), +c.lng.toFixed(6)); };
}
async function act(fn, okMsg){ try { await fn(); await load(); RAW = JSON.stringify(S.d); render(); if (okMsg) toast(okMsg); if (TG && TG.HapticFeedback) TG.HapticFeedback.notificationOccurred("success"); } catch (e) { toast(e.message); } }

document.addEventListener("click", async e => {
  const b = e.target.closest("button,[data-openo]"); if (!b) return;
  const ds = b.dataset;
  if (ds.tab) { S.tab = ds.tab; S.form = null; S.open = null; render(); window.scrollTo(0, 0); if (ds.tab === "earn") act(async () => {}); }
  else if (ds.openo) { S.open = +ds.openo; S.sel = {}; S.qty = {}; S.price = {}; render(); window.scrollTo(0, 0); refreshData(); }
  else if ("back" in ds) { S.open = null; render(); refreshData(); }
  else if ("cancel" in ds) { S.form = null; render(); }
  else if (ds.claim) act(async () => { await call({ action:"c_claim", no:+ds.claim }); S.open = +ds.claim; }, "Буюртма сизники");
  else if (ds.pk) act(() => call({ action:"c_pickup", no:S.open, shop_id:+ds.pk }), "✅ Белгиланди: дўкон товари сизда");
  else if ("pf" in ds) { if (!confirm("Ҳамма товар машина турадиган жойдами? Паркка берилсинми?")) return; let sent = 0; act(async () => { sent = (await call({ action:"c_tofleet", no:S.open })).sent; }).then(() => { if (S.d.my.some(x => x.no === S.open && x.stage >= 2)) toast(sent ? `🚕 Паркка юборилди (${sent} ҳайдовчи)` : "⚠️ Паркда фаол ҳайдовчи йўқ — админ тайинлайди"); }); }
  else if (ds.miss) act(() => call({ action:"c_missing", no:S.open, line_no:+ds.miss, on:true }), "Топилмади деб белгиланди");
  else if (ds.unmiss) act(() => call({ action:"c_missing", no:S.open, line_no:+ds.unmiss, on:false }));
  else if ("buy" in ds) {
    const o = S.d.my.find(x => x.no === S.open);
    const lines = o.lines.filter(l => l.status === "pending" && S.sel[l.line_no]).map(l => ({ line_no:l.line_no, qty:num(S.qty[l.line_no] ?? l.qty), price:num(S.price[l.line_no] ?? curPrice(l)) }));
    act(async () => { await call({ action:"c_buy", no:S.open, shop_id:+S.shop, lines }); S.sel = {}; S.qty = {}; S.price = {}; }, "💳 Тўлов сўрови админга юборилди");
  }
  else if ("fleet" in ds) {
    const note = (document.getElementById("fnote") || {}).value || "";
    pickPoint((lat, lng) => act(async () => { await call({ action:"c_done", no:S.open }).catch(() => {}); await call({ action:"c_handoff", no:S.open, fleet:true, lat, lng, note }); }, "🚕 Паркка юборилди: ҳайдовчилар ботида"));
  }
  else if (ds.hand) act(async () => { await call({ action:"c_done", no:S.open }).catch(() => {}); await call({ action:"c_handoff", no:S.open, ...(ds.hand === "self" ? { self:true } : { driver_id:+ds.hand }) }); },
    ds.hand === "self" ? "Ботда юклаш рўйхати келди" : "Ҳайдовчига топширилди");
  else if (ds.pst) { const [id, v] = ds.pst.split(":"); const o = S.poff[id]; act(async () => { await call({ action:"c_price", shop_id:+S.pshop, product_id:+id, price:o.price, in_stock:v === "1" }); S.poff[id].in_stock = v === "1"; }); }
  else if ("newp" in ds) { S.form = "product"; render(); }
  else if ("newshop" in ds) { S.form = "shop"; render(); }
  else if ("nssave" in ds) act(async () => {
    const r = await call({ action:"c_addshop", name:$("ns_name").value, row:$("ns_row").value, phone:$("ns_phone").value, card:$("ns_card").value });
    S.form = null; if (S.open) { S.shop = String(r.shop.id); S.shopOffers = {}; }
  }, "Дўкон қўшилди");
  else if ("npsave" in ds) act(async () => {
    if (!/\p{L}/u.test($("np_unit").value)) throw new Error("Ўлчов сўз билан: дона, қоп, кг, м²…");
    await call({ action:"c_newproduct", cat:$("np_cat").value, name:$("np_name").value, spec:$("np_spec").value, unit:$("np_unit").value, price:num($("np_price").value), shop_id:+S.pshop });
    S.form = null;
  }, "Админга юборилди");
});
document.addEventListener("change", async e => {
  const t = e.target;
  if (t.id === "shopSel") { S.shop = t.value; if (t.value === "new") { S.form = "shop"; render(); return; } try { await loadShopOffers(t.value); } catch (er) {} S.price = {}; render(); }
  else if (t.id === "pshopSel") { S.pshop = t.value; S.poff = t.value ? (await call({ action:"c_offers", shop_id:+t.value })).offers : {}; render(); }
  else if (t.dataset.sel) { S.sel[t.dataset.sel] = t.checked; stickyOrder(S.d.my.find(x => x.no === S.open)); }
  else if (t.dataset.qty) { S.qty[t.dataset.qty] = num(t.value); stickyOrder(S.d.my.find(x => x.no === S.open)); }
  else if (t.dataset.pr) { S.price[t.dataset.pr] = num(t.value); S.sel[t.dataset.pr] = true; const c = document.querySelector(`[data-sel="${t.dataset.pr}"]`); if (c) c.checked = true; stickyOrder(S.d.my.find(x => x.no === S.open)); }
  else if (t.dataset.pp) {
    const id = t.dataset.pp, price = num(t.value);
    try { await call({ action:"c_price", shop_id:+S.pshop, product_id:+id, price, in_stock:true }); if (price) S.poff[id] = { price, in_stock:true }; else delete S.poff[id]; t.classList.toggle("set", !!price); toast(price ? "✓ Сақланди" : "Ўчирилди"); }
    catch (er) { toast(er.message); }
  }
});
document.addEventListener("input", e => { if (e.target.id === "pq") { S.pq = e.target.value; const pos = e.target.selectionStart; render(); const q = $("pq"); q.focus(); q.setSelectionRange(pos, pos); } });

let LASTSIG = null, SEEN = new Set(), PB = false, LASTFULL = Date.now();
function beepC(){ if (window.SND) SND.play(); }
async function pingTick(force){
  if (PB || (document.hidden && !force)) return; PB = true;
  try {
    const r = await call({ action:"c_ping" });
    const fresh = r.open.filter(n => !SEEN.has(n));
    if (fresh.length) { fresh.forEach(n => SEEN.add(n)); beepC(); toast("Янги буюртма №" + fresh.join(", №")); }
    if (r.sig !== LASTSIG || Date.now() - LASTFULL > 30000) { LASTSIG = r.sig; LASTFULL = Date.now(); await refreshData(); }
  } catch (e) {} finally { PB = false; }
}
function dropSes(){ SES = ""; try { localStorage.removeItem("col_ses"); } catch (e) {} clearInterval(boot.iv); $("nav").hidden = true; $("sticky").hidden = true; }
function loginView(msg){
  $("hdr").hidden = false; $("hout").hidden = true; $("hme").textContent = "";
  TGLOGIN.view({ el:"app", wrap:"lg", mu:"muted", title:"Йиғувчи кабинети", text:"Telegram ботдаги йиғувчи аккаунтингиз орқали киринг.", prefix:"clogin_", newFn:"col_login_new", checkFn:"col_login_check", msg,
    onOk: ses => { SES = ses; try { localStorage.setItem("col_ses", SES); } catch (e) {} boot(); } });
}
async function boot(){
  $("hdr").hidden = false;
  if (!IN_TG && !SES) return loginView();
  if (IN_TG) { TG.ready(); TG.expand(); }
  try {
    await load(); $("nav").hidden = false; $("hme").textContent = (S.d.me && S.d.me.name) || "";
    if (!IN_TG) { $("hout").hidden = false; $("hout").onclick = () => { dropSes(); loginView(); }; }
    TamirPush.init({ app:"collector", base:"uz", token:() => SES, lang:() => LG.lang(), tr:s => LG.tr(s) });
    render(); LASTSIG = null; SEEN = new Set((S.d.open || []).map(o => o.no)); clearInterval(boot.iv); boot.iv = setInterval(pingTick, 3000); document.addEventListener("visibilitychange", () => { if (!document.hidden && (SES || IN_TG)) pingTick(true); });
  } catch (err) { if (err.message !== "auth") $("app").innerHTML = `<div class="msg">${esc(err.message)}</div>`; }
}
boot();
