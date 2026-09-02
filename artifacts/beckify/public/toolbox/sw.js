/* ============================================================================
   TOOLBOX SERVICE WORKER — offline app shell
   ============================================================================
   The toolbox is the part of the site that most needs to work without a
   network: it is used in plant rooms, switchgear rooms and job sites, and its
   saved jobs already live in IndexedDB on the device. Without a service worker
   that local data was unreachable the moment the page itself failed to load.

   Scope is /toolbox/ because this file sits there, so the React site at / is
   untouched by it.

   Strategies, and why:

     navigations      network-first, falling back to the cached shell. The
                      toolbox is one HTML file that changes on every deploy, so
                      serving a cached copy first would strand users on an old
                      build until they hard-refreshed.

     same-origin GET  stale-while-revalidate. CSS/JS are served from cache for
                      an instant load and refreshed in the background, so an
                      update lands on the next visit without ever leaving the
                      user offline-broken in between.

     cross-origin     cache-first, network fallback, opaque responses kept,
                      but only for an allow-list of CDNs (jsDelivr, Google
                      Fonts, GA). jsPDF is still lazy-loaded from a CDN on
                      first use. Local Tesseract OCR files (~18 MB) are also
                      runtime-cached on first Read-nameplate / panel-photo
                      use — they are not in the install SHELL, so visitors
                      who never run OCR do not download them at install.
                      Unknown hosts are not intercepted.

   CACHE_VERSION must be bumped whenever a precached file changes, otherwise
   returning visitors keep the old shell until the browser evicts it.
   ============================================================================ */

const CACHE_VERSION = 'v21';
const SHELL_CACHE = 'toolbox-shell-' + CACHE_VERSION;
const RUNTIME_CACHE = 'toolbox-runtime-' + CACHE_VERSION;
const RUNTIME_HOST_ALLOWLIST = [
  'cdn.jsdelivr.net',
  'fonts.googleapis.com',
  'fonts.gstatic.com',
  'www.googletagmanager.com',
  'www.google-analytics.com',
  'region1.google-analytics.com',
];

const SHELL = [
  './',
  './index.html',
  './manifest.json',
  './panel-schedule.html',
  './panel-power-study.html',
  './css/styles.css',
  './css/panel-schedule.css',
  './js/vendor/solver.js',
  './js/nec-data.js',
  './js/app.js',
  './js/wire-tools.js',
  './js/power-tools.js',
  './js/factor-tools.js',
  './js/xfmr-engine.js',
  './js/heater-wizard.js',
  './js/timer555.js',
  './js/report-export.js',
  './js/url-state.js',
  './js/tdr-analyzer.js',
  './js/local-store.js',
  './js/projects-ui.js',
  './js/arcade.js',
  './js/panel-schedule.js',
  './js/panel-power-study.js',
  './js/conduit-guide.js',
  './js/xfmr-wizard.js',
  './js/circuit-sim.js',
  './js/smith-chart.js',
  './js/emp-emc.js',
  './js/magnetic-circuit.js',
  './js/transient-circuits.js',
  './js/phasor-diagram.js',
  './js/semiconductor-iv.js',
  './js/fiber-link.js',
  './js/gaussian-beam.js',
  './js/stem-tools.js',
  './js/lp-optimizer.js',
  './js/base-converter.js',
  './js/io-list-generator.js',
  './js/signal-scaling.js',
  './js/ebus-budget.js',
  './js/modbus-address.js',
  './js/plc-timer-preset.js',
  './js/field-persist.js',
  './js/nema-wiring.js',
  './js/battery-bank.js',
  './js/cable-schedule.js',
  './js/ocr-helper.js',
  './js/motor-nameplate.js',
  './js/vendor/xlsx.full.min.js',
  './js/math-explanations.js',
  './js/analog-schematics.js',
  './js/analog-tools.js',
  './js/icons.js',
  './icons/icon-192.png',
  './icons/icon-512.png',
  './icons/icon-maskable-512.png',
];

self.addEventListener('install', function (event) {
  event.waitUntil(
    caches.open(SHELL_CACHE).then(function (cache) {
      // One missing file must not fail the whole install and leave the user
      // with no offline support at all, so each request is added on its own.
      return Promise.all(SHELL.map(function (url) {
        return cache.add(new Request(url, { cache: 'reload' })).catch(function () {});
      }));
    }).then(function () { return self.skipWaiting(); })
  );
});

self.addEventListener('activate', function (event) {
  event.waitUntil(
    caches.keys().then(function (keys) {
      return Promise.all(keys.map(function (k) {
        if (k !== SHELL_CACHE && k !== RUNTIME_CACHE && k.indexOf('toolbox-') === 0) {
          return caches.delete(k);
        }
        return null;
      }));
    }).then(function () { return self.clients.claim(); })
  );
});

self.addEventListener('message', function (event) {
  if (event.data === 'skip-waiting') self.skipWaiting();
});

function isSameOrigin(url) {
  return url.origin === self.location.origin;
}

/** Network-first: the freshest shell wins, the cache covers being offline. */
function networkFirst(request) {
  return fetch(request).then(function (response) {
    if (response && response.ok) {
      const copy = response.clone();
      caches.open(SHELL_CACHE).then(function (c) { c.put(request, copy); });
    }
    return response;
  }).catch(function () {
    return caches.match(request).then(function (hit) {
      return hit || caches.match('./index.html');
    });
  });
}

/** Serve from cache immediately, refresh in the background for next time. */
function staleWhileRevalidate(request, cacheName) {
  return caches.open(cacheName).then(function (cache) {
    return cache.match(request).then(function (hit) {
      const network = fetch(request).then(function (response) {
        if (response && (response.ok || response.type === 'opaque')) {
          cache.put(request, response.clone());
        }
        return response;
      }).catch(function () { return hit; });
      return hit || network;
    });
  });
}

/** Cache-first, for CDN libraries that are versioned and never change. */
function cacheFirst(request, cacheName) {
  return caches.open(cacheName).then(function (cache) {
    return cache.match(request).then(function (hit) {
      if (hit) return hit;
      return fetch(request).then(function (response) {
        if (response && (response.ok || response.type === 'opaque')) {
          cache.put(request, response.clone());
        }
        return response;
      });
    });
  });
}

function isTesseractAsset(url) {
  return url.pathname.indexOf('/toolbox/js/vendor/tesseract/') !== -1;
}

self.addEventListener('fetch', function (event) {
  const request = event.request;
  if (request.method !== 'GET') return;

  let url;
  try { url = new URL(request.url); } catch (_) { return; }

  // Only claim requests that belong to the toolbox; the rest of the site is
  // served normally even though this worker is registered in the same origin.
  if (isSameOrigin(url) && url.pathname.indexOf('/toolbox/') !== 0) return;

  if (request.mode === 'navigate') {
    event.respondWith(networkFirst(request));
    return;
  }

  if (isSameOrigin(url) && isTesseractAsset(url)) {
    event.respondWith(cacheFirst(request, RUNTIME_CACHE).catch(function () {
      return caches.match(request);
    }));
    return;
  }

  if (isSameOrigin(url)) {
    event.respondWith(staleWhileRevalidate(request, SHELL_CACHE));
    return;
  }

  if (RUNTIME_HOST_ALLOWLIST.indexOf(url.hostname) === -1) return;

  // Fonts and lazy-loaded libraries from known CDNs only.
  event.respondWith(cacheFirst(request, RUNTIME_CACHE).catch(function () {
    return caches.match(request);
  }));
});
