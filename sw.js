// Простой service worker: сначала сеть, при отсутствии интернета — последняя сохранённая версия страницы.
// + Web Push: билдиришнома телефон блокда бўлса ҳам келади (push.js обуна қилади, tg-bot юборади).
const CACHE = "tamir-v97";
self.addEventListener("install", e => { self.skipWaiting(); });
self.addEventListener("activate", e => {
  e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k !== CACHE).map(k => caches.delete(k)))).then(() => self.clients.claim()));
});
self.addEventListener("fetch", e => {
  const r = e.request;
  if (r.method !== "GET" || new URL(r.url).origin !== location.origin) return;   // Supabase и шрифты не трогаем
  e.respondWith(fetch(r).then(res => { const c = res.clone(); caches.open(CACHE).then(ch => ch.put(r, c)); return res; })
    .catch(() => caches.match(r).then(m => m || caches.match("./"))));
});
// Бот юборган хабар: { t: сарлавҳа, b: матн, u: очиладиган саҳифа, tag }
self.addEventListener("push", e => {
  let d = {}; try { d = e.data ? e.data.json() : {}; } catch (x) { d = { b: e.data ? e.data.text() : "" }; }
  const url = new URL(d.u || "./", self.registration.scope).href;
  e.waitUntil(self.registration.showNotification(d.t || "Ta'mir", {
    body: d.b || "", icon: "icon-192.png", badge: "icon-192.png", tag: d.tag || undefined, renotify: !!d.tag,
    data: { url }, vibrate: [200, 100, 200]
  }));
});
// Билдиришнома босилса: шу илова очиқ бўлса ўшанга ўтади, бўлмаса янгисини очади
self.addEventListener("notificationclick", e => {
  e.notification.close();
  const url = (e.notification.data && e.notification.data.url) || self.registration.scope;
  e.waitUntil(self.clients.matchAll({ type: "window", includeUncontrolled: true }).then(cs => {
    const page = new URL(url).pathname;
    for (const c of cs) if (new URL(c.url).pathname === page && "focus" in c) return c.focus();
    return self.clients.openWindow(url);
  }));
});
