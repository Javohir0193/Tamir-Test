// Ta'mir: янги буюртма овози + тебраниш, «овозсиз» тугмаси (ҳолат сақланади). window.SND.play()
(function () {
  "use strict";
  var KEY = "snd_off", off = false, ctx = null;
  try { off = localStorage.getItem(KEY) === "1"; } catch (e) {}
  function unlock() { try { if (!ctx) ctx = new (window.AudioContext || window.webkitAudioContext)(); if (ctx.state === "suspended") ctx.resume(); } catch (e) {} }
  ["touchstart", "click", "keydown"].forEach(function (ev) { document.addEventListener(ev, unlock, { passive: true }); });
  function tone(t, f, d) {
    var o = ctx.createOscillator(), g = ctx.createGain(); o.type = "sine"; o.frequency.value = f; o.connect(g); g.connect(ctx.destination);
    g.gain.setValueAtTime(0.0001, t); g.gain.exponentialRampToValueAtTime(0.28, t + 0.02); g.gain.exponentialRampToValueAtTime(0.0001, t + d); o.start(t); o.stop(t + d + 0.02);
  }
  function play() {
    if (off) return;
    try { navigator.vibrate && navigator.vibrate([250, 120, 250, 120, 250]); } catch (e) {}
    try { unlock(); if (ctx) { var t = ctx.currentTime; tone(t, 880, 0.22); tone(t + 0.28, 1175, 0.22); tone(t + 0.56, 880, 0.3); } } catch (e) {}
  }
  var BELL = '<svg viewBox="0 0 24 24" width="18" height="18" fill="currentColor"><path d="M12 22a2.2 2.2 0 0 0 2.2-2.2h-4.4A2.2 2.2 0 0 0 12 22zm7-6.2V11a7 7 0 0 0-5.5-6.8V3.5a1.5 1.5 0 0 0-3 0v.7A7 7 0 0 0 5 11v4.8l-1.7 1.7V19h17.4v-1.5z"/></svg>';
  var MUTE = '<svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M6.5 17H19l-1.7-1.8V11a5.3 5.3 0 0 0-1.3-3.5M9 5.6A5.3 5.3 0 0 0 6.7 11v4.2L5 17"/><path d="M10 20a2 2 0 0 0 4 0M3 3l18 18"/></svg>';
  function paint(b) { b.innerHTML = off ? MUTE : BELL; b.style.opacity = off ? ".75" : "1"; b.setAttribute("aria-label", off ? "Овоз ўчиқ" : "Овоз ёқиқ"); b.title = off ? "Овоз ўчиқ" : "Овоз ёқиқ"; }
  function init() {
    var b = document.createElement("button");
    b.id = "sndBtn"; b.type = "button";
    b.style.cssText = "position:fixed;right:66px;top:calc(8px + env(safe-area-inset-top,0px));z-index:60;width:36px;height:32px;display:grid;place-items:center;border:0;border-radius:16px;background:rgba(255,255,255,.95);color:#1B1F24;box-shadow:0 1px 4px rgba(0,0,0,.18);padding:0";
    paint(b);
    b.addEventListener("click", function () {
      off = !off; try { localStorage.setItem(KEY, off ? "1" : "0"); } catch (e) {} paint(b);
      if (!off) { unlock(); play(); }
      var t = document.getElementById("toast"); if (t) { t.textContent = off ? "Овоз ўчирилди" : "Овоз ёқилди"; t.classList.add("show"); setTimeout(function () { t.classList.remove("show"); }, 1400); }
    });
    document.body.appendChild(b);
  }
  // Янги буюртма бор экан, қўнғироқ тугмаси ёниб-ўчиб туради
  function alert(on) {
    var b = document.getElementById("sndBtn"); if (!b) return;
    if (!document.getElementById("sndCss")) {
      var st = document.createElement("style"); st.id = "sndCss";
      st.textContent = "@keyframes sndGlow{0%,100%{box-shadow:0 0 0 0 rgba(255,255,255,.9),0 0 0 0 rgba(255,214,102,.8)}50%{box-shadow:0 0 0 5px rgba(255,255,255,.35),0 0 14px 6px rgba(255,214,102,.95)}}@keyframes sndSwing{0%,100%{transform:rotate(0)}20%{transform:rotate(14deg)}40%{transform:rotate(-12deg)}60%{transform:rotate(8deg)}80%{transform:rotate(-6deg)}}#sndBtn.snd-alert{animation:sndGlow 1.2s ease-in-out infinite;background:#FFE08A!important}#sndBtn.snd-alert svg{animation:sndSwing 1.2s ease-in-out infinite;transform-origin:50% 10%}";
      document.head.appendChild(st);
    }
    b.classList.toggle("snd-alert", !!on);
  }
  window.SND = { play: play, alert: alert, isOff: function () { return off; } };
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", init); else init();
})();
