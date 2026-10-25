// ============================================================
// Max Power — service worker
// Dos trabajos:
//   1) Recibir las notificaciones y mostrarlas.
//   2) Guardar el "casco" de la app (index, css, js, iconos) para que
//      ABRA sin señal o si GitHub Pages se cae. Antes, sin internet, tocar
//      el icono dejaba la pantalla en blanco.
// ============================================================
const CACHE = "mxp-casco-v192";
const CASCO = [
  "./", "./index.html", "./css/styles.css",
  "./js/app.js", "./js/db.js", "./js/i18n.js", "./js/iconos.js", "./js/conta.js", "./css/conta.css",
  "./assets/config.js", "./assets/logo.js",
  "./manifest.webmanifest",
  "./assets/icon-192.png", "./assets/icon-512.png", "./assets/icon-180.png",
  "./assets/fonts/manrope.woff2", "./assets/fonts/jetbrains-mono.woff2", "./assets/symbols-tile.svg",
  "./assets/lockup.png"
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

// v279 (22-oct, pliego §13 D7): el aviso puede traer "url" para que tocarlo abra
// una pantalla (p. ej. "?abrir=horas&proyecto=dicke"). Solo vale una dirección
// relativa que empiece por "?", "#" o "./": nunca una ajena ni una que suba de carpeta
// («./../otra»). Si no, abre la app.
const urlDelAviso = u => (typeof u === "string" && /^[?#]|^\.\//.test(u) && !u.includes("//") && !/(^|[/?#])\.\.([/?#]|$)/.test(u)) ? u : ".";

self.addEventListener("push", e => {
  let d = {};
  try { d = e.data ? e.data.json() : {}; } catch (err) { d = { cuerpo: e.data && e.data.text() }; }
  e.waitUntil(self.registration.showNotification(d.titulo || "Max Power", {
    body: d.cuerpo || "",
    icon: "assets/icon-192.png",
    badge: "assets/icon-192.png",
    tag: d.tag || "mxp",
    data: { url: urlDelAviso(d.url) }
  }));
});

self.addEventListener("notificationclick", e => {
  e.notification.close();
  const rel = urlDelAviso(e.notification.data && e.notification.data.url);
  let url = new URL(rel, self.registration.scope).href;
  if (!url.startsWith(self.registration.scope)) url = self.registration.scope; // por si acaso: nunca fuera de la app
  // Si la app ya está abierta (una ventana DE LA APP, no otra página del mismo dominio), se
  // enfoca y se le dice qué pantalla abrir; si no, se abre en esa dirección (la app la lee al arrancar).
  e.waitUntil(self.clients.matchAll({ type: "window", includeUncontrolled: true }).then(ws => {
    const w = ws.find(x => typeof x.url === "string" && x.url.startsWith(self.registration.scope));
    if (w) {
      return Promise.resolve().then(() => w.focus()).catch(() => {})
        .then(() => { w.postMessage({ tipo: "abrir", url }); });
    }
    return self.clients.openWindow(url);
  }));
});
