const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

const tick = (ms = 0) => new Promise(resolve => setTimeout(resolve, ms));

// ---------------------------------------------------------------------------------------------
// The service worker (web/nexapos_service_worker.js)
// ---------------------------------------------------------------------------------------------

class FakeRequest {
  constructor(url, init = {}) { this.url = new URL(String(url), 'https://example.test/app/').toString(); this.cache = init.cache; }
}

// A response whose body arrives in two chunks, so byte counting has something to count.
function fakeResponse(size, ok = true) {
  const make = () => ({
    ok, status: ok ? 200 : 503, clone: make,
    body: {getReader() {
      const chunks = [Math.floor(size / 2), size - Math.floor(size / 2)]; let i = 0;
      return {read: async () => i < chunks.length ? {done: false, value: {length: chunks[i++]}} : {done: true}};
    }},
  });
  return make();
}

function workerHarness({files = [['./index.html', 100], ['./main.dart.js', 300]], cached = [], failing = {}, version = 'v1'} = {}) {
  const events = {}, requests = [], broadcasts = [], replies = [], store = new Map(), state = {skipWaiting: 0};
  const cacheNamed = name => { if (!store.has(name)) store.set(name, new Map()); return store.get(name); };
  const key = request => new URL(request.url || request).pathname;
  const cacheApi = name => { const map = cacheNamed(name); return {
    put: async (request, response) => { await new Promise(r => setTimeout(r, 0)); map.set(key(request), response); },
    match: async request => map.get(key(request)),
  }; };
  for (const url of cached) cacheNamed('nexapos-web-' + version).set(new URL(url, 'https://example.test/app/').pathname, {marker: 'old', ok: true});
  const source = fs.readFileSync('web/nexapos_service_worker.js', 'utf8')
    .replace('/*NEXAPOS_PRECACHE*/[]', JSON.stringify(files.map(f => f[0])))
    .replace('/*NEXAPOS_PRECACHE_BYTES*/[]', JSON.stringify(files.map(f => f[1])))
    .replace('/*NEXAPOS_CACHE_VERSION*/', version);
  vm.runInNewContext(source, {
    URL, Request: FakeRequest, setTimeout, console, Date, Promise, Number, Math,
    self: {
      location: {href: 'https://example.test/app/nexapos_service_worker.js', origin: 'https://example.test'},
      registration: {scope: 'https://example.test/app/'},
      addEventListener: (name, handler) => events[name] = handler,
      skipWaiting: async () => { state.skipWaiting++; },
      clients: {matchAll: async () => [{postMessage: message => broadcasts.push(message)}], claim: async () => {}},
    },
    caches: {
      open: async name => { assert.match(name, /^nexapos-web-/); return cacheApi(name); },
      delete: async name => store.delete(name),
      keys: async () => [...store.keys()],
    },
    fetch: async (request, options) => {
      const path = new URL(request.url).pathname;
      requests.push({path, cache: options && options.cache});
      failing[path] = failing[path] || 0;
      const planned = failing[path];
      if (planned === 'always' || planned > 0) { if (planned !== 'always') failing[path] -= 1; return fakeResponse(1, false); }
      return fakeResponse(files.find(f => new URL(f[0], 'https://example.test/app/').pathname === path)[1]);
    },
  });
  // Resolves when the worker says its work is done (waitUntil), or - for a message it answers
  // straight away without any work - after the answer was posted.
  const message = (data) => new Promise((resolve, reject) => {
    let kept = false;
    events.message({
      data, ports: [{postMessage: value => replies.push(value)}],
      waitUntil: work => { kept = true; work.then(resolve, reject); },
    });
    if (!kept) setTimeout(resolve, 0);
  });
  return {
    store, requests, broadcasts, replies, state, events,
    realCache: () => cacheNamed('nexapos-web-' + version),
    install: () => new Promise((resolve, reject) => events.install({waitUntil: work => work.then(resolve, reject)})),
    refresh: (data = {}) => message({type: 'NEXAPOS_REFRESH', ...data}),
    ask: data => message(data),
  };
}

test('installing reports real, byte-weighted progress, and never says 100% by itself', async () => {
  const h = workerHarness();
  await h.install();
  const fractions = h.broadcasts.map(m => m.fraction);
  assert.ok(h.broadcasts.every(m => m.type === 'NEXAPOS_PROGRESS'));
  assert.deepEqual(fractions.slice(0, 2), [0, 0.25], 'index.html is 100 of 400 bytes');
  assert.ok(fractions.at(-1) < 1 && fractions.at(-1) >= 0.9, 'the last file done is still just under 100%');
  assert.deepEqual(fractions, [...fractions].sort((a, b) => a - b), 'only ever forward');
  assert.equal(h.broadcasts.at(-1).files, 2);
  assert.equal(h.broadcasts.at(-1).totalFiles, 2);
  assert.equal(h.realCache().size, 2);
  assert.equal(h.state.skipWaiting, 1, 'takes over once everything is cached');
});

test('installing without file sizes still reports progress, by file count', async () => {
  const h = workerHarness({files: [['./a.js', 0], ['./b.js', 0], ['./c.js', 0], ['./d.js', 0]]});
  await h.install();
  assert.deepEqual(h.broadcasts.slice(0, 3).map(m => m.fraction), [0, 0.25, 0.5]);
});

test('a file that fails once is retried and the install still completes', async () => {
  const h = workerHarness({failing: {'/app/main.dart.js': 1}});
  await h.install();
  assert.equal(h.requests.filter(r => r.path.endsWith('main.dart.js')).length, 2);
  assert.equal(h.realCache().size, 2);
  assert.equal(h.state.skipWaiting, 1);
});

test('a file that keeps failing fails the install, so the old version stays in charge', async () => {
  const h = workerHarness({failing: {'/app/main.dart.js': 'always'}});
  await assert.rejects(h.install(), /HTTP 503/);
  assert.equal(h.state.skipWaiting, 0);
});

test('the worker says which build it is', async () => {
  const h = workerHarness({version: 'abc123'});
  await h.ask({type: 'NEXAPOS_VERSION'});
  assert.equal(h.replies.length, 1);
  assert.equal(h.replies[0].version, 'abc123');
});

test('a full refresh bypasses the HTTP cache, reports progress, and replaces the files at the end', async () => {
  const h = workerHarness({cached: ['./index.html', './main.dart.js']});
  await h.refresh();
  assert.equal(h.requests.length, 2);
  assert.ok(h.requests.every(r => r.cache === 'no-store'));
  const progress = h.replies.filter(r => r.type === 'progress').map(r => r.fraction);
  assert.deepEqual(progress.slice(0, 2), [0, 0.25]);
  assert.equal(h.replies.at(-1).ok, true);
  assert.ok([...h.realCache().values()].every(r => r.marker !== 'old'), 'both files were replaced');
  assert.deepEqual([...h.store.keys()], ['nexapos-web-v1'], 'the staging cache is gone');
});

test('a failed full refresh leaves every existing file in place and reports a retryable error', async () => {
  const h = workerHarness({cached: ['./index.html', './main.dart.js'], failing: {'/app/main.dart.js': 'always'}});
  await h.refresh();
  assert.equal(h.replies.at(-1).ok, false);
  assert.ok([...h.realCache().values()].every(r => r.marker === 'old'), 'nothing was replaced');
  assert.deepEqual([...h.store.keys()], ['nexapos-web-v1'], 'the staging cache is gone');
});

test('refreshing only what is missing fetches just the files the browser evicted', async () => {
  const h = workerHarness({cached: ['./index.html']});
  await h.refresh({missingOnly: true});
  assert.deepEqual(h.requests.map(r => r.path), ['/app/main.dart.js']);
  assert.equal(h.realCache().size, 2);
  assert.equal(h.realCache().get('/app/index.html').marker, 'old', 'what was already there is kept');
  assert.equal(h.replies.at(-1).ok, true);
});

test('refreshing only what is missing downloads nothing when nothing is missing', async () => {
  const h = workerHarness({cached: ['./index.html', './main.dart.js']});
  await h.refresh({missingOnly: true});
  assert.equal(h.requests.length, 0);
  assert.equal(h.replies.at(-1).ok, true);
});

test("the worker's own script is never served from the cache", async () => {
  const h = workerHarness({cached: ['./index.html']});
  let answered = 0;
  h.events.fetch({
    request: {method: 'GET', url: 'https://example.test/app/nexapos_service_worker.js?canvaskit=plain', mode: 'same-origin'},
    respondWith: () => { answered++; },
  });
  assert.equal(answered, 0, 'the network answers, so a page can see whether a newer build exists');
  h.events.fetch({
    request: {method: 'GET', url: 'https://example.test/app/index.html', mode: 'same-origin'},
    respondWith: () => { answered++; },
  });
  assert.equal(answered, 1, 'ordinary files still come from the cache');
});

// ---------------------------------------------------------------------------------------------
// The page script (window.nexaPOSUpdate in web/index.html)
// ---------------------------------------------------------------------------------------------

const pageSource = (() => {
  const html = fs.readFileSync('web/index.html', 'utf8');
  const block = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].map(m => m[1]).find(s => s.includes('window.nexaPOSUpdate = '));
  assert.ok(block, 'index.html has the update script');
  return block;
})();

class FakeChannel {
  constructor() {
    this.port1 = {close() {}};
    this.port2 = {postMessage: value => setTimeout(() => this.port1.onmessage && this.port1.onmessage({data: value}), 0)};
  }
}

function fakeWorker(state, options) {
  const {version = 'abc', refreshProgress = [], refreshReply = {ok: true}} = options;
  return {
    scriptURL: 'https://example.test/app/nexapos_service_worker.js?canvaskit=plain',
    postMessage(message, [port]) {
      state.sent.push(message);
      if (message.type === 'NEXAPOS_VERSION') port.postMessage({version});
      if (message.type === 'NEXAPOS_REFRESH') {
        for (const fraction of refreshProgress) port.postMessage({type: 'progress', fraction});
        port.postMessage(refreshReply);
      }
    },
  };
}

function pageHarness(options = {}) {
  const {servedVersion = 'abc', serveStatus = 200, updateError = null, noRegistration = false,
    installing = null, noServiceWorker = false, stallMs = 5000} = options;
  const state = {sent: [], replaced: [], updates: 0, progress: [], swListeners: new Set()};
  const registration = {
    active: fakeWorker(state, options), installing: null, waiting: null,
    update: async () => { state.updates++; if (updateError) throw updateError; if (installing) registration.installing = installing; },
  };
  const serviceWorker = {
    getRegistration: async () => noRegistration ? undefined : registration,
    addEventListener: (name, fn) => name === 'message' && state.swListeners.add(fn),
    removeEventListener: (name, fn) => name === 'message' && state.swListeners.delete(fn),
    startMessages() {},
  };
  const sandbox = {
    URL, setTimeout, clearTimeout, Date, Promise, Set, Error, Error, console,
    MessageChannel: FakeChannel,
    navigator: noServiceWorker ? {} : {serviceWorker},
    location: {href: 'https://example.test/app/?x=1', replace: href => state.replaced.push(href)},
    fetch: async () => ({ok: serveStatus === 200, status: serveStatus, text: async () => `const CACHE_NAME = CACHE_PREFIX + '${servedVersion}';`}),
  };
  sandbox.window = sandbox;
  sandbox.NEXAPOS_UPDATE_STALL_MS = stallMs;
  sandbox.NEXAPOS_UPDATE_RESTART_MS = 20;
  vm.createContext(sandbox);
  vm.runInContext(pageSource, sandbox);
  return {
    state, registration, sandbox,
    update: () => sandbox.nexaPOSUpdate((fraction, phrase) => state.progress.push([fraction, phrase])),
    tellPage: data => state.swListeners.forEach(fn => fn({data})),
  };
}

function fakePending() {
  const listeners = new Set();
  return {
    state: 'installing',
    addEventListener: (name, fn) => listeners.add(fn),
    removeEventListener: (name, fn) => listeners.delete(fn),
    become(next) { this.state = next; [...listeners].forEach(fn => fn()); },
    get listeners() { return listeners.size; },
  };
}

test('a newer build: waits for it to install, shows its progress, downloads nothing a second time, then restarts', async () => {
  const pending = fakePending();
  const h = pageHarness({installing: pending});
  const run = h.update();
  await tick(5);
  h.tellPage({type: 'NEXAPOS_PROGRESS', fraction: 0.3});
  h.tellPage({type: 'NEXAPOS_PROGRESS', fraction: 0.8});
  await tick(2);
  pending.become('activated');
  const outcome = await run;
  assert.deepEqual(h.state.progress.map(p => p[0]), [-1, 0, 0.3, 0.8, 1]);
  assert.equal(h.state.progress.at(-1)[1], 'Restarting…');
  assert.equal(h.state.sent.length, 0, 'the new worker already cached everything: no refresh message, no second download');
  assert.equal(h.state.replaced.length, 1);
  assert.match(h.state.replaced[0], /updated=\d+/);
  assert.match(h.state.replaced[0], /x=1/, 'the rest of the address is kept');
  assert.match(outcome, /reload this page/, 'the fake page never actually restarts, so it says so');
  assert.equal(pending.listeners, 0);
  assert.equal(h.state.swListeners.size, 0, 'nothing left listening');
});

test('no newer worker but the one running is the newest: only evicted files are fetched, then it restarts', async () => {
  const h = pageHarness({servedVersion: 'abc', version: 'abc', refreshProgress: [0.5]});
  await h.update();
  assert.deepEqual(h.state.sent.map(m => m.type), ['NEXAPOS_VERSION', 'NEXAPOS_REFRESH']);
  assert.equal(h.state.sent[1].missingOnly, true);
  assert.deepEqual(h.state.progress.map(p => p[0]), [-1, 0, 0.5, 1]);
  assert.equal(h.state.replaced.length, 1);
});

test('no newer worker found, but the server has a different build (a browser that missed the update): every file is downloaded again', async () => {
  const h = pageHarness({servedVersion: 'newer', version: 'old'});
  await h.update();
  assert.equal(h.state.sent[1].type, 'NEXAPOS_REFRESH');
  assert.equal(h.state.sent[1].missingOnly, false);
  assert.equal(h.state.replaced.length, 1);
});

test('a download that does not finish says so and does not restart the page', async () => {
  const h = pageHarness({refreshReply: {ok: false, error: 'HTTP 503'}});
  const outcome = await h.update();
  assert.match(outcome, /did not finish/);
  assert.equal(h.state.replaced.length, 0);
});

test('an unreachable server says so', async () => {
  const offline = pageHarness({updateError: new TypeError('network error')});
  assert.match(await offline.update(), /Could not reach the update server/);
  const noScript = pageHarness({serveStatus: 404});
  assert.match(await noScript.update(), /Could not reach the update server/);
  assert.equal(offline.state.replaced.length + noScript.state.replaced.length, 0);
});

test('a download that goes quiet is given up on, not waited for forever', async () => {
  const pending = fakePending();
  const h = pageHarness({installing: pending, stallMs: 30});
  const run = h.update();
  await tick(5);
  h.tellPage({type: 'NEXAPOS_PROGRESS', fraction: 0.2});
  const outcome = await run;
  assert.match(outcome, /download stopped/);
  assert.equal(h.state.replaced.length, 0);
  assert.equal(pending.listeners, 0);
});

test('every sign of progress keeps a slow download alive', async () => {
  const pending = fakePending();
  const h = pageHarness({installing: pending, stallMs: 60});
  const run = h.update();
  await tick(5);
  for (let i = 1; i <= 5; i++) { await tick(30); h.tellPage({type: 'NEXAPOS_PROGRESS', fraction: i / 10}); }
  pending.become('activated');
  await run;
  assert.equal(h.state.replaced.length, 1, 'took 150 ms against a 60 ms patience, because it kept reporting');
});

test('an install that fails (the worker became redundant) says so', async () => {
  const pending = fakePending();
  const h = pageHarness({installing: pending});
  const run = h.update();
  await tick(5);
  pending.become('redundant');
  assert.match(await run, /could not be installed/);
  assert.equal(h.state.replaced.length, 0);
});

test('asking twice joins the running update: one download, and the second listener is caught up', async () => {
  const pending = fakePending();
  const h = pageHarness({installing: pending});
  const first = h.update();
  await tick(5);
  h.tellPage({type: 'NEXAPOS_PROGRESS', fraction: 0.6});
  const second = [];
  const joined = h.sandbox.nexaPOSUpdate((fraction, phrase) => second.push(fraction));
  assert.equal(joined, first, 'the very same run');
  assert.deepEqual(second, [0.6], 'told at once how far it has got');
  h.tellPage({type: 'NEXAPOS_PROGRESS', fraction: 0.9});
  pending.become('activated');
  await first;
  assert.equal(h.state.updates, 1, 'the browser was asked for a new worker once');
  assert.equal(h.state.replaced.length, 1);
  assert.deepEqual(second.slice(0, 2), [0.6, 0.9]);
});

test('after a failure a new update can be started', async () => {
  const h = pageHarness({updateError: new TypeError('network error')});
  await h.update();
  await h.update();
  assert.equal(h.state.updates, 2);
});

test('before the offline worker exists, or in a browser without one, it says what to do', async () => {
  assert.match(await pageHarness({noRegistration: true}).update(), /still getting ready/);
  assert.match(await pageHarness({noServiceWorker: true}).update(), /Reload the page/);
});
