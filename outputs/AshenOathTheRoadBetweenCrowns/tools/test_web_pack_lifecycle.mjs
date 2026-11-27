// Run with node tools/test_web_pack_lifecycle.mjs.
import assert from 'node:assert/strict';
import { createHash, webcrypto } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { setTimeout as delay } from 'node:timers/promises';
import vm from 'node:vm';

const shell = readFileSync(new URL('../web_boot_shell.html', import.meta.url), 'utf8');
const packStart = shell.indexOf('      async function sha256Hex(');
const priorityStart = shell.indexOf('      let openingPrefetchQueue = [];');
const packOperations = shell.slice(packStart,
  shell.indexOf("      requestPack('opening', null, false, true);", packStart));
const priorities = shell.slice(priorityStart,
  shell.indexOf("      window.addEventListener('ashen-oath-menu-ready'", priorityStart));
assert(packOperations && priorities);

const origin = 'https://ashenoath.invalid';
const payload = Buffer.alloc(700 * 1024, 27);
const sha256 = value => createHash('sha256').update(value).digest('hex');
const digest = sha256(payload);
const manifest = { release_id: 'test', packs: {} };
for (const id of ['discard', 'promote', 'foreground']) {
  manifest.packs[id] = { url: `packs/${id}.pck?sha256=${digest}`, bytes: payload.length, sha256: digest, version: 'v' };
}
const artifacts = Object.values(manifest.packs).map(pack => ({
  path: pack.url.split('?')[0], bytes: pack.bytes, sha256: pack.sha256,
}));
const serializedManifest = JSON.stringify(manifest);
const release = { build_id: 'test', artifacts, runtime_pack_manifest: { sha256: sha256(serializedManifest) } };
const writes = [];
const mounts = [];
const window = {
  __ashenOathPreloadedPacks: {},
  location: { href: origin + '/', origin },
  crypto: webcrypto,
  setTimeout: (callback, ms) => setTimeout(callback, ms === 15000 ? 500 : ms),
  clearTimeout, setInterval, clearInterval,
};
const cache = {
  match: async () => undefined,
  keys: async () => [],
  put: (url, response) => new Promise((resolve, reject) => writes.push({ url, response, resolve, reject })),
};
window.caches = { open: async () => cache };
const context = vm.createContext({
  window, location: window.location, crypto: webcrypto, caches: window.caches, bootMetrics: {},
  SHELL_BUILD_ID: 'test', AbortController, ReadableStream, Response, URL, TextDecoder, performance, console,
  failed: false,
  engine: { supportsOwnedPackBuffers: true, copyToFS(path, bytes, own) { mounts.push({ path, bytes, own }); } },
  async fetch(url) {
    if (url === 'runtime_pack_manifest.json') return new Response(serializedManifest);
    if (url === 'release_manifest.json') return Response.json(release);
    return new Response(payload);
  },
});
vm.runInContext(`${packOperations}\n${priorities}\n
  window.testOperations = packOperations;
  window.testRequestBootstrap = id => requestPack(id, null, false, true);
  window.testFilesystemReady = () => filesystemReadyResolve(true);
`, context);

const state = id => window.__ashenOathPreloadedPacks[id]?.state;
async function waitFor(condition) {
  const end = performance.now() + 4000;
  while (!condition()) {
    assert(performance.now() < end, 'Pack lifecycle condition did not settle');
    await delay(5);
  }
}

assert(window.testRequestBootstrap('discard'));
await waitFor(() => state('discard') === 'verified');
const discard = window.testOperations.get('discard').promise;
assert.deepEqual(JSON.parse(window.__ashenOathPrioritizePacks(['opening'])), []);
assert.equal(await discard, null);
assert.equal(state('discard'), 'cancelled');
assert.equal(window.testOperations.size, 0);
assert.equal(mounts.length, 0);

assert(window.__ashenOathRequestPack('promote', digest, payload.length, 'v', true));
await waitFor(() => writes.length === 1);
const promote = window.testOperations.get('promote').promise;
assert(window.__ashenOathRequestPack('promote', digest, payload.length, 'v'));
const reader = writes[0].response.body.getReader();
const chunks = [];
for (let chunk = await reader.read(); !chunk.done; chunk = await reader.read()) {
  assert(chunk.value.byteLength <= 256 * 1024);
  chunks.push(Buffer.from(chunk.value));
}
assert.deepEqual(Buffer.concat(chunks), payload);
writes[0].resolve();
await waitFor(() => state('promote') === 'verified');
assert.equal(mounts.length, 0);
window.testFilesystemReady();
assert.equal((await promote).state, 'preloaded');
assert.equal(writes.length, 1, 'Promotion must reuse the in-progress Cache Storage write');
assert.equal(window.testOperations.size, 0);
assert.equal(mounts[0].own, true);
assert.equal(sha256(Buffer.from(mounts[0].bytes)), digest);

assert(window.__ashenOathRequestPack('foreground', digest, payload.length, 'v'));
await waitFor(() => state('foreground') === 'preloaded');
assert.equal(window.testOperations.size, 0);
assert.equal(writes.length, 2, 'Mounted packs must stay ready while a best-effort cache write stalls');
await delay(550);
await assert.rejects(writes[1].response.body.getReader().read(), { name: 'AbortError' });
assert.equal(sha256(Buffer.from(mounts[1].bytes)), digest);
console.log('PASS verified-pack streaming, promotion, cancellation and mount readiness');
