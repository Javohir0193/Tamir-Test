// Ta'mir — Excel (.xlsx) файлнинг биринчи варағини браузернинг ўзида ўқиш (ташқи кутубхонасиз).
// Нима учун ўзимиз: npm'даги xlsx@0.18.5 да маълум заифликлар бор (CVE-2023-30533, CVE-2024-22363), янгиси npm'да йўқ.
// Бизга фақат катаклардаги матн ва рақам керак: формат, формула, сана, расм ўқилмайди.
// Ишлатиш: TamirXlsx.read(arrayBuffer) → Promise<string[][]> (қаторлар, ҳар бири катаклар матни).
// Керак: DecompressionStream («deflate-raw») — Chrome 103+, Safari 16.4+, Firefox 113+. Бўлмаса хато: «CSV қилиб сақланг».
(function () {
  "use strict";
  var MAX_FILE = 5 * 1024 * 1024, MAX_PART = 30 * 1024 * 1024, MAX_ROWS = 5000, MAX_COLS = 50;

  function u16(b, o) { return b[o] | (b[o + 1] << 8); }
  function u32(b, o) { return (b[o] | (b[o + 1] << 8) | (b[o + 2] << 16) | (b[o + 3] << 24)) >>> 0; }

  // ZIP: марказий каталогдан файллар рўйхати (ном → {method, size, usize, off})
  function zipEntries(b) {
    var eocd = -1;
    for (var i = b.length - 22; i >= Math.max(0, b.length - 22 - 65535); i--) if (u32(b, i) === 0x06054b50) { eocd = i; break; }
    if (eocd < 0) throw new Error("not_xlsx");
    var n = u16(b, eocd + 10), p = u32(b, eocd + 16), out = {}, dec = new TextDecoder("utf-8");
    for (var k = 0; k < n && k < 2000; k++) {
      if (p + 46 > b.length || u32(b, p) !== 0x02014b50) throw new Error("not_xlsx");
      var method = u16(b, p + 10), size = u32(b, p + 20), usize = u32(b, p + 24), nl = u16(b, p + 28), xl = u16(b, p + 30), cl = u16(b, p + 32), off = u32(b, p + 42);
      out[dec.decode(b.subarray(p + 46, p + 46 + nl))] = { method: method, size: size, usize: usize, off: off };
      p += 46 + nl + xl + cl;
    }
    return out;
  }

  async function inflate(data, limit) {
    if (typeof DecompressionStream === "undefined") throw new Error("no_inflate");
    var rd = new Blob([data]).stream().pipeThrough(new DecompressionStream("deflate-raw")).getReader(), parts = [], total = 0;
    for (;;) {
      var r = await rd.read(); if (r.done) break;
      total += r.value.length; if (total > limit) { try { rd.cancel(); } catch (_) {} throw new Error("too_big"); }   // «zip bomb»дан ҳимоя
      parts.push(r.value);
    }
    var res = new Uint8Array(total), o = 0; parts.forEach(function (x) { res.set(x, o); o += x.length; });
    return res;
  }

  async function readPart(b, ents, name) {
    var e = ents[name]; if (!e) return null;
    if (e.usize > MAX_PART) throw new Error("too_big");
    var lo = e.off; if (u32(b, lo) !== 0x04034b50) throw new Error("not_xlsx");
    var start = lo + 30 + u16(b, lo + 26) + u16(b, lo + 28), data = b.subarray(start, start + e.size);
    var raw = e.method === 0 ? data : e.method === 8 ? await inflate(data, MAX_PART) : null;
    if (!raw) throw new Error("not_xlsx");
    return new DOMParser().parseFromString(new TextDecoder("utf-8").decode(raw), "application/xml");
  }

  var tags = function (node, name) { return node ? Array.prototype.slice.call(node.getElementsByTagNameNS("*", name)) : []; };
  var text = function (node) { return tags(node, "t").map(function (t) { return t.textContent; }).join(""); };
  function colNo(ref) { var m = /^([A-Z]+)/.exec(ref || ""), n = 0; if (!m) return -1; for (var i = 0; i < m[1].length; i++) n = n * 26 + m[1].charCodeAt(i) - 64; return n - 1; }

  async function read(buf) {
    var b = new Uint8Array(buf);
    if (b.length > MAX_FILE) throw new Error("too_big");
    var ents = zipEntries(b);
    // биринчи варақ: workbook.xml → r:id → workbook.xml.rels → йўл (бўлмаса sheet1.xml)
    var path = "xl/worksheets/sheet1.xml";
    var wb = await readPart(b, ents, "xl/workbook.xml"), rels = await readPart(b, ents, "xl/_rels/workbook.xml.rels");
    var first = tags(wb, "sheet")[0];
    if (first && rels) {
      var rid = first.getAttribute("r:id") || first.getAttributeNS("http://schemas.openxmlformats.org/officeDocument/2006/relationships", "id");
      tags(rels, "Relationship").forEach(function (r) {
        if (r.getAttribute("Id") === rid) { var t = r.getAttribute("Target") || ""; path = t.charAt(0) === "/" ? t.slice(1) : "xl/" + t.replace(/^\.\//, ""); }
      });
    }
    var ss = (tags(await readPart(b, ents, "xl/sharedStrings.xml"), "si")).map(text);
    var sh = await readPart(b, ents, path);
    if (!sh) throw new Error("not_xlsx");
    var rows = [];
    tags(sh, "row").slice(0, MAX_ROWS).forEach(function (row) {
      var cells = [];
      tags(row, "c").forEach(function (c, i) {
        var col = colNo(c.getAttribute("r")); if (col < 0) col = i; if (col >= MAX_COLS) return;
        var t = c.getAttribute("t"), v = tags(c, "v")[0], val;
        if (t === "s") val = ss[+(v ? v.textContent : -1)] || "";
        else if (t === "inlineStr") val = text(tags(c, "is")[0]);
        else if (t === "b") val = v && v.textContent === "1" ? "1" : "0";
        else val = v ? v.textContent : "";
        // рақамлар: Excel 62000 ни «62000» ёки «61999.999999999993» каби сақлайди — 6 хонагача яхлитлаймиз
        if (!t || t === "n") { var f = parseFloat(val); if (isFinite(f) && /^-?[\d.]+(E[-+]?\d+)?$/i.test(val)) val = String(Math.round(f * 1e6) / 1e6); }
        while (cells.length < col) cells.push("");
        cells[col] = String(val);
      });
      if (cells.some(function (x) { return String(x).trim(); })) rows.push(cells);
    });
    return rows;
  }

  // Файл .xlsx эканини биринчи байтлардан аниқлаш (ZIP «PK\x03\x04»)
  function isXlsx(buf) { var b = new Uint8Array(buf, 0, Math.min(4, buf.byteLength)); return b.length === 4 && b[0] === 0x50 && b[1] === 0x4b && b[2] === 3 && b[3] === 4; }

  window.TamirXlsx = { read: read, isXlsx: isXlsx };
})();
