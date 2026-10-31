// Ta'mir — иловага «Telegram орқали кириш» (ҳайдовчи, йиғувчи, дўкон иловалари учун умумий).
// Илова очилади → «Telegram орқали кириш» → бот «Start» → илова ўзи киради (токен 2 сония оралиқда текширилади).
// TGLOGIN.view({ el, title, text, prefix:"dlogin_", newFn:"drv_login_new", checkFn:"drv_login_check", onOk(session, r), msg, wrap, btn, mu })
// TGLOGIN.miniSession(action) — Telegram ичида (Mini App) очилганда initData орқали сессия олади, бўлмаса null.
(function () {
  var C = window.TAMIR_CONFIG || {}, BOT = C.env === "test" ? "tamir_test1_bot" : "tamir_sotuvchi_bot";
  var TG = window.Telegram && window.Telegram.WebApp;
  var esc = function (s) { return String(s == null ? "" : s).replace(/[&<>"]/g, function (c) { return { "&":"&amp;", "<":"&lt;", ">":"&gt;", '"':"&quot;" }[c]; }); };
  var RUN = 0;
  if (TG && TG.initData) { try { TG.ready(); TG.expand(); } catch (e) {} }
  async function rpc(fn, args) {
    var r = await fetch(C.supabaseUrl + "/rest/v1/rpc/" + fn, { method:"POST", headers:{ apikey:C.supabaseKey, Authorization:"Bearer " + C.supabaseKey, "content-type":"application/json" }, body:JSON.stringify(args || {}) });
    var j = await r.json().catch(function () { return null; });
    if (!r.ok) throw new Error((j && (j.message || j.hint)) || "Хато");
    return j;
  }
  // iPhone (Safari / ekranga qo'shilgan ilova): havola bosilgan zahoti ochilishi kerak — await dan keyingi window.open bloklanadi.
  // Shuning uchun token oldindan olinadi, tugma oddiy <a> havola. Token localStorage da saqlanadi: iOS ilovani fonda yopib qo'ysa ham,
  // qaytib ochilganda tekshirish davom etadi. Ilovaga qaytganda (visibilitychange) darhol tekshiriladi.
  // Asosiy tugma tg:// orqali to'g'ridan-to'g'ri Telegram ilovasini ochadi (iPhone'da t.me ba'zan Safari'da sahifa bo'lib ochiladi
  // va ilovadan chiqib ketadi). Telegram o'rnatilmagan bo'lsa — pastdagi kichik t.me havola (yangi oynada).
  function store(k, v) { try { if (v) localStorage.setItem(k, JSON.stringify(v)); else localStorage.removeItem(k); } catch (e) {} }
  function load(k) { try { return JSON.parse(localStorage.getItem(k) || "null"); } catch (e) { return null; } }
  function view(o) {
    var run = ++RUN, el = typeof o.el === "string" ? document.getElementById(o.el) : o.el, key = "tgl_" + o.prefix;
    el.innerHTML = '<div class="' + (o.wrap || "center") + '"><h1>' + esc(o.title) + '</h1><p class="' + (o.mu || "mu") + '">' + esc(o.text || "Telegram ботдаги аккаунтингиз орқали киринг.") + '</p>' +
      '<a class="' + (o.btn || "btn") + '" id="tglb" href="#" aria-disabled="true" style="display:inline-block;width:100%;max-width:320px;text-decoration:none;text-align:center;opacity:.5">Telegram орқали кириш</a>' +
      '<p class="' + (o.mu || "mu") + '" id="tglm" aria-live="polite">' + esc(o.msg || "") + '</p>' +
      '<p class="' + (o.mu || "mu") + '" style="font-size:13px">Telegram очилмадими? <a id="tglw" href="#" target="_blank" rel="noopener" style="color:inherit">Бу ерни босинг</a></p></div>';
    var a = document.getElementById("tglb"), w = document.getElementById("tglw"), m = document.getElementById("tglm"), cur = null, busy = false, stop = false;
    var alive = function () { return run === RUN && !stop && document.body.contains(a); };
    function done() { stop = true; store(key, null); document.removeEventListener("visibilitychange", onVis); window.removeEventListener("focus", onVis); window.removeEventListener("pageshow", onVis); }
    function fail(msg) { done(); view(Object.assign({}, o, { msg:msg })); }
    function setTok(t) {
      cur = t; w.href = "https://t.me/" + BOT + "?start=" + o.prefix + t.tok; a.href = "tg://resolve?domain=" + BOT + "&start=" + o.prefix + t.tok;
      a.removeAttribute("aria-disabled"); a.style.opacity = "";
    }
    async function fresh() {
      try { setTok({ tok:await rpc(o.newFn), at:Date.now() }); }
      catch (e) { if (alive()) m.textContent = e.message; }
    }
    async function check() {
      if (!cur || !cur.sent || busy || !alive()) return;
      busy = true;
      try {
        var r = await rpc(o.checkFn, { p_token:cur.tok });
        if (!alive()) return;
        if (r.status === "ok") { done(); return o.onOk(r.session, r); }
        if (r.status === "expired" || Date.now() - cur.at > 30 * 60000) return fail("Вақт тугади. Қайта уриниб кўринг.");
      } catch (e) {} finally { busy = false; }
    }
    function onVis() { if (!document.hidden) check(); }
    a.onclick = w.onclick = function (e) {
      if (!cur) { e.preventDefault(); m.textContent = "Бир сония…"; return; }
      cur.sent = true; store(key, cur);
      if (TG && TG.initData && TG.openTelegramLink) { e.preventDefault(); try { TG.openTelegramLink(w.href); } catch (x) {} }
      m.textContent = "Telegram'да «Start» ни босинг, кейин шу иловага қайтинг — ўзи киради.";
    };
    document.addEventListener("visibilitychange", onVis); window.addEventListener("focus", onVis); window.addEventListener("pageshow", onVis);
    var saved = load(key);
    if (saved && saved.tok && Date.now() - saved.at < 30 * 60000) {        // олдинги уриниш давом этади (iOS илова қайта очилган бўлса ҳам)
      setTok(saved); cur.sent = true; m.textContent = o.msg || "Telegram'да «Start» ни босган бўлсангиз, ҳозир киради…"; check();
    } else { store(key, null); fresh(); }
    (function loop() {
      setTimeout(function () {
        if (!alive()) return;
        if (cur && !cur.sent && Date.now() - cur.at > 20 * 60000) fresh();   // эскирмасин
        check(); loop();
      }, 2000);
    })();
  }
  async function miniSession(action) {
    if (!TG || !TG.initData || !C.botApi) return null;
    try {
      var r = await fetch(C.botApi, { method:"POST", headers:{ "content-type":"application/json", "x-init-data":TG.initData }, body:JSON.stringify({ action:action }) });
      var j = await r.json().catch(function () { return {}; });
      return r.ok && j.session ? j.session : null;
    } catch (e) { return null; }
  }
  window.TGLOGIN = { view:view, miniSession:miniSession, bot:BOT };
})();
