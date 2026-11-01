// Ta'mir — телефонга билдиришнома (Web Push): телефон блокда бўлса ҳам экранга чиқади. 5 та иловада битта код.
// Ишлатиш (саҳифада):
//   TamirPush.init({ app:"driver", base:"uz", token:() => SES, lang:() => LG.lang(), tr:s => LG.tr(s) });
//   шаблонда: ${TamirPush.btn("btn alt")}   — тугма; ҳолати ўзи янгиланади, босилганда ёқади/ўчиради.
//   rpc берилмаса, Supabase REST (publishable калит) орқали чақирилади; мижоз ва админ саҳифалари ўз sb.rpc'ини беради.
// Бот (tg-bot) Telegram'га хабар юборганда шу одамнинг телефонига push ҳам юборади. Калит: push_key(), обуна: push_subscribe (27-миграция).
// Чекловлар: Telegram ичида push йўқ (тугма кўринмайди). iPhone: фақат iOS 16.4+ ва сайт «Бош экранга қўшилган» бўлса.
(function () {
  "use strict";
  var C = window.TAMIR_CONFIG || {};
  var T = {
    uz: { on: "🔔 Билдиришнома ёқилган", off: "🔔 Билдиришномани ёқиш", denied: "🔕 Билдиришномага рухсат йўқ", ios: "🔔 Билдиришнома", busy: "⏳ Ёқилмоқда…",
      iosHelp: "iPhone'да билдиришнома фақат сайт бош экранга қўшилганда ишлайди (iOS 16.4 ёки янгиси): Safari → «Улашиш» → «На экран Домой». Кейин шу белгидан очиб, тугмани қайта босинг.",
      deniedHelp: "Телефон бу сайтга билдиришнома юборишга рухсат бермаган. Браузер ёки телефон созламаларида шу сайт учун «Билдиришномалар»ни ёқинг ва қайта уриниб кўринг.",
      ok: "✅ Билдиришнома ёқилди. Телефон блокда бўлса ҳам хабар келади.", offAsk: "Шу телефонда билдиришномани ўчирайми?", offOk: "Билдиришнома ўчирилди.",
      nokey: "Билдиришнома ҳали созланмаган. Бир дақиқадан кейин қайта уриниб кўринг.", fail: "Билдиришномани ёқиб бўлмади: " },
    ru: { on: "🔔 Уведомления включены", off: "🔔 Включить уведомления", denied: "🔕 Уведомления запрещены", ios: "🔔 Уведомления", busy: "⏳ Включаем…",
      iosHelp: "На iPhone уведомления работают, только если сайт добавлен на экран «Домой» (iOS 16.4 или новее): Safari → «Поделиться» → «На экран Домой». Потом откройте сайт с этого значка и нажмите кнопку ещё раз.",
      deniedHelp: "Телефон запретил этому сайту присылать уведомления. Включите «Уведомления» для этого сайта в настройках браузера или телефона и попробуйте снова.",
      ok: "✅ Уведомления включены. Будут приходить, даже когда телефон заблокирован.", offAsk: "Выключить уведомления на этом телефоне?", offOk: "Уведомления выключены.",
      nokey: "Уведомления ещё не настроены. Попробуйте через минуту.", fail: "Не удалось включить уведомления: " }
  };
  var O = null, ST = "off", BUSY = false;

  function inTg() { try { return !!(window.Telegram && Telegram.WebApp && Telegram.WebApp.initData); } catch (e) { return false; } }
  function isIos() { return /iP(hone|ad|od)/.test(navigator.userAgent) || (navigator.platform === "MacIntel" && navigator.maxTouchPoints > 1); }
  function canPush() { return "serviceWorker" in navigator && "PushManager" in window && "Notification" in window && window.isSecureContext && !inTg(); }
  function txt(k) { return T[O && O.base === "ru" ? "ru" : "uz"][k]; }          // саҳифанинг асосий тилида; таржимани саҳифа луғати қилади
  function say(k, extra) { var s = txt(k) + (extra || ""); try { alert(O && O.tr ? O.tr(s) : s); } catch (e) {} }
  function flagKey() { return "push_" + O.app; }
  function getFlag() { try { return localStorage.getItem(flagKey()) === "1"; } catch (e) { return false; } }
  function setFlag(v) { try { if (v) localStorage.setItem(flagKey(), "1"); else localStorage.removeItem(flagKey()); } catch (e) {} }
  function b64ToBytes(s) {
    s = s.replace(/-/g, "+").replace(/_/g, "/"); while (s.length % 4) s += "=";
    var r = atob(s), a = new Uint8Array(r.length); for (var i = 0; i < r.length; i++) a[i] = r.charCodeAt(i); return a;
  }
  function bytesToB64(buf) {
    var b = new Uint8Array(buf), s = ""; for (var i = 0; i < b.length; i++) s += String.fromCharCode(b[i]);
    return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
  }
  function restRpc(fn, args) {
    return fetch(C.supabaseUrl + "/rest/v1/rpc/" + fn, { method: "POST", headers: { apikey: C.supabaseKey, Authorization: "Bearer " + C.supabaseKey, "content-type": "application/json" }, body: JSON.stringify(args || {}) })
      .then(function (r) { return r.json().catch(function () { return null; }).then(function (j) { if (!r.ok) throw new Error((j && (j.message || j.hint)) || "HTTP " + r.status); return j; }); });
  }
  function call(fn, args) { return (O.rpc || restRpc)(fn, args); }
  function swReg() { return navigator.serviceWorker.register("sw.js").then(function () { return navigator.serviceWorker.ready; }); }
  function sameKey(sub, key) {
    try { var k = sub.options && sub.options.applicationServerKey; return !k || bytesToB64(k) === key; } catch (e) { return true; }
  }
  // обунани базага ёзиш (ҳар очилганда ҳам: сессия, тил ва телефон манзили янгиланиб туради)
  function save(sub) {
    var j = sub.toJSON();
    return call("push_subscribe", { p_app: O.app, p_token: O.token ? (O.token() || null) : null, p_endpoint: j.endpoint, p_p256dh: j.keys.p256dh, p_auth: j.keys.auth, p_lang: O.lang ? O.lang() : O.base });
  }
  function state() {
    if (!canPush()) return inTg() ? "none" : isIos() ? "ios" : "none";
    if (Notification.permission === "denied") return "denied";
    return getFlag() && Notification.permission === "granted" ? "on" : "off";
  }
  function paint() {
    ST = state();
    var els = document.querySelectorAll("[data-push]");
    for (var i = 0; i < els.length; i++) { els[i].hidden = ST === "none"; els[i].textContent = BUSY ? txt("busy") : txt(ST === "none" ? "off" : ST); }
  }
  function enable() {
    BUSY = true; paint();
    var key;
    return Notification.requestPermission()
      .then(function (p) { if (p !== "granted") throw new Error("denied"); return call("push_key", {}); })
      .then(function (k) { if (!k) throw new Error("nokey"); key = k; return swReg(); })
      .then(function (reg) {
        return reg.pushManager.getSubscription().then(function (sub) {
          if (sub && !sameKey(sub, key)) return sub.unsubscribe().then(function () { return null; });
          return sub;
        }).then(function (sub) { return sub || reg.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey: b64ToBytes(key) }); });
      })
      .then(save)
      .then(function () { setFlag(true); BUSY = false; paint(); say("ok"); })
      .catch(function (e) {
        BUSY = false; paint();
        var m = (e && e.message) || String(e);
        if (m === "denied") say("deniedHelp"); else if (m === "nokey") say("nokey"); else say("fail", m);
      });
  }
  function disable() {
    var ask = txt("offAsk"); if (!confirm(O.tr ? O.tr(ask) : ask)) return Promise.resolve();
    BUSY = true; paint();
    // браузердаги обуна қолади (шу телефонда бошқа Ta'mir иловаси ҳам ишлатиши мумкин) — фақат шу илова учун ёзув ўчади
    return navigator.serviceWorker.getRegistration().then(function (reg) { return reg && reg.pushManager.getSubscription(); })
      .then(function (sub) { return sub ? call("push_unsubscribe", { p_app: O.app, p_endpoint: sub.endpoint }) : null; })
      .catch(function () {})
      .then(function () { setFlag(false); BUSY = false; paint(); say("offOk"); });
  }
  function onClick(e) {
    var b = e.target && e.target.closest && e.target.closest("[data-push]"); if (!b || BUSY || !O) return;
    e.preventDefault(); e.stopPropagation();
    if (ST === "ios") return say("iosHelp");
    if (ST === "denied") return say("deniedHelp");
    if (ST === "on") return disable();
    return enable();
  }
  // илова очилганда: ёқилган бўлса обунани жимгина янгилаш (сессия алмашган ёки браузер манзилни ўзгартирган бўлиши мумкин)
  function refresh() {
    if (!O || state() !== "on") return;
    swReg().then(function (reg) { return reg.pushManager.getSubscription(); })
      .then(function (sub) { if (!sub) { setFlag(false); paint(); return; } return save(sub); })
      .catch(function () {});
  }
  window.TamirPush = {
    init: function (o) {
      var first = !O; O = o || {}; O.base = O.base === "ru" ? "ru" : "uz";
      if (first) {
        document.addEventListener("click", onClick, true);
        new MutationObserver(function () { var els = document.querySelectorAll("[data-push]:not([data-push-p])"); for (var i = 0; i < els.length; i++) els[i].setAttribute("data-push-p", "1"); if (els.length) paint(); })
          .observe(document.documentElement, { childList: true, subtree: true });
        window.addEventListener("langchange", paint);
      }
      paint(); refresh();
    },
    refresh: refresh,
    btn: function (cls, style) {
      if (!O || state() === "none") return "";
      return '<button type="button" class="' + (cls || "btn alt") + '" data-push' + (style ? ' style="' + style + '"' : "") + ">" + txt(state()) + "</button>";
    },
    state: state
  };
})();
