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
  function openBot(url) {
    if (TG && TG.initData && TG.openTelegramLink) { try { TG.openTelegramLink(url); return; } catch (e) {} }
    if (!window.open(url, "_blank")) location.href = url;
  }
  function view(o) {
    var run = ++RUN, el = typeof o.el === "string" ? document.getElementById(o.el) : o.el;
    el.innerHTML = '<div class="' + (o.wrap || "center") + '"><h1>' + esc(o.title) + '</h1><p class="' + (o.mu || "mu") + '">' + esc(o.text || "Telegram ботдаги аккаунтингиз орқали киринг.") + '</p>' +
      '<button class="' + (o.btn || "btn") + '" id="tglb" style="width:100%;max-width:320px">Telegram орқали кириш</button><p class="' + (o.mu || "mu") + '" id="tglm" aria-live="polite">' + esc(o.msg || "") + '</p></div>';
    var btn = document.getElementById("tglb"), m = document.getElementById("tglm");
    btn.onclick = async function () {
      btn.disabled = true;
      try {
        var tok = await rpc(o.newFn);
        openBot("https://t.me/" + BOT + "?start=" + o.prefix + tok);
        m.textContent = "Telegram очилди: «Start» ни босиб, шу ерга қайтинг…";
        for (var i = 0; i < 150; i++) {
          await new Promise(function (r) { setTimeout(r, 2000); });
          if (run !== RUN) return;                       // бошқа ойна очилди
          var r = await rpc(o.checkFn, { p_token:tok });
          if (r.status === "ok") return o.onOk(r.session, r);
          if (r.status === "expired") break;
        }
        view(Object.assign({}, o, { msg:"Вақт тугади. Қайта уриниб кўринг." }));
      } catch (e) { view(Object.assign({}, o, { msg:e.message })); }
    };
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
