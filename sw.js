const CACHE_PREFIX = 'cruisecrew-cache';
const DEFAULT_VERSION = 'unversioned';
let activeCacheName = `${CACHE_PREFIX}-${DEFAULT_VERSION}`;

async function getFreshAppVersion() {
  try {
    const res = await fetch(`/version.json?t=${Date.now()}`, { cache: 'no-store' });
    if (!res.ok) throw new Error(`version fetch failed (${res.status})`);
    const data = await res.json();
    return String(data.version || DEFAULT_VERSION).trim().replace(/^v/i, '') || DEFAULT_VERSION;
  } catch (err) {
    console.warn('CruiseCrew service worker version fetch failed', err);
    return DEFAULT_VERSION;
  }
}

function isNavigationRequest(request) {
  return request.mode === 'navigate' || (request.headers.get('accept') || '').includes('text/html');
}

function shouldAlwaysFetchFresh(url) {
  return url.origin === self.location.origin && (
    url.pathname === '/' ||
    url.pathname === '/index.html' ||
    url.pathname === '/version.json' ||
    url.pathname === '/manifest.webmanifest' ||
    url.pathname === '/manifest.json' ||
    url.pathname === '/sw.js' ||
    url.pathname === '/service-worker.js'
  );
}

function isLongLivedStaticAsset(url) {
  return url.origin === self.location.origin && /\.(?:png|jpg|jpeg|gif|webp|svg|ico)$/i.test(url.pathname);
}

self.addEventListener('install', event => {
  event.waitUntil((async () => {
    const version = await getFreshAppVersion();
    activeCacheName = `${CACHE_PREFIX}-${version}`;
    console.log('CruiseCrew service worker installing', { version, cache: activeCacheName });
  })());
});


self.addEventListener('message', event => {
  if (event.data && event.data.type === 'SKIP_WAITING') {
    self.skipWaiting();
  }
});

self.addEventListener('activate', event => {
  event.waitUntil((async () => {
    const version = await getFreshAppVersion();
    activeCacheName = `${CACHE_PREFIX}-${version}`;
    const keys = await caches.keys();
    await Promise.all(keys.map(key => {
      if (key.startsWith(CACHE_PREFIX) && key !== activeCacheName) {
        console.log('CruiseCrew old caches deleted', key);
        return caches.delete(key);
      }
      return Promise.resolve(false);
    }));
    await self.clients.claim();
    console.log('CruiseCrew new service worker activated', { version, cache: activeCacheName });
  })());
});

self.addEventListener('fetch', event => {
  const { request } = event;
  if (request.method !== 'GET') return;

  const url = new URL(request.url);

  if (isNavigationRequest(request) || shouldAlwaysFetchFresh(url)) {
    event.respondWith(fetch(request, { cache: 'no-store' }).catch(() => caches.match('/index.html')));
    return;
  }

  if (isLongLivedStaticAsset(url)) {
    event.respondWith((async () => {
      const cache = await caches.open(activeCacheName);
      const cached = await cache.match(request);
      if (cached) return cached;
      const response = await fetch(request);
      if (response.ok) cache.put(request, response.clone());
      return response;
    })());
  }
});

// Push notification handlers are intentionally not defined here. If/when the
// push notification PR adds push, notificationclick, or subscription logic,
// keep those handlers alongside this cache/update logic instead of replacing it.
