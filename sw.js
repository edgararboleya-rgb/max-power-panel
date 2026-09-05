// ============================================================
// Max Power — service worker
// Dos trabajos:
//   1) Recibir las notificaciones y mostrarlas.
//   2) Guardar el "casco" de la app (index, css, js, iconos) para que
//      ABRA sin señal o si GitHub Pages se cae. Antes, sin internet, tocar
//      el icono dejaba la pantalla en blanco.
// ============================================================
const CACHE = "mxp-casco-v27";
const CASCO = [
  "./", "./index.html", "./css/styles.css",
  "./js/app.js", "./js/db.js", "./js/i18n.js",
  "./assets/config.js", "./assets/logo.js",
  "./manifest.webmanifest",
  "./assets/icon-192.png", "./assets/icon-512.png", "./assets/icon-180.png"
];

self.addEventListener("install", e => {
  e.waitUntil(
    caches.open(CACHE).then(c => c.addAll(CASCO)).catch(() => {})
      .then(() => self.skipWaiting())
  );
});

self.addEventListener("activate", e => {
  e.waitUntil(
    caches.keys()
      .then(ks => Promise.all(ks.filter(k => k !== CACHE).map(k => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener("fetch", e => {
  const req = e.request;
  if (req.method !== "GET") return;
  const url = new URL(req.url);
  // Solo el casco de la app. Los datos (Supabase) SIEMPRE van a la red:
  // nunca se sirve un proyecto o una hora desde el caché.
  if (url.origin !== self.location.origin) return;

  // Los archivos versionados (?v=NN) se pueden servir del caché sin miedo:
  // cuando sube la versión cambia la dirección y se baja el nuevo.
  const versionado = url.search.includes("v=");
  if (versionado) {
    e.respondWith(
      caches.match(req).then(hit => hit || fetch(req).then(r => {
        const copia = r.clone();
        caches.open(CACHE).then(c => c.put(req, copia)).catch(() => {});
        return r;
      }).catch(() =>
        // Sin señal y con una versión nueva que este teléfono todavía no
        // bajó: se sirve la copia sin ?v= que se guardó al instalar. Sin
        // esto la app abría en blanco justo cuando más falta hace.
        caches.match(req, { ignoreSearch: true })))
    );
    return;
  }

  // index.html y lo demás: primero la red (para tener lo último),
  // y si no hay señal, lo que haya guardado.
  e.respondWith(
    fetch(req).then(r => {
      const copia = r.clone();
      caches.open(CACHE).then(c => c.put(req, copia)).catch(() => {});
      return r;
    }).catch(() => caches.match(req).then(hit => hit || caches.match("./index.html")))
  );
});

self.addEventListener("push", e => {
  let d = {};
  try { d = e.data ? e.data.json() : {}; } catch (err) { d = { cuerpo: e.data && e.data.text() }; }
  e.waitUntil(self.registration.showNotification(d.titulo || "Max Power", {
    body: d.cuerpo || "",
    icon: "assets/icon-192.png",
    badge: "assets/icon-192.png",
    tag: d.tag || "mxp",
    data: { url: "." }
  }));
});

self.addEventListener("notificationclick", e => {
  e.notification.close();
  e.waitUntil(self.clients.matchAll({ type: "window", includeUncontrolled: true }).then(ws =>
    ws.length ? ws[0].focus() : self.clients.openWindow(".")));
});
