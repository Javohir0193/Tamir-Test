// Ta'mir: тепада пастга тортиб янгилаш. Фақат transform ишлатилади (GPU), шунинг учун силлиқ.
(function () {
  "use strict";
  var TH = 78, MAXV = 120, y0 = null, dy = 0, busy = false, bg, ring, els = [], SA = 0, raf = 0, cur = 0, band = null;
  var css = "html,body{overscroll-behavior-y:none}" +
    "#pullBg{position:fixed;left:0;right:0;top:0;height:260px;z-index:50;pointer-events:none;opacity:0;will-change:transform;transform:translate3d(0,-260px,0);background:linear-gradient(180deg,#FFB36B 0%,#FB923C 55%,#F97316 100%)}" +
    "#pullEl{position:fixed;left:50%;top:0;width:44px;height:44px;margin-left:-22px;z-index:51;pointer-events:none;opacity:0;will-change:transform,opacity;transform:translate3d(0,-60px,0) scale(.5)}" +
    "#pullEl i{width:44px;height:44px;border-radius:50%;background:#fff;box-shadow:0 4px 14px rgba(0,0,0,.2);display:grid;place-items:center}" +
    "#pullEl svg{width:24px;height:24px;color:#F97316;display:block}" +
    "#pullEl.spin svg{animation:pullspin .75s linear infinite}@keyframes pullspin{to{transform:rotate(360deg)}}" +
    ".pulling{--pe:none}";
  var EASE = "cubic-bezier(.22,.9,.3,1)";
  function measure() { var d = document.createElement("div"); d.style.cssText = "position:fixed;top:0;height:env(safe-area-inset-top,0px);visibility:hidden"; document.body.appendChild(d); SA = d.offsetHeight; d.remove(); }
  function blocked(t) {
    for (var n = t; n && n.nodeType === 1 && n !== document.body; n = n.parentElement) {
      if (/^(INPUT|TEXTAREA|SELECT)$/.test(n.tagName) || (n.classList && (n.classList.contains("dmap") || n.classList.contains("leaflet-container"))) || n.hasAttribute("data-nopull")) return true;
      var cs = getComputedStyle(n); if (/(auto|scroll)/.test(cs.overflowY) && n.scrollHeight > n.clientHeight && n.scrollTop > 0) return true;
    }
    return false;
  }
  function collect() { els = [].slice.call(document.querySelectorAll("body > header, body > main, body > footer, body > #app, body > .wrap")); }
  function setTr(on) {
    var t = on ? "transform .4s " + EASE : "none";
    els.forEach(function (e) { e.style.transition = t; });
    bg.style.transition = on ? "transform .4s " + EASE + ", opacity .3s" : "none";
    ring.style.transition = on ? "transform .4s " + EASE + ", opacity .3s" : "none";
  }
  function apply(v, spin) {
    v = Math.round(v); cur = v;
    var p = Math.min(1, v / TH);
    els.forEach(function (e) { e.style.transform = v ? "translate3d(0," + v + "px,0)" : ""; });
    bg.style.transform = "translate3d(0," + (v ? (SA + v - 257) : -260) + "px,0)";
    bg.style.opacity = v ? "1" : "0";
    var ry = SA + Math.max(2, (v - 44) / 2 + 2);
    ring.style.opacity = v ? String(Math.min(1, p * 1.6)) : "0";
    ring.style.transform = "translate3d(0," + (v ? ry : -60) + "px,0) scale(" + (0.5 + 0.5 * p) + ") rotate(" + (spin ? 0 : v * 6) + "deg)";
    if (band) band.style.opacity = v ? "0" : "1";
  }
  function frame(v) { if (raf) cancelAnimationFrame(raf); raf = requestAnimationFrame(function () { raf = 0; apply(v); }); }
  function start(e) {
    if (busy) return;
    if ((window.scrollY || 0) > 0 || blocked(e.target) || document.querySelector(".pick,.sheet,#sheet")) { y0 = null; return; }
    collect(); y0 = e.touches[0].clientY; dy = 0; setTr(false);
  }
  function move(e) {
    if (y0 === null || busy) return;
    var d = e.touches[0].clientY - y0;
    if (d <= 0) { if (dy) { dy = 0; frame(0); } return; }
    if ((window.scrollY || 0) > 0) { y0 = null; setTr(true); apply(0); return; }
    if (e.cancelable && d > 4) e.preventDefault();
    dy = MAXV * (1 - Math.exp(-d / 170));          // табиий қаршилик (резина)
    frame(dy);
  }
  function end() {
    if (y0 === null || busy) { y0 = null; return; }
    y0 = null;
    if (raf) { cancelAnimationFrame(raf); raf = 0; }
    if (dy >= TH * 0.85) {
      busy = true; setTr(true); ring.classList.add("spin"); apply(TH * 0.8, true); ring.style.opacity = "1"; ring.style.transform = "translate3d(0," + (SA + TH * 0.8 / 2 - 20) + "px,0) scale(1)";
      var done = function () {
        setTimeout(function () {
          ring.style.opacity = "0"; ring.style.transform = "translate3d(0," + (SA + TH * 0.8 / 2 - 20) + "px,0) scale(.4)";
          setTimeout(function () { setTr(true); apply(0); setTimeout(function () { ring.classList.remove("spin"); busy = false; dy = 0; els.forEach(function (e) { e.style.transition = ""; }); }, 420); }, 220);
        }, 300);
      };
      try { var r = (window.__pull || function () { location.reload(); })(); if (r && r.then) r.then(done, done); else done(); } catch (e) { done(); }
    } else { setTr(true); apply(0); dy = 0; setTimeout(function () { els.forEach(function (e) { e.style.transition = ""; }); }, 420); }
  }
  function init() {
    var st = document.createElement("style"); st.textContent = css; document.head.appendChild(st);
    bg = document.createElement("div"); bg.id = "pullBg"; document.body.appendChild(bg);
    ring = document.createElement("div"); ring.id = "pullEl";
    ring.innerHTML = '<i><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><path d="M20 12a8 8 0 1 1-2.4-5.7"/><path d="M20 4v5h-5"/></svg></i>';
    document.body.appendChild(ring);
    band = document.getElementById("sabar");
    measure();
    window.addEventListener("resize", measure);
    window.addEventListener("load", function () { band = document.getElementById("sabar"); });
    document.addEventListener("touchstart", start, { passive: true });
    document.addEventListener("touchmove", move, { passive: false });
    document.addEventListener("touchend", end, { passive: true });
    document.addEventListener("touchcancel", end, { passive: true });
  }
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", init); else init();
})();
