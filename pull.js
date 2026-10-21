// Ta'mir: тепада пастга тортиб янгилаш (pull-to-refresh) — тўқ сариқ ҳалқа эффекти.
(function () {
  "use strict";
  var TH = 72, y0 = null, dy = 0, busy = false, el, ring, main;
  var css = "html,body{overscroll-behavior-y:none}" +
    "#pullEl{position:fixed;left:50%;top:calc(env(safe-area-inset-top,0px) + 8px);width:44px;height:44px;margin-left:-22px;z-index:48;pointer-events:none;opacity:0;transform:translateY(-70px) scale(.6)}" +
    "#pullEl i{display:block;width:44px;height:44px;border-radius:50%;background:#fff;box-shadow:0 4px 14px rgba(0,0,0,.25);display:grid;place-items:center}" +
    "#pullEl svg{width:24px;height:24px;color:#F97316}" +
    "#pullEl.spin svg{animation:pullspin .8s linear infinite}@keyframes pullspin{to{transform:rotate(360deg)}}" +
    "#pullEl.back{transition:transform .35s cubic-bezier(.2,.9,.3,1.2),opacity .3s}";
  function start(e) { if (busy) return; if ((window.scrollY || 0) > 0 || document.querySelector(".pick,.sheet,#sheet")) { y0 = null; return; } y0 = e.touches[0].clientY; dy = 0; }
  function move(e) {
    if (y0 === null || busy) return;
    var d = e.touches[0].clientY - y0;
    if (d <= 0) { dy = 0; paint(0); return; }
    if ((window.scrollY || 0) > 0) { y0 = null; paint(0); return; }
    dy = Math.min(d * 0.55, 120);
    if (e.cancelable && d > 6) e.preventDefault();
    paint(dy);
  }
  function paint(v) {
    var p = Math.min(1, v / TH);
    el.classList.remove("back");
    el.style.opacity = p ? String(Math.min(1, p * 1.4)) : "0";
    el.style.transform = "translateY(" + (-70 + v * 1.1) + "px) scale(" + (0.6 + 0.4 * p) + ") rotate(" + (v * 4) + "deg)";
    if (main) main.style.transform = v ? "translateY(" + v * 0.5 + "px)" : "";
  }
  function end() {
    if (y0 === null || busy) { y0 = null; return; }
    y0 = null;
    if (dy >= TH * 0.9) {
      busy = true; el.classList.add("back", "spin");
      el.style.opacity = "1"; el.style.transform = "translateY(" + (TH * 0.7) + "px) scale(1)";
      if (main) { main.style.transition = "transform .3s"; main.style.transform = "translateY(" + TH * 0.45 + "px)"; }
      var done = function () { setTimeout(reset, 450); };
      try { var r = (window.__pull || function () { location.reload(); })(); if (r && r.then) r.then(done, done); else done(); } catch (e) { done(); }
    } else reset();
  }
  function reset() {
    el.classList.add("back"); el.classList.remove("spin"); el.style.opacity = "0"; el.style.transform = "translateY(-70px) scale(.6)";
    if (main) { main.style.transition = "transform .3s"; main.style.transform = ""; setTimeout(function () { if (main) main.style.transition = ""; }, 320); }
    dy = 0; busy = false;
  }
  function init() {
    var st = document.createElement("style"); st.textContent = css; document.head.appendChild(st);
    el = document.createElement("div"); el.id = "pullEl";
    el.innerHTML = '<i><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><path d="M20 12a8 8 0 1 1-2.4-5.7"/><path d="M20 4v5h-5"/></svg></i>';
    document.body.appendChild(el);
    main = document.querySelector("main") || document.getElementById("app");
    document.addEventListener("touchstart", start, { passive: true });
    document.addEventListener("touchmove", move, { passive: false });
    document.addEventListener("touchend", end, { passive: true });
    document.addEventListener("touchcancel", end, { passive: true });
  }
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", init); else init();
})();
