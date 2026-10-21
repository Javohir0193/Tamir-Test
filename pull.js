// Ta'mir: тепада пастга тортиб янгилаш — тепа градиентга айланади, ўртада ҳалқа чиқиб, силлиқ йўқолади.
(function () {
  "use strict";
  var TH = 80, y0 = null, dy = 0, busy = false, bg, ring, els = [];
  var css = "html,body{overscroll-behavior-y:none}" +
    "#pullBg{position:fixed;left:0;right:0;top:0;height:0;z-index:4;pointer-events:none;background:linear-gradient(180deg,#FDBA74 0%,#FB923C 45%,#F97316 100%)}" +
    "#pullEl{position:fixed;left:50%;top:0;width:44px;height:44px;margin-left:-22px;z-index:50;pointer-events:none;opacity:0}" +
    "#pullEl i{width:44px;height:44px;border-radius:50%;background:#fff;box-shadow:0 4px 14px rgba(0,0,0,.22);display:grid;place-items:center}" +
    "#pullEl svg{width:24px;height:24px;color:#F97316}" +
    "#pullEl.spin svg{animation:pullspin .8s linear infinite}@keyframes pullspin{to{transform:rotate(360deg)}}";
  function safe() { var d = document.createElement("div"); d.style.cssText = "position:fixed;top:0;height:env(safe-area-inset-top,0px);visibility:hidden"; document.body.appendChild(d); var h = d.offsetHeight; d.remove(); return h; }
  function blocked(t) {
    for (var n = t; n && n.nodeType === 1 && n !== document.body; n = n.parentElement) {
      if (/^(INPUT|TEXTAREA|SELECT)$/.test(n.tagName) || (n.classList && (n.classList.contains("dmap") || n.classList.contains("leaflet-container"))) || n.hasAttribute("data-nopull")) return true;
      var cs = getComputedStyle(n); if (/(auto|scroll)/.test(cs.overflowY) && n.scrollHeight > n.clientHeight && n.scrollTop > 0) return true;
    }
    return false;
  }
  function collect() { els = [].slice.call(document.querySelectorAll("body > header, body > main, body > footer, body > #app, body > .wrap")); }
  function shift(v, anim) {
    var sa = safe(), t = anim ? "transform .38s cubic-bezier(.2,.8,.2,1)" : "none";
    els.forEach(function (e) { e.style.transition = anim ? t : "none"; e.style.transform = v ? "translateY(" + v + "px)" : ""; });
    bg.style.transition = anim ? "height .38s cubic-bezier(.2,.8,.2,1)" : "none";
    bg.style.height = v ? (sa + v) + "px" : "0px";
    ring.style.transition = anim ? "opacity .3s, transform .38s cubic-bezier(.2,.8,.2,1)" : "none";
    var p = Math.min(1, v / TH);
    ring.style.top = (sa + Math.max(0, v / 2 - 22)) + "px";
    ring.style.opacity = v ? String(Math.min(1, p * 1.5)) : "0";
    ring.style.transform = "scale(" + (0.5 + 0.5 * p) + ") rotate(" + (anim ? 0 : v * 5) + "deg)";
    if (anim) setTimeout(function () { els.forEach(function (e) { if (!e.style.transform) e.style.transition = ""; }); }, 420);
  }
  function start(e) { if (busy) return; if ((window.scrollY || 0) > 0 || blocked(e.target) || document.querySelector(".pick,.sheet,#sheet")) { y0 = null; return; } collect(); y0 = e.touches[0].clientY; dy = 0; }
  function move(e) {
    if (y0 === null || busy) return;
    var d = e.touches[0].clientY - y0;
    if (d <= 0) { dy = 0; shift(0, false); return; }
    if ((window.scrollY || 0) > 0) { y0 = null; shift(0, true); return; }
    dy = Math.min(d * 0.5, 110);
    if (e.cancelable && d > 6) e.preventDefault();
    shift(dy, false);
  }
  function end() {
    if (y0 === null || busy) { y0 = null; return; }
    y0 = null;
    if (dy >= TH * 0.9) {
      busy = true; ring.classList.add("spin"); shift(TH * 0.75, true); ring.style.opacity = "1"; ring.style.transform = "scale(1)";
      var done = function () { setTimeout(function () { ring.style.transition = "opacity .35s, transform .35s"; ring.style.opacity = "0"; ring.style.transform = "scale(.4)"; setTimeout(function () { shift(0, true); ring.classList.remove("spin"); busy = false; dy = 0; }, 180); }, 350); };
      try { var r = (window.__pull || function () { location.reload(); })(); if (r && r.then) r.then(done, done); else done(); } catch (e) { done(); }
    } else { shift(0, true); dy = 0; }
  }
  function init() {
    var st = document.createElement("style"); st.textContent = css; document.head.appendChild(st);
    bg = document.createElement("div"); bg.id = "pullBg"; document.body.appendChild(bg);
    ring = document.createElement("div"); ring.id = "pullEl";
    ring.innerHTML = '<i><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><path d="M20 12a8 8 0 1 1-2.4-5.7"/><path d="M20 4v5h-5"/></svg></i>';
    document.body.appendChild(ring);
    document.addEventListener("touchstart", start, { passive: true });
    document.addEventListener("touchmove", move, { passive: false });
    document.addEventListener("touchend", end, { passive: true });
    document.addEventListener("touchcancel", end, { passive: true });
  }
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", init); else init();
})();
