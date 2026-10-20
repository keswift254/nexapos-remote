const CACHE_PREFIX = 'nexapos-web-';
const CACHE_NAME = CACHE_PREFIX + '/*NEXAPOS_CACHE_VERSION*/';
const PRECACHE_URLS = /*NEXAPOS_PRECACHE*/[];
// The size in bytes of each file in PRECACHE_URLS, same order: lets a download report real progress.
const PRECACHE_BYTES = /*NEXAPOS_PRECACHE_BYTES*/[];
const INDEX_URL = new URL('index.html', self.registration.scope).toString();

// index.html registers this worker as nexapos_service_worker.js?canvaskit=chromium (or =plain)
// after seeing which CanvasKit build this browser actually loaded. The other build is ~5-7 MB
// this browser will never use, so it is not downloaded. With no hint, both are cached.
const CANVASKIT_BUILD = new URL(self.location.href).searchParams.get('canvaskit');
const PRECACHE_ENTRIES = PRECACHE_URLS
  .map((url, index) => ({ url, bytes: Number(PRECACHE_BYTES[index]) || 0 }))
  .filter(({ url }) => {
    if (CANVASKIT_BUILD === 'chromium') return !url.startsWith('./canvaskit/canvaskit.');
    if (CANVASKIT_BUILD === 'plain') return !url.startsWith('./canvaskit/chromium/');
    return true;
  });
const PRECACHE_FOR_THIS_BROWSER = PRECACHE_ENTRIES.map((entry) => entry.url);

// Reports how far a download of `entries` has got, 0..1 (never 1 until the caller finishes),
// weighted by file size when every size is known and by file count otherwise. Sends at most
// ~8 updates a second; a finished file is always reported.
function progressReporter(entries, send) {
  const totalBytes = entries.reduce((sum, entry) => sum + entry.bytes, 0);
  const bySize = totalBytes > 0 && entries.every((entry) => entry.bytes > 0);
  let finishedBytes = 0;
  let finishedFiles = 0;
  let lastSent = 0;
  function fraction(currentBytes) {
    if (entries.length === 0) return 0;
    const value = bySize ? (finishedBytes + currentBytes) / totalBytes : finishedFiles / entries.length;
    return Math.max(0, Math.min(0.99, value));
  }
  function emit(currentBytes) {
    lastSent = Date.now();
    send({ fraction: fraction(currentBytes), files: finishedFiles, totalFiles: entries.length });
  }
  return {
    start() { emit(0); },
    loaded(currentBytes) { if (Date.now() - lastSent >= 120) emit(currentBytes); },
    fileDone(entry) { finishedBytes += entry.bytes; finishedFiles += 1; emit(0); },
  };
}

// Tells every open page how the install is going (the page that asked for an update shows it).
async function broadcast(message) {
  try {
    if (!self.clients || !self.clients.matchAll) return;
    const clients = await self.clients.matchAll({ includeUncontrolled: true, type: 'window' });
    for (const client of clients) client.postMessage(message);
  } catch (_) {
    // Progress is a courtesy; it must never fail an install.
  }
}

// Counts the bytes of a copy of the response as they arrive. Whether the download worked is
// decided by the cache write alone, so a failure here is ignored.
async function countBytes(response, onBytes) {
  try {
    const reader = response.body && response.body.getReader && response.body.getReader();
    if (!reader) return;
    let loaded = 0;
    for (;;) {
      const { done, value } = await reader.read();
      if (done) return;
      loaded += value.length;
      onBytes(loaded);
    }
  } catch (_) {
    // see above
  }
}

async function fetchIntoCache(cache, request, onBytes, fetchOptions) {
  const response = await fetch(request, fetchOptions);
  if (!response || !response.ok) throw new Error(`HTTP ${response && response.status}`);
  const counting = countBytes(response.clone(), onBytes);
  await cache.put(request, response);
  await counting;
}

async function precacheApplication() {
  const cache = await caches.open(CACHE_NAME);
  const progress = progressReporter(PRECACHE_ENTRIES, (update) => broadcast({ type: 'NEXAPOS_PROGRESS', ...update }));
  progress.start();
  // WebKit can abort one request in an otherwise healthy batch. Cache each
  // file independently and retry transient failures, preserving every file
  // that already succeeded instead of rolling the whole batch back.
  for (const entry of PRECACHE_ENTRIES) {
    let lastError;
    for (let attempt = 1; attempt <= 3; attempt++) {
      try {
        const request = new Request(entry.url, { cache: 'no-cache' });
        await fetchIntoCache(cache, request, (bytes) => progress.loaded(bytes));
        lastError = null;
        break;
      } catch (error) {
        lastError = error;
        if (attempt < 3) {
          await new Promise((resolve) => setTimeout(resolve, attempt * 350));
        }
      }
    }
    if (lastError) throw lastError;
    progress.fileDone(entry);
  }
  await self.skipWaiting();
}

self.addEventListener('install', (event) => {
  event.waitUntil(precacheApplication());
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    const names = await caches.keys();
    await Promise.all(names
      .filter((name) => name.startsWith(CACHE_PREFIX) && name !== CACHE_NAME)
      .map((name) => caches.delete(name)));
    await self.clients.claim();
  })());
});

async function fetchNavigation(request) {
  try {
    const response = await Promise.race([
      fetch(request, { cache: 'no-store' }),
      new Promise((_, reject) => setTimeout(() => reject(new Error('offline')), 3000)),
    ]);
    if (response && response.ok) {
      const cache = await caches.open(CACHE_NAME);
      await cache.put(INDEX_URL, response.clone());
    }
    return response;
  } catch (_) {
    const cached = await caches.match(INDEX_URL, { ignoreSearch: true });
    if (cached) return cached;
    throw _;
  }
}

async function fetchApplicationFile(request) {
  const cache = await caches.open(CACHE_NAME);
  const cached = await cache.match(request, { ignoreSearch: true });
  if (cached) return cached;

  const response = await fetch(request);
  if (response && response.ok) {
    const cache = await caches.open(CACHE_NAME);
    await cache.put(request, response.clone());
  }
  return response;
}

self.addEventListener('fetch', (event) => {
  if (event.request.method !== 'GET') return;
  const url = new URL(event.request.url);
  if (url.origin !== self.location.origin) return;
  // The worker's own script always comes from the network: the page reads it to learn whether
  // the server has a newer build than this one, and a cached copy would answer "no" forever.
  if (url.pathname.endsWith('/nexapos_service_worker.js')) return;

  event.respondWith(
    event.request.mode === 'navigate'
      ? fetchNavigation(event.request)
      : fetchApplicationFile(event.request),
  );
});

// An explicit "update now" from the page.
//   NEXAPOS_VERSION  -> replies { version } : which build this worker is.
//   NEXAPOS_REFRESH  -> downloads the application files again, replying { type: 'progress',
//     fraction } as it goes and { ok } at the end. { missingOnly: true } only fetches files
//     this cache does not have (a browser may evict some); otherwise every file is fetched
//     again, bypassing the HTTP cache, into a staging cache that replaces the real entries
//     only once ALL of it has arrived, so a failed or offline update leaves the existing
//     offline application usable.
// IndexedDB/OPFS (shop data), preferences and credentials are never touched.
self.addEventListener('message', (event) => {
  const type = event.data && event.data.type;
  const port = event.ports && event.ports[0];
  if (type === 'NEXAPOS_VERSION') {
    if (port) port.postMessage({ version: CACHE_NAME.slice(CACHE_PREFIX.length) });
    return;
  }
  if (type !== 'NEXAPOS_REFRESH') return;
  const missingOnly = event.data.missingOnly === true;
  event.waitUntil((async () => {
    const stagingName = CACHE_NAME + '-staging';
    try {
      const cache = await caches.open(CACHE_NAME);
      const todo = [];
      for (const entry of PRECACHE_ENTRIES) {
        const request = new Request(new URL(entry.url, self.registration.scope));
        if (missingOnly && await cache.match(request, { ignoreSearch: true })) continue;
        todo.push({ entry, request });
      }
      const progress = progressReporter(
        todo.map((item) => item.entry),
        (update) => { if (port) port.postMessage({ type: 'progress', fraction: update.fraction }); },
      );
      progress.start();
      const target = missingOnly ? cache : await caches.open(stagingName);
      for (const { entry, request } of todo) {
        await fetchIntoCache(target, request, (bytes) => progress.loaded(bytes), { cache: 'no-store' });
        progress.fileDone(entry);
      }
      if (!missingOnly) {
        for (const { request } of todo) await cache.put(request, await target.match(request));
      }
      if (port) port.postMessage({ ok: true });
    } catch (error) {
      if (port) port.postMessage({ ok: false, error: String(error) });
    } finally {
      if (!missingOnly) await caches.delete(stagingName);
    }
  })());
});
