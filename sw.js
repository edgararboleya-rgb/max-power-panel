// Max Power — service worker: recibe las notificaciones y las muestra
self.addEventListener("install", () => self.skipWaiting());
self.addEventListener("activate", e => e.waitUntil(self.clients.claim()));

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
