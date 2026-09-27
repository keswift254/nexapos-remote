const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

function harness(fail = false) {
  const events = {}, writes = [], requests = [], replies = [];
  const source = fs.readFileSync('web/nexapos_service_worker.js', 'utf8')
    .replace('/*NEXAPOS_PRECACHE*/[]', '["./index.html", "./main.dart.js"]');
  vm.runInNewContext(source, {
    URL, Request, setTimeout, console,
    self: {location: {href: 'https://example.test/app/nexapos_service_worker.js'},
      registration: {scope: 'https://example.test/app/'},
      addEventListener: (name, handler) => events[name] = handler},
    caches: {open: async name => { assert.match(name, /^nexapos-web-/); return {put: async request => writes.push(request.url)}; }},
    fetch: async (request, options) => {
      requests.push({url: request.url, cache: options.cache});
      return {ok: !(fail && request.url.endsWith('main.dart.js')), status: fail ? 503 : 200};
    },
  });
  return {writes, requests, replies, refresh: () => new Promise((resolve, reject) => events.message({
    data: {type: 'NEXAPOS_REFRESH'}, ports: [{postMessage: value => replies.push(value)}],
    waitUntil: work => work.then(resolve, reject),
  }))};
}

test('explicit update bypasses HTTP cache and replaces only application assets', async () => {
  const h = harness(); await h.refresh();
  assert.equal(h.requests.length, 2);
  assert.ok(h.requests.every(r => r.cache === 'no-store'));
  assert.equal(h.writes.length, 2);
  assert.equal(h.replies[0].ok, true);
});

test('failed download retains existing offline assets and reports a retryable error', async () => {
  const h = harness(true); await h.refresh();
  assert.equal(h.writes.length, 0);
  assert.equal(h.replies[0].ok, false);
});
