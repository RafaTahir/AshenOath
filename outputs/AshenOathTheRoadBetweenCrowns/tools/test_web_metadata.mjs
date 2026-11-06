import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import vm from 'node:vm';

// Exercise the authoritative export shell, not a copy of its implementation or
// a generated web/index.html. Network, timers and the engine filesystem are fake.
const shell = readFileSync(new URL('../web_boot_shell.html', import.meta.url), 'utf8');
function sourceBetween(start, end) {
  const first = shell.indexOf(start);
  const last = shell.indexOf(end, first);
  assert.ok(first >= 0 && last > first, `Missing shell test boundary: ${start}`);
  return shell.slice(first, last);
}
const metadataSource = sourceBetween('      async function sha256Hex(payload)', '      function mountOpeningPackAfterReady()');
const shutdownSource = sourceBetween('      function showStartupError(', '      window.__ashenOathBootstrapFailure');
const startupSource = sourceBetween('      window.__ashenOathStart = async () => {', '    })();');
const digest = bytes => createHash('sha256').update(new Uint8Array(bytes)).digest('hex');
const digestBuffer = bytes => Uint8Array.from(createHash('sha256').update(new Uint8Array(bytes)).digest()).buffer;
const encode = value => new TextEncoder().encode(JSON.stringify(value));
const deferred = () => {
  let resolve, reject;
  const promise = new Promise((yes, no) => { resolve = yes; reject = no; });
  return { promise, resolve, reject };
};
const observe = promise => {
  const result = { state: 'pending' };
  promise.then(value => Object.assign(result, { state: 'fulfilled', value }),
    error => Object.assign(result, { state: 'rejected', error }));
  return result;
};
async function flush() {
  for (let index = 0; index < 40; index += 1) await Promise.resolve();
}

class Clock {
  now = 0;
  next = 1;
  timers = new Map();
  setTimeout = (callback, delay) => {
    const id = this.next++;
    this.timers.set(id, { callback, at: this.now + delay });
    return id;
  };
  clearTimeout = id => this.timers.delete(id);
  async advance(milliseconds) {
    const target = this.now + milliseconds;
    for (;;) {
      const due = [...this.timers].filter(([, timer]) => timer.at <= target)
        .sort((a, b) => a[1].at - b[1].at || a[0] - b[0])[0];
      if (!due) break;
      this.now = due[1].at;
      this.timers.delete(due[0]);
      due[1].callback();
      await flush();
    }
    this.now = target;
    await flush();
  }
}

function fixture(change = () => {}) {
  const bodies = new Map(['campaign', 'opening_materials'].map(id => [id, new TextEncoder().encode(`GDPCfixture:${id}`)]));
  const manifest = {
    release_id: 'metadata-fixture',
    packs: Object.fromEntries([...bodies].map(([id, bytes]) => [id, {
      status: 'streamed_web_candidate', version: 'metadata-fixture', bytes: bytes.byteLength,
      sha256: digest(bytes), url: `packs/${id}.pck?sha256=${digest(bytes)}`,
    }])),
  };
  const release = {
    build_id: 'metadata-fixture',
    artifacts: [...bodies].map(([id, bytes]) => ({
      path: `packs/${id}.pck`, decoded_bytes: bytes.byteLength, decoded_sha256: digest(bytes),
    })),
  };
  change(manifest, release);
  const bytes = encode(manifest);
  release.runtime_pack_manifest = { sha256: digest(bytes) };
  return { manifest, release, bytes, bodies };
}

function harness(options = {}) {
  const data = options.data || fixture();
  const clock = new Clock();
  const requests = [], copied = [], errors = [];
  let route = options.route;
  const defaultResponse = path => {
    if (path === '/release_manifest.json') return { ok: true, json: async () => data.release };
    if (path === '/runtime_pack_manifest.json') return { ok: true, arrayBuffer: async () => data.bytes.buffer };
    const id = /^\/packs\/([a-z0-9_]+)\.pck$/.exec(path)?.[1];
    assert.ok(data.bodies.has(id), `Unexpected fake fetch: ${path}`);
    return { ok: true, arrayBuffer: async () => data.bodies.get(id).buffer };
  };
  const crypto = { subtle: { digest: (_algorithm, bytes) => options.hash ? options.hash(bytes) : Promise.resolve(digestBuffer(bytes)) } };
  const window = {
    crypto, location: { href: 'https://game.invalid/', origin: 'https://game.invalid' },
    __ashenOathPreloadedPacks: {}, setTimeout: clock.setTimeout, clearTimeout: clock.clearTimeout,
    dispatchEvent() {},
  };
  if (options.cache) window.caches = options.cache;
  const context = vm.createContext({
    AbortController, URL, TextDecoder, Uint8Array, crypto, window, location: window.location,
    caches: options.cache,
    SHELL_BUILD_ID: 'metadata-fixture', failed: false, bootMetrics: {}, startupDeadline: 0,
    document: { hidden: true, getElementById: () => ({}) }, errorPanel: {}, loading: {},
    updateAudioNotice() {}, setBootState() {}, reload: { focus() {} },
    CustomEvent: class { constructor(type, init) { this.type = type; this.detail = init.detail; } },
    engine: { supportsOwnedPackBuffers: options.ownedBuffers === true,
      copyToFS: (path, bytes, owned) => copied.push({ path, bytes: new Uint8Array(bytes), owned }), requestQuit() {} },
    console: { error: (...values) => errors.push(values) },
    fetch: (url, init) => {
      const request = { url: String(url), path: new URL(url, window.location.href).pathname, ...init };
      requests.push(request);
      const response = () => defaultResponse(request.path);
      return Promise.resolve(route ? route(request, response) : response());
    },
  });
  vm.runInContext(metadataSource + shutdownSource + `
    globalThis.api = {
      manifest: getPackManifest, wait: awaitWithAbort,
      operation: id => packOperations.get(id),
      metadataSignal: () => manifestAttempt?.controller.signal,
      filesystemReady: () => filesystemReadyResolve(true),
      shutdown: () => showStartupError('Fixture shutdown'),
    };
  `, context, { filename: 'web_boot_shell.html:metadata' });
  if (options.filesystemReady !== false) context.api.filesystemReady();
  return {
    data, clock, requests, copied, errors, api: context.api,
    request: id => window.__ashenOathRequestPack(id), cancel: id => window.__ashenOathCancelPack(id),
    state: id => window.__ashenOathPreloadedPacks[id],
    setRoute: replacement => { route = replacement; },
    count: path => requests.filter(request => request.path === path).length,
    startEngine: Engine => {
      Object.assign(context, { Engine, GODOT_CONFIG: { executable: 'engine' }, started: false,
        engineBooted: false, startupResourceError: '', performance: { now: () => clock.now, mark() {} },
        captureEngineAudioContext: () => () => {}, updateLoading() {}, mountOpeningPackAfterReady() {} });
      vm.runInContext(startupSource, context);
      return window.__ashenOathStart();
    },
  };
}

test('new packs use HTTP caching without a duplicate decoded Cache Storage write', async () => {
  let writes = 0;
  const h = harness({ cache: { open: async () => ({
    match: async () => undefined, put: async () => { writes++; }, delete: async () => true,
  }) } });
  h.request('campaign');
  await h.api.operation('campaign').promise;
  assert.equal(h.state('campaign').state, 'preloaded');
  assert.equal(h.requests.find(request => request.path === '/packs/campaign.pck').cache, 'force-cache');
  assert.equal(writes, 0);
});

test('valid legacy decoded caches remain readable and hash verified', async () => {
  const data = fixture();
  const h = harness({ data, cache: { open: async () => ({
    match: async () => ({ ok: true, arrayBuffer: async () => data.bodies.get('campaign').buffer }),
    put: async () => { throw new Error('Legacy cache must be read-only'); },
    delete: async () => true,
  }) } });
  h.request('campaign');
  await h.api.operation('campaign').promise;
  assert.equal(h.state('campaign').state, 'preloaded');
  assert.equal(h.count('/packs/campaign.pck'), 0);
  assert.deepEqual(h.copied[0].bytes, data.bodies.get('campaign'));
});

test('corrupt legacy cache is removed and Retry reloads verified network bytes', async () => {
  const data = fixture();
  let stale = true, deletions = 0;
  const bad = new Uint8Array(data.bodies.get('campaign'));
  bad[0] ^= 1;
  const h = harness({ data, cache: { open: async () => ({
    match: async () => stale ? { ok: true, arrayBuffer: async () => bad.buffer } : undefined,
    delete: async () => { stale = false; deletions++; return true; },
  }) } });
  h.request('campaign');
  await h.api.operation('campaign').promise;
  assert.equal(h.state('campaign').state, 'failed');
  assert.equal(h.copied.length, 0);
  assert.equal(deletions, 1);
  h.request('campaign');
  await h.api.operation('campaign').promise;
  assert.equal(h.state('campaign').state, 'preloaded');
  assert.equal(h.requests.find(request => request.path === '/packs/campaign.pck').cache, 'reload');
});

test('unavailable legacy cache does not prevent HTTP-cached pack loading', async () => {
  const h = harness({ cache: { open: async () => { throw new Error('Storage unavailable'); } } });
  h.request('campaign');
  await h.api.operation('campaign').promise;
  assert.equal(h.state('campaign').state, 'preloaded');
  assert.equal(h.count('/packs/campaign.pck'), 1);
});

test('verified packs enter the initialized filesystem before project startup finishes', async () => {
  const h = harness({ filesystemReady: false });
  const initialized = deferred(), running = deferred();
  let loads = 0;
  class Engine {
    static getMissingFeatures() { return []; }
    init() { return initialized.promise; }
    startGame() { loads += 1; return Promise.all([this.init(), running.promise]); }
    copyToFS(path, bytes) { h.copied.push({ path, bytes }); }
  }
  h.request('campaign');
  const started = observe(h.startEngine(Engine));
  await flush();
  assert.equal(h.state('campaign').state, 'verified');
  assert.equal(h.copied.length, 0);
  initialized.resolve();
  await flush();
  assert.equal(h.state('campaign').state, 'preloaded');
  assert.equal(h.copied.length, 1);
  assert.equal(started.state, 'pending');
  running.resolve();
  await flush();
  assert.equal(started.state, 'fulfilled');
  assert.equal(loads, 1);
});

test('failed engine initialization never copies verified packs into an unavailable filesystem', async () => {
  const h = harness({ filesystemReady: false });
  const initialized = deferred();
  class Engine {
    static getMissingFeatures() { return []; }
    init() { return initialized.promise; }
    startGame() { return this.init(); }
    copyToFS() { assert.fail('copy after failed initialization'); }
    requestQuit() {}
  }
  h.request('campaign');
  const starting = h.startEngine(Engine);
  await flush();
  initialized.reject(new Error('Engine initialization failed'));
  await starting;
  await flush();
  assert.equal(h.copied.length, 0);
  assert.equal(h.request('campaign'), false);
});

test('the complete source shell scripts parse', () => {
  const scripts = [...shell.matchAll(/<script\b[^>]*>([\s\S]*?)<\/script>/g)];
  assert.ok(scripts.length > 0);
  for (const [, source] of scripts) new vm.Script(source, { filename: 'web_boot_shell.html' });
});

for (const ownedBuffers of [false, true]) {
  test(`verified pack ownership requires explicit engine capability: ${ownedBuffers}`, async () => {
    const h = harness({ ownedBuffers });
    h.request('campaign');
    await flush();
    assert.equal(h.state('campaign').state, 'preloaded');
    assert.equal(h.copied[0].owned, ownedBuffers);
    assert.equal(digest(h.copied[0].bytes), h.data.manifest.packs.campaign.sha256);
  });
}

test('concurrent packs share one validated manifest and retain successful metadata', async () => {
  const h = harness();
  h.request('campaign');
  h.request('opening_materials');
  const shared = h.api.manifest();
  await flush();
  assert.equal(h.state('campaign').state, 'preloaded');
  assert.equal(h.state('opening_materials').state, 'preloaded');
  assert.equal(h.copied.length, 2);
  assert.equal(h.count('/release_manifest.json'), 1);
  assert.equal(h.count('/runtime_pack_manifest.json'), 1);
  assert.equal(h.api.manifest(), shared);
  assert.equal(h.clock.timers.size, 0);
  assert.equal(h.requests[0].signal, h.requests[1].signal);
});

for (const path of ['/release_manifest.json', '/runtime_pack_manifest.json']) {
  for (const phase of ['headers', 'body']) {
    test(`metadata deadline bounds stalled ${path} ${phase}, then explicit Retry recovers`, async () => {
      const stalled = deferred();
      const h = harness({ route: (request, next) => {
        if (request.path !== path) return next();
        if (phase === 'headers') return stalled.promise; // Deliberately ignores abort.
        return { ok: true, json: () => stalled.promise, arrayBuffer: () => stalled.promise };
      } });
      h.request('campaign');
      await flush();
      const metadataSignal = h.api.metadataSignal();
      await h.clock.advance(14999);
      assert.equal(h.state('campaign').state, 'loading');
      await h.clock.advance(1);
      assert.equal(metadataSignal.aborted, true);
      assert.equal(h.state('campaign').state, 'failed');
      assert.match(h.state('campaign').error, /metadata request timed out/i);
      await h.clock.advance(30000);
      assert.equal(h.count('/release_manifest.json'), 1, 'failure must not create automatic retry loops');
      h.setRoute(null);
      h.request('campaign');
      await flush();
      assert.equal(h.state('campaign').state, 'preloaded');
      assert.equal(h.count('/release_manifest.json'), 2);
      assert.equal(h.requests.find(request => request.path === '/packs/campaign.pck').cache, 'reload');
      assert.equal(h.clock.timers.size, 0);
    });
  }
}

test('the 15-second budget covers both requests rather than restarting per response', async () => {
  const releaseHeaders = deferred(), runtimeBody = deferred();
  const h = harness({ route: (request, next) => {
    if (request.path === '/release_manifest.json') return releaseHeaders.promise;
    if (request.path === '/runtime_pack_manifest.json') return { ok: true, arrayBuffer: () => runtimeBody.promise };
    return next();
  } });
  h.request('campaign');
  await h.clock.advance(8000);
  releaseHeaders.resolve({ ok: true, json: async () => h.data.release });
  await flush();
  await h.clock.advance(6999);
  assert.equal(h.state('campaign').state, 'loading');
  await h.clock.advance(1);
  assert.equal(h.state('campaign').state, 'failed');
});

for (const oldOutcome of ['resolve', 'reject']) {
  test(`timeout covers validation and a late old ${oldOutcome} cannot replace new metadata`, async () => {
    const oldHash = deferred();
    let calls = 0;
    const h = harness({ hash: bytes => ++calls === 1 ? oldHash.promise : Promise.resolve(digestBuffer(bytes)) });
    h.request('campaign');
    await flush();
    const old = h.api.manifest();
    const result = observe(old);
    await h.clock.advance(15000);
    assert.equal(result.state, 'rejected');
    h.request('campaign');
    const replacement = h.api.manifest();
    await flush();
    assert.notEqual(replacement, old);
    assert.equal(h.state('campaign').state, 'preloaded');
    if (oldOutcome === 'resolve') oldHash.resolve(digestBuffer(h.data.bytes));
    else oldHash.reject(new Error('Late old digest failure'));
    await flush();
    assert.equal(h.api.manifest(), replacement);
    assert.equal(h.state('campaign').state, 'preloaded');
    assert.equal(h.copied.length, 1);
    assert.equal(h.count('/release_manifest.json'), 2);
  });
}

test('cancelling one of two metadata consumers settles it without aborting its sibling', async () => {
  const headers = deferred();
  const h = harness({ route: (request, next) => request.path === '/release_manifest.json' ? headers.promise : next() });
  h.request('campaign');
  h.request('opening_materials');
  const cancelled = observe(h.api.operation('campaign').promise);
  const sharedSignal = h.api.metadataSignal();
  h.cancel('campaign');
  await flush();
  assert.equal(cancelled.state, 'fulfilled');
  assert.equal(cancelled.value, null);
  assert.equal(h.state('campaign').state, 'cancelled');
  assert.equal(sharedSignal.aborted, false);
  assert.equal(h.state('opening_materials').state, 'loading');
  headers.resolve({ ok: true, json: async () => h.data.release });
  await flush();
  assert.equal(h.state('opening_materials').state, 'preloaded');
  assert.equal(h.copied.length, 1);
  h.request('campaign');
  await flush();
  assert.equal(h.state('campaign').state, 'preloaded');
  assert.equal(h.count('/release_manifest.json'), 1);
  assert.equal(h.copied.length, 2);
});

test('immediate cancel and restart cannot let the old operation overwrite its replacement', async () => {
  const headers = deferred();
  const h = harness({ route: (request, next) => request.path === '/release_manifest.json' ? headers.promise : next() });
  h.request('campaign');
  const old = h.api.operation('campaign');
  h.cancel('campaign');
  h.request('campaign');
  const replacement = h.api.operation('campaign');
  await flush();
  assert.notEqual(old, replacement);
  assert.equal(h.state('campaign').state, 'loading');
  headers.resolve({ ok: true, json: async () => h.data.release });
  await flush();
  assert.equal(h.state('campaign').state, 'preloaded');
  assert.equal(h.copied.length, 1);
  assert.equal(h.count('/release_manifest.json'), 1);
});

test('an already-aborted consumer rejects promptly and still handles late underlying rejection', async () => {
  const h = harness(), underlying = deferred(), controller = new AbortController();
  controller.abort(new Error('Consumer left'));
  const result = observe(h.api.wait(underlying.promise, controller.signal));
  await flush();
  assert.equal(result.state, 'rejected');
  assert.match(result.error.message, /Consumer left/);
  underlying.reject(new Error('Late ignored work'));
  await flush();
});

test('the unchanged 90-second pack deadline cancels a stalled transfer and explicit Retry works', async () => {
  const transfer = deferred();
  const h = harness({ route: (request, next) => request.path.startsWith('/packs/') ? transfer.promise : next() });
  h.request('campaign');
  await flush();
  const transferSignal = h.requests.find(request => request.path.startsWith('/packs/')).signal;
  // A real Fetch rejects when aborted. Keep that behavior while its headers stall.
  transferSignal.addEventListener('abort', () => transfer.reject(transferSignal.reason), { once: true });
  await h.clock.advance(89999);
  assert.equal(h.state('campaign').state, 'loading');
  await h.clock.advance(1);
  assert.equal(transferSignal.aborted, true);
  assert.equal(h.state('campaign').state, 'cancelled');
  h.setRoute(null);
  h.request('campaign');
  await flush();
  assert.equal(h.state('campaign').state, 'preloaded');
  assert.equal(h.count('/release_manifest.json'), 1);
});

test('the pack deadline also bounds waiting for the engine filesystem', async () => {
  const h = harness({ filesystemReady: false });
  h.request('campaign');
  await flush();
  assert.equal(h.state('campaign').state, 'verified');
  await h.clock.advance(90000);
  assert.equal(h.state('campaign').state, 'cancelled');
  h.api.filesystemReady();
  await flush();
  assert.equal(h.copied.length, 0);
});

for (const [label, data, error] of [
  ['page/release identity', fixture((_manifest, release) => { release.build_id = 'other-release'; }), /Page\/release identity mismatch/],
  ['runtime release identity', fixture(manifest => { manifest.release_id = 'other-release'; }), /Runtime manifest release mismatch/],
  ['pack inventory', fixture((_manifest, release) => { release.artifacts[0].decoded_bytes += 1; }), /Pack release-inventory mismatch/],
  ['external origin', fixture(manifest => { manifest.packs.campaign.url = 'https://elsewhere.invalid/packs/campaign.pck'; }), /External pack origin rejected/],
]) {
  test(`${label} validation still rejects unsafe metadata before any pack fetch`, async () => {
    const h = harness({ data });
    h.request('campaign');
    await flush();
    assert.equal(h.state('campaign').state, 'failed');
    assert.match(h.state('campaign').error, error);
    assert.equal(h.requests.filter(request => request.path.startsWith('/packs/')).length, 0);
    assert.equal(h.copied.length, 0);
    assert.equal(h.clock.timers.size, 0);
  });
}

test('runtime metadata hash mismatch fails, and corrected metadata can be retried', async () => {
  const data = fixture();
  data.release.runtime_pack_manifest.sha256 = '0'.repeat(64);
  const h = harness({ data });
  h.request('campaign');
  await flush();
  assert.equal(h.state('campaign').state, 'failed');
  assert.match(h.state('campaign').error, /Runtime manifest hash mismatch/);
  assert.equal(h.copied.length, 0);
  data.release.runtime_pack_manifest.sha256 = digest(data.bytes);
  h.request('campaign');
  await flush();
  assert.equal(h.state('campaign').state, 'preloaded');
  assert.equal(h.count('/release_manifest.json'), 2);
});

test('HTTP metadata failure is immediate and does not poison a subsequent attempt', async () => {
  const h = harness({ route: (request, next) => request.path === '/runtime_pack_manifest.json' ? { ok: false, status: 503 } : next() });
  h.request('campaign');
  await flush();
  assert.equal(h.state('campaign').state, 'failed');
  assert.match(h.state('campaign').error, /runtime pack manifest HTTP 503/);
  h.setRoute(null);
  h.request('campaign');
  await flush();
  assert.equal(h.state('campaign').state, 'preloaded');
  assert.equal(h.count('/release_manifest.json'), 2);
});

test('global bootstrap shutdown aborts shared metadata and blocks new pack requests', async () => {
  const headers = deferred();
  const h = harness({ route: () => headers.promise });
  h.request('campaign');
  const signal = h.api.metadataSignal();
  h.api.shutdown();
  await flush();
  assert.equal(signal.aborted, true);
  assert.equal(h.state('campaign').state, 'failed');
  assert.match(h.state('campaign').error, /Game startup stopped/);
  assert.equal(h.request('opening_materials'), false);
  assert.equal(h.copied.length, 0);
  assert.equal(h.clock.timers.size, 0);
});
