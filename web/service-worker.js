const prefix = "swag:" + self.registration.scope + ":";
const cacheName = prefix + "501941c09c5a513c6495a0f66aff14f99fc70ca84e7b74da36f211d85b3ba0f1";
const files = ["LICENSE-APACHE","LICENSE-MIT","app.bundle.json","app.lab","app.lax","app.mjs","assets/drum-hat.wav","assets/drum-kick.wav","assets/drum-snare.wav","assets/electronic-hat.wav","assets/electronic-kick.wav","assets/electronic-snare.wav","assets/metronome.wav","assets/organ-a4.wav","assets/piano-a4.wav","assets/synth-a4.wav","catalog.ls.ts","icons/icon-192.png","icons/icon-512.png","index.html","la_player_bg.wasm","manifest.webmanifest","piano.css","piano.ls.ts"].map(path => new URL(path, self.registration.scope).href);
self.addEventListener("install", event => {
  event.waitUntil(caches.open(cacheName).then(cache => cache.addAll(files)));
});
self.addEventListener("activate", event => {
  event.waitUntil(caches.keys().then(keys => Promise.all(keys
    .filter(key => key.startsWith(prefix) && key !== cacheName).map(key => caches.delete(key))))
    .then(() => self.clients.claim()));
});
self.addEventListener("fetch", event => {
  if (event.request.method !== "GET") return;
  const url = new URL(event.request.url);
  url.search = "";
  if (url.href === self.registration.scope) url.pathname += "index.html";
  if (!files.includes(url.href)) return;
  event.respondWith(caches.open(cacheName).then(async cache =>
    (await cache.match(url.href)) ?? fetch(event.request)));
});
