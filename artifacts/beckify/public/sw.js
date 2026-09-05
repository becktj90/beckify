/* ============================================================================
   ROOT SERVICE WORKER — offline app shell for the React site
   ============================================================================
   Scope is / but this worker only acts on the React shell itself. It bails
   out immediately on /toolbox/, /games/, /projects/, /demos/, and /arcade/
   so it never competes with the toolbox's own service worker (scoped to
   /toolbox/) and never caches static game/project content that changes
   independently of this app's deploys.

   No build-time asset list: Vite content-hashes every JS/CSS chunk, so
   stale-while-revalidate on same-origin GETs is enough — each hashed file
   is immutable once fetched, and a changed deploy simply requests new
   hashed filenames the next time a route is visited.

   Navigations are network-first so a returning visitor never gets stuck on
   a stale shell; the cached index.html is only a fallback for being offline.

   CACHE_VERSION must be bumped whenever this file's caching logic changes.
   ============================================================================ */

const CACHE_VERSION = 'v2';
const SHELL_CACHE = 'beckify-shell-' + CACHE_VERSION;

const EXCLUDED_PREFIXES = ['/toolbox/', '/games/', '/projects/', '/demos/', '/arcade/'];

function isExcluded(pathname) {
  return EXCLUDED_PREFIXES.some(function (p) { return pathname.indexOf(p) === 0; });
}

self.addEventListener('install', function (event) {
  event.waitUntil(
    caches.open(SHELL_CACHE).then(function (cache) {
      return cache.add(new Request('/', { cache: 'reload' })).catch(function () {});
    }).then(function () { return self.skipWaiting(); })
  );
});

self.addEventListener('activate', function (event) {
  event.waitUntil(
    caches.keys().then(function (keys) {
      return Promise.all(keys.map(function (k) {
        if (k !== SHELL_CACHE && k.indexOf('beckify-shell-') === 0) {
          return caches.delete(k);
        }
        return null;
      }));
    }).then(function () { return self.clients.claim(); })
  );
});

function networkFirst(request) {
  return fetch(request).then(function (response) {
    if (response && response.ok) {
      const copy = response.clone();
      caches.open(SHELL_CACHE).then(function (c) { c.put(request, copy); });
    }
    return response;
  }).catch(function () {
    return caches.match(request).then(function (hit) {
      return hit || caches.match('/');
    });
  });
}

function staleWhileRevalidate(request) {
  return caches.open(SHELL_CACHE).then(function (cache) {
    return cache.match(request).then(function (hit) {
      const network = fetch(request).then(function (response) {
        if (response && response.ok) cache.put(request, response.clone());
        return response;
      }).catch(function () { return hit; });
      return hit || network;
    });
  });
}

self.addEventListener('fetch', function (event) {
  const request = event.request;
  if (request.method !== 'GET') return;

  let url;
  try { url = new URL(request.url); } catch (_) { return; }
  if (url.origin !== self.location.origin) return;
  if (isExcluded(url.pathname)) return;

  if (request.mode === 'navigate') {
    event.respondWith(networkFirst(request));
    return;
  }

  event.respondWith(staleWhileRevalidate(request));
});
