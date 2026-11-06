// Real exported MEMFS and Cache Storage check, without starting the game or GPU.
// node tools/test_web_pack_buffers.mjs <report.json> <python.exe>
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { createReadStream, readFileSync, writeFileSync, mkdirSync, mkdtempSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { execFileSync } from 'node:child_process';
import { gunzipSync } from 'node:zlib';
import { createHash } from 'node:crypto';
import puppeteer from 'puppeteer-core';

const reportPath = resolve(process.argv[2]);
const python = process.argv[3] || 'python';
const project = resolve(new URL('..', import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1'));
const web = resolve(project, '../../web');
const release = JSON.parse(readFileSync(resolve(web, 'release_manifest.json')));
const packs = JSON.parse(readFileSync(resolve(web, 'runtime_pack_manifest.json')));
const stock = gunzipSync(readFileSync(resolve(web, release.engine.script)));
const patched = execFileSync(python, ['-c',
  'import sys; from web_engine_owned_buffers import enable_owned_pack_buffers; sys.stdout.buffer.write(enable_owned_pack_buffers(sys.stdin.buffer.read()))'],
{ cwd: resolve(project, 'tools'), input: stock, maxBuffer: 2 * 1024 * 1024 });
const boundary = 'Module["copyToFS"]=GodotFS.copy_to_fs;';
assert.equal(patched.toString().split(boundary).length, 2);
// Test-only readback: never packaged, no game-state mutation or gameplay entry.
const served = patched.toString().replace(boundary, boundary +
  'Module["packTestView"]=function(p){const n=FS.lookupPath(p).node;return n.contents.subarray(0,n.usedBytes)};' +
  'Module["packTestRemove"]=function(p){FS.unlink(p)};');
const shell = readFileSync(resolve(project, 'web_boot_shell.html'), 'utf8');
assert(shell.includes('packCache.put(packUrl, new Response(payload))'));
const opening = packs.packs.opening;
const openingPath = new URL(opening.url, 'http://test.invalid/').pathname;
const artifact = release.artifacts.find(item => '/' + item.path === openingPath);
assert(artifact?.content_encoding === 'gzip');
const requests = [];
const server = createServer((req, res) => {
  const path = new URL(req.url, 'http://localhost').pathname;
  requests.push(path);
  if (path === '/') {
    res.writeHead(200, { 'Content-Type': 'text/html', 'Cache-Control': 'no-store' });
    res.end('<!doctype html><title>Pack ownership check</title><script src="/index.js"></script>');
  } else if (path === '/favicon.ico') {
    res.writeHead(204); res.end();
  } else if (path === '/index.js') {
    res.writeHead(200, { 'Content-Type': 'application/javascript' }); res.end(served);
  } else if (path === '/index.wasm' || path === '/opening.pck') {
    const item = path === '/index.wasm' ? release.artifacts.find(item => item.path === release.engine.wasm) : artifact;
    res.writeHead(200, { 'Content-Type': path === '/index.wasm' ? 'application/wasm' : 'application/octet-stream',
      'Content-Encoding': 'gzip', 'Content-Length': item.bytes, 'Cache-Control': 'no-store' });
    createReadStream(resolve(web, item.path)).pipe(res);
  } else { res.writeHead(404); res.end(); }
});
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
mkdirSync(dirname(reportPath), { recursive: true });
const profile = mkdtempSync(resolve(dirname(reportPath), 'pack-buffer-profile-'));
let browser;
const report = { status: 'running', baseline_build: release.build_id, profile,
  phases: [], console_errors: [],
  stock_js_sha256: createHash('sha256').update(stock).digest('hex'),
  candidate_js_sha256: createHash('sha256').update(patched).digest('hex'),
  scope: 'Actual MEMFS and browser Cache Storage. Headless; graphics disabled; no game startup, saves, or loading-time claim.' };
try {
  browser = await puppeteer.launch({ executablePath: 'C:/Program Files/Google/Chrome/Application/chrome.exe',
    headless: true, userDataDir: profile, protocolTimeout: 180000,
    args: ['--disable-gpu', '--no-first-run', '--no-default-browser-check', '--disable-background-networking'] });
  const page = await browser.newPage();
  const errors = [];
  page.on('pageerror', error => errors.push(String(error)));
  page.on('console', message => {
    if (message.text().startsWith('PACK_CHECK:')) {
      report.phases.push({ phase: message.text().slice(11), at: new Date().toISOString() });
      console.log(message.text());
    } else if (message.type() === 'error') report.console_errors.push(message.text());
  });
  await page.goto(`http://127.0.0.1:${server.address().port}/`, { waitUntil: 'load' });
  report.browser = await browser.version();
  report.result = await page.evaluate(async ({ expected }) => {
    const engine = new Engine({ executable: '/index', persistentPaths: [], onPrintError: (...args) => console.error(...args) });
    await engine.init('/index');
    console.log('PACK_CHECK:engine_initialized');
    if (engine.supportsOwnedPackBuffers !== true) throw new Error('Ownership capability absent');
    const payload = await (await fetch('/opening.pck')).arrayBuffer();
    console.log('PACK_CHECK:pack_downloaded');
    const hash = async bytes => [...new Uint8Array(await crypto.subtle.digest('SHA-256', bytes))]
      .map(value => value.toString(16).padStart(2, '0')).join('');
    if (payload.byteLength !== expected.bytes || await hash(payload) !== expected.sha256) throw new Error('Opening pack identity mismatch');
    console.log('PACK_CHECK:pack_verified');
    const t0 = performance.now();
    engine.copyToFS('/copy.pck', payload);
    const copyMs = performance.now() - t0;
    const copy = engine.rtenv.packTestView('/copy.pck');
    if (copy.buffer === payload || await hash(copy) !== expected.sha256) throw new Error('Default copy semantics changed');
    engine.rtenv.packTestRemove('/copy.pck');
    console.log('PACK_CHECK:default_copy_verified');
    const t1 = performance.now();
    engine.copyToFS('/owned.pck', payload, true);
    const ownedMs = performance.now() - t1;
    const owned = engine.rtenv.packTestView('/owned.pck');
    if (owned.buffer !== payload || await hash(owned) !== expected.sha256) throw new Error('Owned handoff was copied or corrupted');
    console.log('PACK_CHECK:owned_handoff_verified');
    const cache = await caches.open('pack-ownership-check');
    const cacheStart = performance.now();
    await cache.put('/verified.pck', new Response(payload));
    const cacheMs = performance.now() - cacheStart;
    console.log('PACK_CHECK:cache_written');
    const cached = await (await cache.match('/verified.pck')).arrayBuffer();
    if (await hash(cached) !== expected.sha256 || await hash(owned) !== expected.sha256 || payload.byteLength !== expected.bytes) {
      throw new Error('Cache Storage detached or altered the engine-owned pack');
    }
    await caches.delete('pack-ownership-check');
    engine.rtenv.packTestRemove('/owned.pck');
    return { decoded_pack_bytes: payload.byteLength, sha256: expected.sha256,
      normal_copy_independent: true, owned_same_buffer: true, cached_bytes_identical: true,
      owned_bytes_intact_after_cache: true, copy_ms: copyMs, owned_ms: ownedMs,
      cache_ms: cacheMs,
      timing_limit: 'One isolated copy operation, not a game-loading benchmark or process-memory measurement.' };
  }, { expected: { bytes: opening.bytes, sha256: opening.sha256 } });
  assert.deepEqual(errors, []);
  assert.deepEqual(report.console_errors, []);
  report.status = 'pass';
} catch (error) {
  report.status = 'fail'; report.error = String(error.stack || error); process.exitCode = 1;
} finally {
  if (browser) await browser.close();
  await new Promise(resolve => server.close(resolve));
  report.requests = requests;
  writeFileSync(reportPath, JSON.stringify(report, null, 2));
  console.log(JSON.stringify(report, null, 2));
}
