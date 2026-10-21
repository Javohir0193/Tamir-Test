// Ta'mir — Яндекс Карталар адаптери. config.js даги ymapsKey тўлдирилса, Leaflet ўрнига Яндекс харита ишлайди.
// Кодда ишлатилган Leaflet функцияларининг кичик тўплами (L.map, marker, divIcon, fitBounds, getCenter) Яндексга мослаб берилган.
// Калит бўш бўлса — аввалгидек OpenStreetMap ишлайди.
(function () {
  var cfg = window.TAMIR_CONFIG || {};
  window.TAMIR_YMAPS = !!cfg.ymapsKey;
  var p = null;
  window.loadYandexAsL = function () {
    if (window.L && window.L.__ya) return Promise.resolve();
    if (p) return p;
    p = new Promise(function (res, rej) {
      var s = document.createElement("script");
      s.src = "https://api-maps.yandex.ru/2.1/?apikey=" + encodeURIComponent(cfg.ymapsKey) + "&lang=ru_RU";
      s.onload = function () { ymaps.ready(function () { build(); res(); }); };
      s.onerror = function () { p = null; rej(new Error("ymaps")); };
      document.head.appendChild(s);
    });
    return p;
  };
  function build() {
    var Tpl = ymaps.templateLayoutFactory.createClass('<div style="font-size:30px;line-height:36px;width:40px;text-align:center;transform:translate(-20px,-36px);filter:drop-shadow(0 2px 2px rgba(0,0,0,.35))">$[properties.t]</div>');
    function YMap(el, opts) {
      var node = typeof el === "string" ? document.getElementById(el) : el;
      this._m = new ymaps.Map(node, { center: [41.3111, 69.2797], zoom: 12, controls: [] }, { suppressMapOpenBlock: true });
      this._node = node; var self = this; [100, 400, 1000].forEach(function (t) { setTimeout(function () { self.invalidateSize(); }, t); });
    }
    YMap.prototype.setView = function (c, z) { var self = this; this._m.setCenter(c, z == null ? this._m.getZoom() : z); [120, 500, 1200].forEach(function (t) { setTimeout(function () { self.invalidateSize(); }, t); }); return this; };
    YMap.prototype.getCenter = function () { var c = this._m.getCenter(); return { lat: c[0], lng: c[1] }; };
    YMap.prototype.invalidateSize = function () { try { this._m.container.fitToViewport(); } catch (e) {} };
    YMap.prototype.fitBounds = function (pts, o) {
      o = o || {}; var self = this, b = ymaps.util.bounds.fromPoints(pts), pad = (o.padding && o.padding[0]) || 40;
      this._m.setBounds(b, { checkZoomRange: true, zoomMargin: pad }).then(function () { if (o.maxZoom && self._m.getZoom() > o.maxZoom) self._m.setZoom(o.maxZoom); });
      return this;
    };
    function Marker(ll, o) { this._ll = ll; this._t = (o && o.icon && o.icon._t) || "📍"; }
    Marker.prototype.addTo = function (map) {
      this._pm = new ymaps.Placemark(this._ll, { t: this._t }, { iconLayout: Tpl, iconShape: { type: "Rectangle", coordinates: [[-20, -36], [20, 0]] } });
      map._m.geoObjects.add(this._pm); return this;
    };
    Marker.prototype.setLatLng = function (ll) { this._ll = ll; if (this._pm) this._pm.geometry.setCoordinates(ll); return this; };
    window.L = {
      __ya: true,
      map: function (el, o) { return new YMap(el, o); },
      marker: function (ll, o) { return new Marker(ll, o); },
      divIcon: function (o) { return { _t: o.html }; },
      tileLayer: function () { return { addTo: function () {} }; }
    };
  }
})();
