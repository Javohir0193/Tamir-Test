// Ta'mir: тепадаги панел пастга скролда силлиқ яширилади, юқорига скролда қайта чиқади.
(function () {
  "use strict";
  var h, last = 0, hid = false, tick = false;
  function set(v) { if (v === hid || !h) return; hid = v; h.classList.toggle("hh-hide", v); }
  function onScroll() {
    if (tick) return; tick = true;
    requestAnimationFrame(function () {
      var y = Math.max(0, window.scrollY || 0), dy = y - last;
      var a = document.activeElement;
      if (y < 70) set(false);
      else if (a && h.contains(a) && /INPUT|TEXTAREA/.test(a.tagName)) set(false);
      else if (dy > 8) set(true);
      else if (dy < -8) set(false);
      if (Math.abs(dy) > 8 || y < 70) last = y;
      tick = false;
    });
  }
  function init() {
    h = document.querySelector("header"); if (!h) return;
    var st = document.createElement("style");
    st.textContent = "header{transition:transform .3s cubic-bezier(.2,.8,.2,1),box-shadow .3s;will-change:transform}header.hh-hide{transform:translateY(-115%);box-shadow:none!important}" +
      "";
    document.head.appendChild(st);
    var bd = document.createElement("div"); bd.id = "sabar"; bd.style.cssText = "position:fixed;left:0;right:0;top:0;height:env(safe-area-inset-top,0px);background:#F97316;z-index:49;pointer-events:none;transition:opacity .2s"; document.body.appendChild(bd);
    window.addEventListener("scroll", onScroll, { passive: true });
  }
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", init); else init();
})();
