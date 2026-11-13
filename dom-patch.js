// Ta'mir: «фақат ўзгарган жойни янгилаш» (morph). paint(el, html) — el.innerHTML = html билан бир хил натижа беради,
// лекин эски элементларни ўчириб қайта чизмайди: янги HTML'ни эскиси билан солиштириб, фақат фарқ қилган матн,
// атрибут ёки элементни ўзгартиради. Натижада:
//  - ҳар 4–15 сониядаги янгиланишда саҳифа «сакрамайди», скрол ва фокус жойида қолади;
//  - i18n.js (ўзбекча таржима) ва icons.js (эмодзи → иконка) фақат ўзгарган кичик қисмни қайта ишлайди;
//  - харита (Leaflet) ва «Осталось: 4:31» каби ўзи янгиланадиган жойлар тегилмайди.
// Ташқи кутубхонасиз. i18n.js таржима қилган матннинг аслини window.__i18n орқали, icons.js эса IC.orig орқали беради.
(function () {
  "use strict";
  var tpl = document.createElement("template");

  // Таржима ёки иконка қўйилгунча бўлган асл матн (шу билан солиштирамиз, акс ҳолда ҳар сафар «ўзгарган» бўлиб қоларди)
  function origText(n) {
    var i = window.__i18n, v;
    if (i && (v = i.orig(n)) != null) return v;
    if (window.IC && IC.orig && (v = IC.orig.get(n)) != null) return v;
    return n.nodeValue;
  }
  function origAttr(el, a) {
    var i = window.__i18n, v;
    if (i && (v = i.origAttr(el, a)) != null) return v;
    return el.getAttribute(a);
  }
  var isSk = function (n) { return n.nodeType === 1 && n.tagName === "SPAN" && n.className === "sk"; };   // icons.js қўйган иконка

  function setText(n, v) {
    if (window.__i18n) window.__i18n.forget(n);
    if (window.IC && IC.orig) IC.orig.delete(n);
    var p = n.previousSibling; if (p && isSk(p)) p.parentNode.removeChild(p);   // icons.js янги матнга ўзи қайта қўяди
    n.nodeValue = v;
  }

  function syncAttrs(a, b) {
    var i, at, name;
    for (i = a.attributes.length - 1; i >= 0; i--) {
      name = a.attributes[i].name;
      if (!b.hasAttribute(name)) { if (window.__i18n) window.__i18n.forgetAttr(a, name); a.removeAttribute(name); }
    }
    for (i = 0; i < b.attributes.length; i++) {
      at = b.attributes[i];
      if (origAttr(a, at.name) !== at.value) { if (window.__i18n) window.__i18n.forgetAttr(a, at.name); a.setAttribute(at.name, at.value); }
    }
  }
  // innerHTML'даги каби: форма майдонлари янги HTML'даги қийматни олади (фақат ҳозир ёзилаётган майдонга тегмаймиз)
  function syncForm(a, b) {
    var tag = a.tagName;
    if (tag === "INPUT") {
      if (a.type === "checkbox" || a.type === "radio") { var c = b.hasAttribute("checked"); if (a.checked !== c) a.checked = c; }
      else if (a.type !== "file" && a !== document.activeElement) { var v = b.getAttribute("value") || ""; if (a.value !== v) a.value = v; }
    } else if (tag === "TEXTAREA") {
      if (a !== document.activeElement && a.value !== b.value) a.value = b.value;
    } else if (tag === "SELECT") {
      if (a !== document.activeElement) {
        var idx = 0, o = a.options;
        for (var i = 0; i < o.length; i++) if (o[i].hasAttribute("selected")) { idx = i; break; }
        if (a.selectedIndex !== idx) a.selectedIndex = idx;
      }
    }
  }
  function key(n) {
    if (n.nodeType !== 1) return null;
    return n.getAttribute("data-map") || n.getAttribute("data-pid") || n.getAttribute("data-ord") || n.getAttribute("data-item") || n.id || null;
  }
  function same(a, b) { return a.nodeType === b.nodeType && (a.nodeType !== 1 || a.tagName === b.tagName); }

  function morphNode(a, b) {
    if (a.nodeType === 3 || a.nodeType === 8) { if (origText(a) !== b.nodeValue) setText(a, b.nodeValue); return; }
    // Харита: шу буюртманинг харитаси бўлса — бутунлай тегмаймиз (mountMaps маркерни ўзи суради)
    if (a.hasAttribute("data-map") && a.getAttribute("data-map") === b.getAttribute("data-map")) return;
    syncAttrs(a, b);
    // «Осталось: 4:31» — ҳар сония ўзи янгиланади, «--:--» билан устидан ёзмаймиз
    if (!(a.hasAttribute("data-due") && a.getAttribute("data-due") === b.getAttribute("data-due") && a.firstChild)) morphChildren(a, b);
    syncForm(a, b);
  }

  function morphChildren(pa, pb) {
    var olds = [], keyed = new Map(), news = [], used = new Set(), n, i, k, a, b, oi = 0;
    for (n = pa.firstChild; n; n = n.nextSibling) {
      if (isSk(n)) continue;
      olds.push(n);
      k = key(n); if (k) keyed.set(n.tagName + "#" + k, n);
    }
    for (n = pb.firstChild; n; n = n.nextSibling) news.push(n);
    var cur = olds.length ? olds[0] : null;
    var next = function (x) { for (x = x.nextSibling; x && isSk(x); x = x.nextSibling); return x; };
    var ref = function () { return cur && cur.previousSibling && isSk(cur.previousSibling) ? cur.previousSibling : cur; };
    for (i = 0; i < news.length; i++) {
      b = news[i]; a = null; k = key(b);
      if (k) { a = keyed.get(b.tagName + "#" + k) || null; if (a && used.has(a)) a = null; }
      else {
        while (oi < olds.length && (used.has(olds[oi]) || key(olds[oi]))) oi++;
        if (oi < olds.length && same(olds[oi], b)) a = olds[oi++];
      }
      if (a) {
        used.add(a);
        if (a === cur) cur = next(cur);
        else { var sk = a.previousSibling && isSk(a.previousSibling) ? a.previousSibling : null; var r = ref(); pa.insertBefore(a, r); if (sk) pa.insertBefore(sk, a); }
        morphNode(a, b);
      } else pa.insertBefore(b, ref());   // янги элемент: шаблондан тўғридан-тўғри кўчирамиз
    }
    // ортиқча эски элементлар (ва уларнинг иконкалари) ўчирилади
    for (i = 0; i < olds.length; i++) if (!used.has(olds[i])) {
      var o = olds[i], p = o.previousSibling;
      if (p && isSk(p)) pa.removeChild(p);
      pa.removeChild(o);
    }
  }

  function paint(el, html) {
    if (!el) return;
    if (!el.firstChild) { el.innerHTML = html; return; }   // биринчи чизиш — оддий йўл энг тез
    tpl.innerHTML = html;
    morphChildren(el, tpl.content);
    tpl.innerHTML = "";
  }
  window.paint = paint;
})();
