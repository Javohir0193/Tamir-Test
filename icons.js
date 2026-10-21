// Ta'mir — иконкалар: iOS учун ингичка контурли (SF услубида), Android учун тўлдирилган (Material услубида).
// Ишлатиш: IC.i("map", 22) → <svg>…; IC.pin() → катта харита булавкаси; IC.marker("truck") → харита белгиси.
(function () {
  var ua = navigator.userAgent || "", ios = /iPhone|iPad|iPod/.test(ua) || (/Macintosh/.test(ua) && navigator.maxTouchPoints > 1);
  var P = {
    pin:    ['<path d="M12 21s-6.5-5.6-6.5-11a6.5 6.5 0 0 1 13 0c0 5.4-6.5 11-6.5 11z"/><circle cx="12" cy="10" r="2.4"/>', '<path fill-rule="evenodd" d="M12 22s-7-6.2-7-12a7 7 0 0 1 14 0c0 5.8-7 12-7 12zm0-9.2a2.8 2.8 0 1 0 0-5.6 2.8 2.8 0 0 0 0 5.6z"/>'],
    map:    ['<path d="M9 4 3.5 6v14L9 18l6 2 5.5-2V4L15 6zM9 4v14M15 6v14"/>', '<path d="M15 5.1 9 3 3.4 4.9a.5.5 0 0 0-.4.5v15a.5.5 0 0 0 .7.5L9 19l6 2 5.6-1.9a.5.5 0 0 0 .4-.5v-15a.5.5 0 0 0-.7-.5zM15 19l-6-2.1V5l6 2.1z"/>'],
    locate: ['<circle cx="12" cy="12" r="3.2"/><circle cx="12" cy="12" r="7.5"/><path d="M12 2.5v3M12 18.5v3M2.5 12h3M18.5 12h3"/>', '<path fill-rule="evenodd" d="M13 3.06V1h-2v2.06A9 9 0 0 0 3.06 11H1v2h2.06A9 9 0 0 0 11 20.94V23h2v-2.06A9 9 0 0 0 20.94 13H23v-2h-2.06A9 9 0 0 0 13 3.06zM12 19a7 7 0 1 1 0-14 7 7 0 0 1 0 14zm0-11a4 4 0 1 0 0 8 4 4 0 0 0 0-8z"/>'],
    truck:  ['<path d="M2.5 6.5h11v9h-11zM13.5 9.5h4l3 3v3h-7"/><circle cx="7" cy="17.5" r="1.8"/><circle cx="17" cy="17.5" r="1.8"/>', '<path d="M20 8h-3V4H3c-1.1 0-2 .9-2 2v11h2a3 3 0 0 0 6 0h6a3 3 0 0 0 6 0h2v-5zM6 18.5a1.5 1.5 0 1 1 0-3 1.5 1.5 0 0 1 0 3zm13.5-9 1.96 2.5H17V9.5zM18 18.5a1.5 1.5 0 1 1 0-3 1.5 1.5 0 0 1 0 3z"/>'],
    home:   ['<path d="M3.5 11 12 4l8.5 7M5.5 10v10h13V10"/><path d="M10 20v-5h4v5"/>', '<path d="M10 20v-6h4v6h5v-8h3L12 3 2 12h3v8z"/>'],
    box:    ['<path d="M4 8 12 4l8 4v8l-8 4-8-4z"/><path d="m4 8 8 4 8-4M12 12v8"/>', '<path d="M20.5 7.3 12 2.5 3.5 7.3v9.4l8.5 4.8 8.5-4.8zM12 4.6l5.9 3.3L12 11.2 6.1 7.9zM5.5 9.6l5.5 3.1v6.4l-5.5-3.1zm7.5 9.5v-6.4l5.5-3.1v6.4z"/>'],
    wallet: ['<path d="M4 7.5A2.5 2.5 0 0 1 6.5 5H18v3M4 7.5V17a2 2 0 0 0 2 2h13V8H6.5A2.5 2.5 0 0 1 4 7.5z"/><circle cx="15.5" cy="13.5" r="1"/>', '<path d="M21 7H5.5A1.5 1.5 0 0 1 4 5.5 1.5 1.5 0 0 1 5.5 4H19V2H5.5A3.5 3.5 0 0 0 2 5.5V19a2 2 0 0 0 2 2h17a1 1 0 0 0 1-1V8a1 1 0 0 0-1-1zm-3 8.5a1.5 1.5 0 1 1 0-3 1.5 1.5 0 0 1 0 3z"/>'],
    list:   ['<path d="M8 6.5h12M8 12h12M8 17.5h12"/><circle cx="4.5" cy="6.5" r=".8"/><circle cx="4.5" cy="12" r=".8"/><circle cx="4.5" cy="17.5" r=".8"/>', '<path d="M3 5h2v2H3zm4 0h14v2H7zM3 11h2v2H3zm4 0h14v2H7zM3 17h2v2H3zm4 0h14v2H7z"/>'],
    check:  ['<circle cx="12" cy="12" r="9"/><path d="m8 12.3 2.7 2.7L16 9.5"/>', '<path d="M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20zm-2 15-5-5 1.4-1.4L10 14.2l7.6-7.6L19 8z"/>'],
    nav:    ['<path d="M20 4 4 10.5l6.5 2.5 2.5 6.5z"/>', '<path d="M21 3 3 10.5l7 2.5 2.5 7z"/>']
  };
  var IC = {
    ios: ios,
    i: function (n, s) {
      var d = P[n]; if (!d) return ""; s = s || 20;
      return ios ? '<svg class="ic" viewBox="0 0 24 24" width="' + s + '" height="' + s + '" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" style="vertical-align:-4px">' + d[0] + '</svg>'
                 : '<svg class="ic" viewBox="0 0 24 24" width="' + s + '" height="' + s + '" fill="currentColor" aria-hidden="true" style="vertical-align:-4px">' + d[1] + '</svg>';
    },
    // Харита маркази булавкаси (тагидаги учи — аниқ нуқта)
    pin: function () {
      var id = "pg" + Math.floor(Math.random() * 1e6);
      return ios
        ? '<svg viewBox="0 0 44 60" width="44" height="60" aria-hidden="true"><defs><linearGradient id="' + id + '" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FF6B5E"/><stop offset="1" stop-color="#D92D20"/></linearGradient></defs>' +
          '<ellipse cx="22" cy="57" rx="7" ry="2.4" fill="rgba(0,0,0,.28)"/><path d="M22 56C22 56 4 37.5 4 22a18 18 0 0 1 36 0c0 15.5-18 34-18 34z" fill="url(#' + id + ')" stroke="rgba(255,255,255,.9)" stroke-width="2"/>' +
          '<circle cx="22" cy="22" r="7" fill="#fff"/><circle cx="22" cy="22" r="3" fill="#D92D20"/></svg>'
        : '<svg viewBox="0 0 44 60" width="44" height="60" aria-hidden="true"><ellipse cx="22" cy="57" rx="7" ry="2.4" fill="rgba(0,0,0,.25)"/>' +
          '<path d="M22 56C22 56 4 37.5 4 22a18 18 0 0 1 36 0c0 15.5-18 34-18 34z" fill="#EA4335"/><circle cx="22" cy="22" r="7.5" fill="#B31412"/><circle cx="22" cy="22" r="3.4" fill="#fff"/></svg>';
    },
    // Харита маркери (юмалоқ белги)
    marker: function (n) {
      var inner = n === "A" || n === "B" ? '<b style="font:800 15px/1 system-ui">' + n + '</b>' : IC.i(n, 20);
      var bg = n === "truck" ? "#1B1F24" : n === "home" ? "#2563EB" : "#FFD92F", fg = n === "A" || n === "B" ? "#1B1F24" : "#fff";
      return '<div style="width:34px;height:34px;border-radius:50%;background:' + bg + ';color:' + fg + ';display:grid;place-items:center;border:2.5px solid #fff;box-shadow:0 2px 6px rgba(0,0,0,.35);margin:3px">' + inner + '</div>';
    }
  };
  window.IC = IC;
  // Булавка суриш пайтида кўтарилади
  document.addEventListener("pointerdown", function (e) { var m = e.target.closest && e.target.closest(".pick-mw"); if (m) { var p = m.querySelector(".pin"); if (p) p.classList.add("up"); } }, true);
  document.addEventListener("pointerup", function () { var p = document.querySelector(".pin.up"); if (p) p.classList.remove("up"); }, true);
  document.addEventListener("pointercancel", function () { var p = document.querySelector(".pin.up"); if (p) p.classList.remove("up"); }, true);
  var st = document.createElement("style");
  st.textContent = ".pin{font-size:0!important;transition:transform .15s ease;transform-origin:50% 100%}.pin.up{transform:translate(-50%,-100%) translateY(-10px)}.pin svg{display:block;filter:drop-shadow(0 3px 3px rgba(0,0,0,.25))}";
  document.head.appendChild(st);
})();
