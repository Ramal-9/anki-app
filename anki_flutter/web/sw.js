// Anki Flow offline service worker.
//
// After the first visit every file of the app is cached, so it opens and works
// without internet (decks, study, AI Practice playback with on-device voices).
// tool/offline.py fills in BUILD and PRECACHE after `flutter build web`;
// without it the worker still caches whatever the app loads.
const BUILD = 'dev';
const PRECACHE = [];

const CACHE = 'anki-flow-' + BUILD;
const FONTS = 'anki-flow-fonts';
const FONT_HOSTS = ['fonts.gstatic.com', 'fonts.googleapis.com', 'www.gstatic.com'];
const scope = self.registration.scope;
const abs = (p) => new URL(p, scope).href;
const precached = new Set(PRECACHE.map(abs));

self.addEventListener('install', (event) => {
  event.waitUntil((async () => {
    const cache = await caches.open(CACHE);
    // The renderer files this device used with the previous version.
    const renderer = new Set();
    for (const key of await caches.keys()) {
      if (!key.startsWith('anki-flow-') || key === CACHE || key === FONTS) continue;
      for (const req of await (await caches.open(key)).keys()) {
        if (req.url.includes('/canvaskit/')) renderer.add(req.url);
      }
    }
    // One by one so a single missing file doesn't break the install.
    await Promise.all(['./', ...PRECACHE, ...renderer].map(async (p) => {
      try {
        const res = await fetch(new Request(abs(p), { cache: 'reload' }));
        if (res.ok) await cache.put(abs(p), res);
      } catch (e) { /* offline during install: cached on first use instead */ }
    }));
    await self.skipWaiting();
  })());
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    for (const key of await caches.keys()) {
      if (key.startsWith('anki-flow-') && key !== CACHE && key !== FONTS) await caches.delete(key);
    }
    await self.clients.claim();
  })());
});

async function fromNetwork(request, cacheName) {
  const res = await fetch(request);
  if (res.ok || res.type === 'opaque') {
    const cache = await caches.open(cacheName);
    await cache.put(request.mode === 'navigate' ? abs('./') : request, res.clone());
  }
  return res;
}

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET') return;
  const url = new URL(request.url);

  // Fonts (e.g. emoji) are fetched once and kept.
  if (FONT_HOSTS.includes(url.hostname)) {
    event.respondWith(caches.match(request).then((hit) => hit || fromNetwork(request, FONTS)));
    return;
  }
  if (url.origin !== self.location.origin) return; // GitHub sync, phrase API: always live

  // Pages: try the network briefly (to pick up updates), else the cached app.
  if (request.mode === 'navigate') {
    event.respondWith((async () => {
      try {
        return await Promise.race([
          fromNetwork(request, CACHE),
          new Promise((_, reject) => setTimeout(() => reject(new Error('timeout')), 3500)),
        ]);
      } catch (e) {
        return (await caches.match(abs('./'))) || (await caches.match(abs('index.html'))) || Response.error();
      }
    })());
    return;
  }

  event.respondWith((async () => {
    const hit = await caches.match(request, { ignoreSearch: true });
    if (hit && precached.has(url.origin + url.pathname)) return hit; // versioned with BUILD
    const refresh = fromNetwork(request, CACHE).catch(() => hit || Response.error());
    return hit || refresh; // stale-while-revalidate for everything else
  })());
});

// The page reports the files it loaded on first start (before this worker
// controlled it), e.g. the renderer for this browser, so they work offline too.
self.addEventListener('message', (event) => {
  const urls = (event.data && event.data.cache) || [];
  event.waitUntil((async () => {
    const cache = await caches.open(CACHE);
    for (const u of urls) {
      const url = new URL(u, scope);
      if (url.origin !== self.location.origin || (await cache.match(url.href, { ignoreSearch: true }))) continue;
      try {
        const res = await fetch(url.href);
        if (res.ok) await cache.put(url.href, res);
      } catch (e) {}
    }
  })());
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil((async () => {
    const all = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
    if (all.length) return all[0].focus();
    return self.clients.openWindow(scope);
  })());
});
