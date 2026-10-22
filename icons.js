// Ta'mir — иконкалар: iOS учун ингичка контурли (SF услубида), Android учун тўлдирилган (Material услубида).
// Ишлатиш: IC.i("map", 22) → <svg>…; IC.pin() → катта харита булавкаси; IC.marker("truck") → харита белгиси.
(function () {
  var ua = navigator.userAgent || "", ios = /iPhone|iPad|iPod/.test(ua) || (/Macintosh/.test(ua) && navigator.maxTouchPoints > 1);
  // window.IC_STYLE = "line" (харидор иловаси) → ҳамма жойда дизайндаги чизиқли иконкалар (қалинлиги 2), тўлдирилганлари ишлатилмайди
  var line = window.IC_STYLE === "line", SW = line ? 2 : 1.7;
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
    tick:   ['<path d="m5 12.5 4.5 4.5L19 7.5"/>', '<path d="M9 16.2 4.8 12l-1.4 1.4L9 19 21 7l-1.4-1.4z"/>'],
    cross:  ['<path d="M6 6l12 12M18 6 6 18"/>', '<path d="M19 6.4 17.6 5 12 10.6 6.4 5 5 6.4 10.6 12 5 17.6 6.4 19 12 13.4 17.6 19 19 17.6 13.4 12z"/>'],
    ruler:  ['<path d="M3 15.5 15.5 3 21 8.5 8.5 21z"/><path d="m7 11 2 2M10 8l2 2M13 5l2 2"/>', '<path d="M21 6H3a1 1 0 0 0-1 1v10a1 1 0 0 0 1 1h18a1 1 0 0 0 1-1V7a1 1 0 0 0-1-1zm-1 10H4V8h2v4h2V8h2v4h2V8h2v4h2V8h2z"/>'],
    store:  ['<path d="M4 9.5 5.5 4h13L20 9.5M4 9.5v10h16v-10M4 9.5a2.7 2.7 0 0 0 5.3 0 2.7 2.7 0 0 0 5.4 0 2.7 2.7 0 0 0 5.3 0M10 19.5v-5h4v5"/>', '<path d="M20 4H4v2h16zM21 14v-2l-1-5H4l-1 5v2h1v6h10v-6h4v6h2v-6zm-9 4H6v-4h6z"/>'],
    receipt:['<path d="M6 3h12v18l-3-2-3 2-3-2-3 2zM9 8h6M9 12h6"/>', '<path d="M18 17H6v-2h12zm0-4H6v-2h12zm0-4H6V7h12zM3 22l1.5-1.5L6 22l1.5-1.5L9 22l1.5-1.5L12 22l1.5-1.5L15 22l1.5-1.5L18 22l1.5-1.5L21 22V2l-1.5 1.5L18 2l-1.5 1.5L15 2l-1.5 1.5L12 2l-1.5 1.5L9 2 7.5 3.5 6 2 4.5 3.5 3 2z"/>'],
    basket: ['<path d="M3 4h2l2 11h11l2-8H6.5"/><circle cx="9" cy="19" r="1.3"/><circle cx="17" cy="19" r="1.3"/>', '<path d="M7 18a2 2 0 1 0 0 4 2 2 0 0 0 0-4zm10 0a2 2 0 1 0 0 4 2 2 0 0 0 0-4zM1 2v2h2l3.6 7.6-1.4 2.4c-.1.3-.2.6-.2 1 0 1.1.9 2 2 2h12v-2H7.4a.25.25 0 0 1-.2-.4l.9-1.6h7.5c.8 0 1.4-.4 1.7-1l3.6-6.5A1 1 0 0 0 20 4H5.2l-.9-2z"/>'],
    tool:   ['<path d="M15 4a4.5 4.5 0 0 0-4 6.3L4 17.3 6.7 20l7-7A4.5 4.5 0 0 0 20 9l-3 3-2.5-.5L14 9l3-3a4.5 4.5 0 0 0-2-2z"/>', '<path d="M22.7 19l-9.1-9.1c.9-2.3.4-5-1.5-6.9-2-2-5-2.4-7.4-1.3L9 6 6 9 1.6 4.7C.4 7.1.9 10.1 2.9 12.1c1.9 1.9 4.6 2.4 6.9 1.5l9.1 9.1c.4.4 1 .4 1.4 0l2.3-2.3c.5-.4.5-1.1.1-1.4z"/>'],
    clock:  ['<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>', '<path d="M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20zm4.2 14.2L11 13V7h1.5v5.2l4.5 2.7z"/>'],
    card:   ['<rect x="3" y="5.5" width="18" height="13" rx="2.5"/><path d="M3 10h18M7 15h3"/>', '<path d="M20 4H4a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2V6a2 2 0 0 0-2-2zm0 14H4v-6h16zm0-10H4V6h16z"/>'],
    tag:    ['<path d="M3.5 12.5V4.5a1 1 0 0 1 1-1h8l8 8a1 1 0 0 1 0 1.4l-7.6 7.6a1 1 0 0 1-1.4 0z"/><circle cx="8" cy="8" r="1.3"/>', '<path d="M21.4 11.6l-9-9A2 2 0 0 0 11 2H4a2 2 0 0 0-2 2v7c0 .55.22 1.05.59 1.42l9 9c.36.36.86.58 1.41.58.55 0 1.05-.22 1.41-.59l7-7c.37-.36.59-.86.59-1.41 0-.55-.23-1.06-.6-1.42zM5.5 7a1.5 1.5 0 1 1 0-3 1.5 1.5 0 0 1 0 3z"/>'],
    phone:  ['<rect x="7" y="2.5" width="10" height="19" rx="2.5"/><path d="M11 18.5h2"/>', '<path d="M17 1H7a2 2 0 0 0-2 2v18a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V3a2 2 0 0 0-2-2zm0 18H7V5h10z"/>'],
    user:   ['<circle cx="12" cy="8" r="3.8"/><path d="M4.5 20a7.5 7.5 0 0 1 15 0"/>', '<path d="M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8zm0 2c-2.7 0-8 1.3-8 4v2h16v-2c0-2.7-5.3-4-8-4z"/>'],
    chat:   ['<path d="M4 5h16v11H9l-5 4z"/>', '<path d="M20 2H4a2 2 0 0 0-2 2v18l4-4h14a2 2 0 0 0 2-2V4a2 2 0 0 0-2-2z"/>'],
    bell:   ['<path d="M6 17V11a6 6 0 0 1 12 0v6l1.5 2h-15zM10 21h4"/>', '<path d="M12 22a2 2 0 0 0 2-2h-4a2 2 0 0 0 2 2zm6-6v-5c0-3.1-1.6-5.6-4.5-6.3V4a1.5 1.5 0 0 0-3 0v.7C7.6 5.4 6 7.9 6 11v5l-2 2v1h16v-1z"/>'],
    camera: ['<path d="M4 8h3l1.5-2.5h7L17 8h3v11H4z"/><circle cx="12" cy="13" r="3.4"/>', '<circle cx="12" cy="12" r="3.2"/><path d="M9 2 7.2 4H4a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2V6a2 2 0 0 0-2-2h-3.2L15 2zm3 15a5 5 0 1 1 0-10 5 5 0 0 1 0 10z"/>'],
    download:['<path d="M12 4v11M7.5 11 12 15.5 16.5 11M5 19.5h14"/>', '<path d="M19 9h-4V3H9v6H5l7 7zM5 18v2h14v-2z"/>'],
    warning:['<path d="M12 3.5 21.5 20h-19zM12 10v4.5M12 17.2h.01"/>', '<path d="M1 21h22L12 2zm12-3h-2v-2h2zm0-4h-2v-4h2z"/>'],
    bolt:   ['<path d="M13 3 5 13.5h6L10 21l9-11h-6z"/>', '<path d="M7 2v11h3v9l7-12h-4l4-8z"/>'],
    plus:   ['<path d="M12 5v14M5 12h14"/>', '<path d="M19 13h-6v6h-2v-6H5v-2h6V5h2v6h6z"/>'],
    heart:  ['<path d="M12 20s-7.5-4.6-7.5-10A4.2 4.2 0 0 1 12 7.6 4.2 4.2 0 0 1 19.5 10c0 5.4-7.5 10-7.5 10z"/>', '<path d="M12 21.4 10.6 20C5.4 15.4 2 12.3 2 8.5A4.5 4.5 0 0 1 6.5 4c1.7 0 3.4.8 4.5 2.1C12.1 4.8 13.8 4 15.5 4A4.5 4.5 0 0 1 20 8.5c0 3.8-3.4 6.9-8.6 11.5z"/>'],
    car:    ['<path d="M4 16V12l2-5h12l2 5v4zM4 16v2.5M20 16v2.5M4 12h16"/><circle cx="7.5" cy="14.2" r=".9"/><circle cx="16.5" cy="14.2" r=".9"/>', '<path d="M18.9 6c-.2-.6-.8-1-1.4-1h-11c-.7 0-1.2.4-1.4 1L3 12v8a1 1 0 0 0 1 1h1a1 1 0 0 0 1-1v-1h12v1a1 1 0 0 0 1 1h1a1 1 0 0 0 1-1v-8zM6.5 16a1.5 1.5 0 1 1 0-3 1.5 1.5 0 0 1 0 3zm11 0a1.5 1.5 0 1 1 0-3 1.5 1.5 0 0 1 0 3zM5 11l1.5-4.5h11L19 11z"/>'],
    star:   ['<path d="m12 3.5 2.6 5.5 6 .8-4.4 4.1 1.1 5.9L12 16.9 6.7 19.8l1.1-5.9L3.4 9.8l6-.8z"/>', '<path d="m12 17.3 6.2 3.7-1.6-7L22 9.2l-7.2-.6L12 2 9.2 8.6 2 9.2 7.5 14l-1.6 7z"/>'],
    dot:    ['<circle cx="12" cy="12" r="6" fill="currentColor" stroke="none"/>', '<circle cx="12" cy="12" r="6"/>'],
    nav:    ['<path d="M20 4 4 10.5l6.5 2.5 2.5 6.5z"/>', '<path d="M21 3 3 10.5l7 2.5 2.5 7z"/>'],
    // Каталог ва хоналар учун (фақат чизиқли)
    brick:  ['<rect x="3" y="5" width="18" height="14" rx="1.5"/><path d="M3 9.7h18M3 14.3h18M9 5v4.7M15 5v4.7M6 9.7v4.6M12 9.7v4.6M18 9.7v4.6M9 14.3V19M15 14.3V19"/>'],
    bag:    ['<path d="M6 6.5 7.5 3h9L18 6.5"/><path d="M5.5 6.5h13l1 13.5a1 1 0 0 1-1 1h-13a1 1 0 0 1-1-1z"/><path d="M9 11h6"/>'],
    rebar:  ['<path d="M5 19 19 5M5 13l8-8M11 19l8-8"/><path d="M7 15l2 2M10 12l2 2M13 9l2 2"/>'],
    wood:   ['<rect x="3" y="5.5" width="18" height="5.5" rx="1"/><rect x="3" y="13" width="18" height="5.5" rx="1"/><circle cx="6.5" cy="8.2" r=".9"/><circle cx="6.5" cy="15.7" r=".9"/>'],
    plug:   ['<path d="M9 2v5M15 2v5M6 7h12v4a6 6 0 0 1-12 0zM12 17v5"/>'],
    bulb:   ['<path d="M9 18h6M10 22h4"/><path d="M12 2a7 7 0 0 0-4 12.7c.6.5 1 1.2 1 2V18h6v-1.3c0-.8.4-1.5 1-2A7 7 0 0 0 12 2z"/>'],
    drop:   ['<path d="M12 2.7 17.7 8.4a8 8 0 1 1-11.4 0z"/>'],
    pipe:   ['<path d="M3 6h10a5 5 0 0 1 5 5v10M3 11h8a2 2 0 0 1 2 2v8"/><path d="M3 4v9M16 21h4"/>'],
    flame:  ['<path d="M8.5 14.5A2.5 2.5 0 0 0 11 12c0-1.4-.5-2-1-3-1.1-2.1-.2-4 2-6 .5 2.5 2 4.9 4 6.5 2 1.6 3 3.5 3 5.5a7 7 0 1 1-14 0c0-1.2.4-2.3 1-3.1.3 1.5 1.4 2.6 2.5 2.6z"/>'],
    layers: ['<path d="M12 2 2 7l10 5 10-5z"/><path d="m2 17 10 5 10-5M2 12l10 5 10-5"/>'],
    shield: ['<path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/>'],
    grid:   ['<rect x="3" y="3" width="18" height="18" rx="2"/><path d="M3 12h18M12 3v18"/>'],
    brush:  ['<path d="M18.4 2.6a2 2 0 0 1 2.9 2.9L12 14.8 9.2 12z"/><path d="M7 14a3 3 0 0 0-3 3c0 1.5-1 2.5-2 3 3 1.5 7 .5 8-2a3 3 0 0 0-3-4z"/>'],
    door:   ['<path d="M5 21V4a1 1 0 0 1 1-1h12a1 1 0 0 1 1 1v17M3 21h18M15 12h.01"/>'],
    hammer: ['<path d="m15 12-8.5 8.5a2.1 2.1 0 0 1-3-3L12 9"/><path d="M17.6 15 22 10.6M20.9 11.7l-1.3-1.3c-.6-.6-.9-1.4-.9-2.2V6.9L16.2 4.4A6 6 0 0 0 12 2.7H9l.9.8A6.6 6.6 0 0 1 12 8.4v1.6l2 2h2.5c.9 0 1.7.3 2.3.9l1.3 1.3"/>'],
    nut:    ['<path d="M12 2.5 20.2 7.3v9.4L12 21.5l-8.2-4.8V7.3z"/><circle cx="12" cy="12" r="3"/>'],
    bed:    ['<path d="M2 4v16M2 8h18a2 2 0 0 1 2 2v10M2 17h20M6 8v9"/>'],
    sun:    ['<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/>'],
    flask:  ['<path d="M9 3h6M10 3v6L4.5 18.5A1.7 1.7 0 0 0 6 21h12a1.7 1.7 0 0 0 1.5-2.5L14 9V3M7 15h10"/>']
  };
  var IC = {
    ios: ios,
    i: function (n, s) {
      var d = P[n]; if (!d) return ""; s = s || 20;
      return ios || line || !d[1] ? '<svg class="ic" viewBox="0 0 24 24" width="' + s + '" height="' + s + '" fill="none" stroke="currentColor" stroke-width="' + SW + '" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" style="vertical-align:-4px">' + d[0] + '</svg>'
                 : '<svg class="ic" viewBox="0 0 24 24" width="' + s + '" height="' + s + '" fill="currentColor" aria-hidden="true" style="vertical-align:-4px">' + d[1] + '</svg>';
    },
    // Харита маркази булавкаси (тагидаги учи — аниқ нуқта)
    pin: function () {
      var id = "pg" + Math.floor(Math.random() * 1e6);
      if (line) return '<svg viewBox="0 0 44 60" width="44" height="60" aria-hidden="true"><defs><linearGradient id="' + id + '" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#F97316"/><stop offset="1" stop-color="#EA580C"/></linearGradient></defs>' +
        '<ellipse cx="22" cy="57" rx="7" ry="2.4" fill="rgba(0,0,0,.35)"/><path d="M22 56C22 56 4 37.5 4 22a18 18 0 0 1 36 0c0 15.5-18 34-18 34z" fill="url(#' + id + ')" stroke="#fff" stroke-width="2"/>' +
        '<circle cx="22" cy="22" r="6.5" fill="#fff"/></svg>';
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
      if (line) { bg = n === "home" || n === "B" ? "#3B82F6" : "linear-gradient(135deg,#F97316,#EA580C)"; fg = "#fff"; }
      return '<div style="width:34px;height:34px;border-radius:50%;background:' + bg + ';color:' + fg + ';display:grid;place-items:center;border:2.5px solid #fff;box-shadow:0 2px 6px rgba(0,0,0,.35);margin:3px">' + inner + '</div>';
    }
  };
  window.IC = IC;

  // ---- Эмодзини автоматик иконкага алмаштириш (матн бошидаги интерфейс эмодзилари) ----
  var G = line ? "#10B981" : "#1F9D55", R = line ? "#FB7185" : "#D93025", A = line ? "#FBBF24" : "#D9822B";
  var EMAP = { "✅":["check",G], "✓":["tick"], "❌":["cross",R], "✕":["cross"], "📍":["pin"], "🏬":["store"], "🏪":["store"], "📦":["box"], "🧾":["receipt"],
    "🧺":["basket"], "🛒":["basket"], "🛍":["basket"], "🏠":["home"], "🔧":["tool"], "🛠":["tool"], "🕒":["clock"], "⏳":["clock"], "⏱":["clock"], "💳":["card"],
    "🏷":["tag"], "📱":["phone"], "👤":["user"], "💬":["chat"], "🔔":["bell"], "📷":["camera"], "⬇":["download"], "⚠️":["warning",A], "⚠":["warning",A],
    "⚡":["bolt"], "➕":["plus"], "🧪":["flask"], "🙏":["heart"], "🙋":["check"], "🗺":["map"], "🚚":["truck"], "🚐":["truck"], "🚛":["truck"], "🛻":["truck"],
    "🚗":["car"], "🚕":["car"], "🎯":["locate"], "★":["star"], "📏":["ruler"], "📐":["ruler"], "🔴":["dot",R], "🟡":["dot",A], "🟢":["dot",G] };
  var keys = Object.keys(EMAP).sort(function (a, b) { return b.length - a.length; });
  var esc = function (x) { return x.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"); };
  var LEAD = new RegExp("^(\\s*)(" + keys.map(esc).join("|") + ")\\uFE0F?\\s*");
  IC.LEAD = new RegExp("^(?:" + keys.map(esc).join("|") + ")\\uFE0F?\\s*");
  var SKIP = "script,style,textarea,option,title,select,.pic,.ge,.emo,.hse,.mk,.e,[data-noskin],svg";
  function sk(name, color) {
    var d = P[name]; if (!d) return null;
    var sp = document.createElement("span"); sp.className = "sk";
    sp.style.cssText = "display:inline-flex;vertical-align:-.2em;margin-right:.35em;width:1.15em;height:1.15em;flex:none" + (color ? ";color:" + color : "");
    sp.innerHTML = ios || line || !d[1] ? '<svg viewBox="0 0 24 24" width="100%" height="100%" fill="none" stroke="currentColor" stroke-width="' + (line ? 2 : 1.8) + '" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' + d[0] + '</svg>'
                       : '<svg viewBox="0 0 24 24" width="100%" height="100%" fill="currentColor" aria-hidden="true">' + d[1] + '</svg>';
    return sp;
  }
  function skinNode(n) {
    var v = n.nodeValue; if (!v) return;
    var m = v.match(LEAD); if (!m) return;
    var p = n.parentNode; if (!p || (p.closest && p.closest(SKIP))) return;
    var e = EMAP[m[2].replace(/\uFE0F/g, "")] || EMAP[m[2]]; if (!e) return;
    var prev = n.previousSibling; if (prev && prev.nodeType === 1 && prev.className === "sk") p.removeChild(prev);
    var el = sk(e[0], e[1]); if (!el) return;
    n.nodeValue = v.slice(m[0].length);
    p.insertBefore(el, n);
    if (!n.nodeValue) el.style.marginRight = "0";
  }
  function skinTree(root) {
    if (!root) return;
    if (root.nodeType === 3) return skinNode(root);
    if (root.nodeType !== 1 || (root.closest && root.closest(SKIP))) return;
    var w = document.createTreeWalker(root, NodeFilter.SHOW_TEXT, null), arr = [], x;
    while ((x = w.nextNode())) { if (x.nodeValue && x.nodeValue.length < 400) arr.push(x); }
    for (var i = 0; i < arr.length; i++) skinNode(arr[i]);
  }
  var pend = new Set(), raf = 0;
  function flush() { raf = 0; var a = Array.from(pend); pend.clear(); for (var i = 0; i < a.length; i++) if (a[i].isConnected) skinTree(a[i]); }
  function init() {
    skinTree(document.body);
    new MutationObserver(function (list) {
      for (var i = 0; i < list.length; i++) {
        var mu = list[i];
        if (mu.type === "characterData") pend.add(mu.target);
        else for (var j = 0; j < mu.addedNodes.length; j++) { var nd = mu.addedNodes[j]; if (!(nd.nodeType === 1 && nd.className === "sk")) pend.add(nd); }
      }
      if (pend.size && !raf) raf = requestAnimationFrame(flush);
    }).observe(document.body, { childList: true, subtree: true, characterData: true });
  }
  IC.ALT = keys.map(esc).join("|");
  IC.skin = skinTree;
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", init); else init();
  // Булавка суриш пайтида кўтарилади
  document.addEventListener("pointerdown", function (e) { var m = e.target.closest && e.target.closest(".pick-mw"); if (m) { var p = m.querySelector(".pin"); if (p) p.classList.add("up"); } }, true);
  document.addEventListener("pointerup", function () { var p = document.querySelector(".pin.up"); if (p) p.classList.remove("up"); }, true);
  document.addEventListener("pointercancel", function () { var p = document.querySelector(".pin.up"); if (p) p.classList.remove("up"); }, true);
  var st = document.createElement("style");
  st.textContent = ".pin{font-size:0!important;transition:transform .15s ease;transform-origin:50% 100%}.pin.up{transform:translate(-50%,-100%) translateY(-10px)}.pin svg{display:block;filter:drop-shadow(0 3px 3px rgba(0,0,0,.25))}";
  document.head.appendChild(st);
})();
