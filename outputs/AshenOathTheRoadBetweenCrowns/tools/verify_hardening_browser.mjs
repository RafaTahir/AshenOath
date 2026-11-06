// Focused production-UI functional checks; no FPS, memory or hardware certification.
// node tools/verify_hardening_browser.mjs --export ../../web --report D:/Temp/AshenOath/hardening/report.json
// --scenario startup|smoke|metadata|cold|all|combat --mode desktop|touch|both --label candidate|baseline
// combat is opt-in; all retains the save/loading suite.
// combat requires --combat-phase light|heavy|bow; run each phase/viewport in a fresh invocation.
// --fault metadata_headers_stall|metadata_body_stall|opening_unavailable selects one Retry case.
// --inspect validates inputs and candidate transport without launching Chromium.
import puppeteer from 'puppeteer-core';
import { createServer } from 'node:http';
import { createReadStream, existsSync, mkdirSync, openSync, closeSync, readSync,
  readFileSync, statSync, writeFileSync, rmSync } from 'node:fs';
import { resolve, join, dirname, extname, sep } from 'node:path';
import { createHash } from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import assert from 'node:assert/strict';

const options = {};
for (let i = 2; i < process.argv.length; i++) {
  const key = process.argv[i];
  assert(key.startsWith('--'), `Unexpected argument: ${key}`);
  options[key.slice(2)] = process.argv[i + 1] && !process.argv[i + 1].startsWith('--') ? process.argv[++i] : true;
}
const exportRoot = resolve(options.export || '../../web');
const scenario = String(options.scenario || 'all');
const mode = String(options.mode || 'both');
const combatPhase = String(options['combat-phase'] || '');
const metadataFaults = options.fault ? [String(options.fault)] : ['metadata_headers_stall', 'metadata_body_stall'];
assert(['all', 'startup', 'smoke', 'metadata', 'cold', 'combat'].includes(scenario), 'Invalid --scenario');
assert(['both', 'desktop', 'touch'].includes(mode), 'Invalid --mode');
if (scenario === 'combat') assert(['light', 'heavy', 'bow'].includes(combatPhase),
  'Combat requires --combat-phase light|heavy|bow. Run each phase/viewport in a fresh process/profile; combined combat reloads are not supported.');
assert(metadataFaults.every(kind => ['metadata_headers_stall', 'metadata_body_stall', 'opening_unavailable'].includes(kind)), 'Invalid --fault');
const timeoutMs = Number(options.timeout || 180000);
assert(Number.isFinite(timeoutMs) && timeoutMs >= 30000, '--timeout must be at least 30000 ms');
const temporaryRoot = resolve('D:/Temp/AshenOath/hardening-browser');
const runRoot = join(temporaryRoot, `run-${Date.now()}-${process.pid}`);
const reportPath = resolve(options.report || join(runRoot, 'report.json'));
const evidenceRoot = reportPath.replace(/\.json$/i, '') + '_evidence';
mkdirSync(runRoot, { recursive: true });
mkdirSync(evidenceRoot, { recursive: true });
const releaseBytes = readFileSync(join(exportRoot, 'release_manifest.json'));
const release = JSON.parse(releaseBytes);
const packs = JSON.parse(readFileSync(join(exportRoot, 'runtime_pack_manifest.json'), 'utf8'));
assert(existsSync(join(exportRoot, 'index.html')), 'Candidate index.html is missing');
if (options['expect-build-id']) assert.equal(release.build_id, String(options['expect-build-id']), 'Wrong candidate build');

const report = {
  schema_version: 1, kind: 'focused_browser_functional', label: String(options.label || 'candidate'),
  started_at: new Date().toISOString(), export_root: exportRoot,
  build_id: release.build_id, source: release.source,
  release_manifest_sha256: createHash('sha256').update(releaseBytes).digest('hex'),
  harness_sha256: createHash('sha256').update(readFileSync(new URL(import.meta.url))).digest('hex'),
  observation_mode: 'production_read_only', gameplay_input: 'Chromium mouse/keyboard/touch and file picker',
  light_loop_candidate_injected: Boolean(options['light-loop-candidate']),
  limits: ['No gameplay mutation API', 'No performance thresholds or hardware/mobile-device certification',
    'Imported fixtures are test journeys, not earned campaign progression'],
  cases: [], requests: [], status: 'running',
};
let combatModule;
if (scenario === 'combat') {
  const moduleUrl = new URL('./hardening_combat_cases.mjs', import.meta.url);
  report.combat_module = { path: fileURLToPath(moduleUrl),
    sha256: createHash('sha256').update(readFileSync(moduleUrl)).digest('hex'), phase: combatPhase };
  combatModule = await import(moduleUrl.href);
  assert.equal(typeof combatModule.runCombatCase, 'function', 'Combat module must export runCombatCase');
}

const mime = { '.html': 'text/html; charset=utf-8', '.js': 'application/javascript; charset=utf-8',
  '.wasm': 'application/wasm', '.json': 'application/json; charset=utf-8', '.png': 'image/png' };
const artifacts = new Map((release.artifacts || []).map(item => [item.path, item]));
function fileInfo(relative) {
  const path = resolve(exportRoot, relative);
  assert(path.startsWith(exportRoot + sep), 'Request escaped export root');
  const descriptor = openSync(path, 'r');
  const signature = Buffer.alloc(2);
  try { readSync(descriptor, signature, 0, 2, 0); } finally { closeSync(descriptor); }
  const gzip = signature[0] === 0x1f && signature[1] === 0x8b;
  const artifact = artifacts.get(relative);
  if (artifact?.content_encoding) assert.equal(gzip ? 'gzip' : '', artifact.content_encoding, `Encoding: ${relative}`);
  if (artifact?.bytes !== undefined) assert.equal(statSync(path).size, artifact.bytes, `Transport size: ${relative}`);
  return { path, gzip, bytes: statSync(path).size };
}
// Serve encoded candidate bytes unchanged; never recompress or retain PCK buffers.
for (const relative of artifacts.keys()) fileInfo(relative);
const fault = { kind: '', path: '', hits: 0, delay_ms: 0 };
const heldDownloads = new Set();
function armFault(kind, path, delayMs = 0) {
  Object.assign(fault, { kind, path, hits: 0, delay_ms: delayMs });
}
const server = createServer((request, response) => {
  let relative;
  try { relative = decodeURIComponent(new URL(request.url, 'http://local').pathname).replace(/^\/+/, '') || 'index.html'; }
  catch { response.writeHead(400).end(); return; }
  const record = { path: relative, at: Date.now(), scenario: currentCase?.name || 'setup', fault: null };
  report.requests.push(record);
  let info;
  try { info = fileInfo(relative); }
  catch { response.writeHead(relative === 'favicon.ico' ? 204 : 404).end(); return; }
  const send = () => {
    if (response.destroyed) return;
    const rootMutable = /^(index\.(html|pck|js|wasm)|index\.audio(?:\.position)?\.worklet\.js)$/.test(relative);
    const headers = { 'Content-Type': mime[extname(relative)] || 'application/octet-stream',
      'Content-Length': info.bytes, 'Cache-Control': rootMutable || relative.endsWith('manifest.json')
        ? 'no-cache, must-revalidate' : 'public, max-age=31536000, immutable' };
    if (info.gzip) headers['Content-Encoding'] = 'gzip';
    response.writeHead(200, headers);
    const stream = createReadStream(info.path);
    response.once('close', () => stream.destroy());
    stream.on('error', () => response.destroy());
    stream.pipe(response);
  };
  if (fault.kind && relative === fault.path) {
    fault.hits++;
    record.fault = fault.kind;
    if (fault.kind === 'opening_unavailable') {
      response.writeHead(503, { 'Cache-Control': 'no-store' }).end('Controlled opening-pack outage');
      return;
    }
    if (fault.kind === 'metadata_headers_stall' || fault.kind === 'metadata_body_stall') {
      // Hold headers/body until the production deadline aborts the real request.
      if (fault.kind === 'metadata_body_stall') {
        response.writeHead(200, { 'Content-Type': mime[extname(relative)] || 'application/octet-stream',
          'Content-Length': info.bytes, 'Cache-Control': 'no-cache, must-revalidate' });
        response.write(readFileSync(info.path).subarray(0, 8));
      }
      response.on('close', () => { record.closed_at = Date.now(); });
      return;
    }
    if (fault.kind === 'cold_hold') {
      const held = { send, response, record };
      heldDownloads.add(held);
      response.on('close', () => { heldDownloads.delete(held); record.closed_at = Date.now(); });
      return;
    }
    if (fault.kind === 'cold_delay') {
      const timer = setTimeout(() => { record.released_at = Date.now(); send(); }, fault.delay_ms);
      response.on('close', () => { clearTimeout(timer); record.closed_at = Date.now(); });
      return;
    }
  }
  send();
});
await new Promise(resolveListen => server.listen(0, '127.0.0.1', resolveListen));
const origin = `http://127.0.0.1:${server.address().port}`;
const sleep = ms => new Promise(resolveSleep => setTimeout(resolveSleep, ms));
let currentCase = null;
let browser = null;
const profile = join(runRoot, 'chromium-profile');
const runtimeErrors = [];
const observations = new WeakMap();
function event(data) {
  currentCase.events.push(data);
  console.log(`HARDENING EVENT: ${currentCase.name} ${data.event}${data.text ? ' ' + data.text.split('\n')[0] : ''}`);
  writeFileSync(reportPath, JSON.stringify(report, null, 2));
}

async function waitFor(fn, description, budget = timeoutMs) {
  const deadline = Date.now() + budget;
  while (Date.now() < deadline) {
    try {
      const value = await fn();
      if (value) return value;
    } catch (error) {
      if (!/Execution context was destroyed|Cannot find context/i.test(String(error))) throw error;
    }
    await sleep(250);
  }
  throw new Error(`Timed out: ${description} (${budget} ms functional bound)`);
}
async function boundedClose(operation) {
  let timer;
  try { await Promise.race([operation.catch(() => {}), new Promise(done => { timer = setTimeout(done, 15000); })]); }
  finally { clearTimeout(timer); }
}
async function observe(page) {
  // The production bridge pushes observations while Godot publishes frames.
  // Do not queue Runtime.evaluate behind a long WebGL/prewarm task to poll it.
  if (page.isClosed()) throw new Error('Observed browser page closed');
  return observations.get(page)?.latest || null;
}
const playable = s => s?.read_only === true && s.ready && !s.paused && s.player?.can_control
  && !s.transition_pending && !s.zone_load_request_pending && !s.ui?.loading_visible && !s.dialogue?.visible;
async function stableGameplay(page) {
  let phase = '', count = 0, last = -1;
  return waitFor(async () => {
    const s = await observe(page);
    if (!playable(s)) { phase = ''; count = 0; return null; }
    const next = JSON.stringify([s.zone, s.ui.viewport, s.input.context, s.player.can_control]);
    if (next !== phase) { phase = next; count = 0; last = -1; }
    if (s.timestamp > last) { count++; last = s.timestamp; }
    return count >= 5 ? s : null;
  }, 'stable gameplay context and viewport before a fresh gesture');
}
function point(button, state, viewport) {
  const v = state.ui.viewport;
  assert(v?.x > 0 && v?.y > 0 && button.size?.x > 0 && button.size?.y > 0, 'Missing button geometry');
  const result = { x: (button.position.x + button.size.x / 2) * viewport.width / v.x,
    y: (button.position.y + button.size.y / 2) * viewport.height / v.y };
  return result;
}
async function tap(page, p, touch) {
  if (touch) {
    const finger = await startFinger(page, p.x, p.y);
    await sleep(80);
    await finger.end();
  }
  else await page.mouse.click(p.x, p.y, { delay: 80 });
}
async function startFinger(page, x, y) {
  const input = observations.get(page).input;
  assert(input, 'Touch input session was not initialized');
  const point = { id: 1, x, y, radiusX: 1, radiusY: 1, force: 1 };
  await input.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [point] });
  return {
    async move(nextX, nextY) { Object.assign(point, { x: nextX, y: nextY }); await input.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [point] }); },
    async end() { await input.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] }); },
  };
}
async function clickButton(page, label, viewport, touch = false, prefix = false) {
  let previous = '';
  let previousTimestamp = -1;
  const found = await waitFor(async () => {
    const state = await observe(page);
    const matches = (state?.ui?.buttons || []).filter(b => b.enabled && (prefix ? b.text.startsWith(label) : b.text === label));
    const button = matches.find(b => b.focused) || matches[0];
    if (!button) return null;
    const p = point(button, state, viewport);
    if (p.x <= 0 || p.x >= viewport.width || p.y <= 0 || p.y >= viewport.height) {
      await page.keyboard.press('Tab');
      return null;
    }
    const geometry = JSON.stringify([button.name, button.text, button.position, button.size, state.ui.viewport]);
    if (previous !== geometry) { previous = geometry; previousTimestamp = state.timestamp; return null; }
    return state.timestamp > previousTimestamp ? { p, text: button.text, state } : null;
  }, `visible enabled ${label}`);
  await tap(page, found.p, touch);
  event({ event: 'ui_click', text: found.text, at: Date.now(), point: found.p });
  return found.state;
}
async function screenshot(page, name) {
  const path = join(evidenceRoot, `${currentCase.name}-${name}.png`);
  await page.screenshot({ path, timeout: 60000 });
  currentCase.screenshots.push(path);
}
async function persistence(page) {
  // Read-only IDB transactions observe actual committed production saves.
  return page.evaluate(() => new Promise((resolveRead, reject) => {
    const request = indexedDB.open('/userfs');
    request.onupgradeneeded = () => request.transaction.abort();
    request.onerror = () => resolveRead({});
    request.onsuccess = () => {
      const db = request.result;
      if (!db.objectStoreNames.contains('FILE_DATA')) { db.close(); resolveRead({}); return; }
      const tx = db.transaction('FILE_DATA', 'readonly');
      const store = tx.objectStore('FILE_DATA');
      const result = {};
      tx.onerror = () => { db.close(); reject(new Error('Read-only save inspection failed')); };
      tx.oncomplete = () => { db.close(); resolveRead(result); };
      store.openCursor().onsuccess = event => {
        const cursor = event.target.result;
        if (!cursor) return;
        const name = String(cursor.key).split('/').at(-1);
        if (name.startsWith('ashen_oath_') && /\.json(?:\.bak)?$/.test(name) && cursor.value.contents) {
          const text = new TextDecoder().decode(cursor.value.contents);
          try { result[name] = { text, data: JSON.parse(text) }; } catch { result[name] = { text }; }
        }
        cursor.continue();
      };
    };
  }));
}
async function enterMenu(page, touch) {
  const url = `${origin}/index.html?observe=1${touch ? '&touch=1' : ''}`;
  observations.get(page).latest = null;
  if (page.url().startsWith(origin)) {
    // Return before Godot's unload work rather than block Page.navigate on it.
    await page.evaluate(target => { setTimeout(() => { location.href = target; }, 0); }, url);
    await waitFor(async () => !(await observe(page))?.ready, 'fresh page navigation');
  } else await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 30000 });
  if (scenario === 'startup' && !currentCase.loading_captured) {
    const first = await waitFor(async () => {
      const s = await observe(page);
      return ['startup', 'main'].includes(s?.ui?.active_menu) ? s : null;
    }, 'loading presentation appears');
    currentCase.loading_captured = true;
    if (first.ui.active_menu === 'startup') {
      assert(!first.ui.buttons?.some(b => b.enabled && /^(New Game|Continue|Settings)$/.test(b.text)),
        'Unready menu actions exposed during loading');
      await screenshot(page, 'loading-first');
      await sleep(9000);
      if ((await observe(page))?.ui?.active_menu === 'startup') await screenshot(page, 'loading-artwork-next');
      event({ event: 'loading_menu_actions_withheld' });
    }
  }
  let nextLoadingCapture = Date.now() + 12000;
  let loadingCapture = 0;
  await waitFor(async () => {
    const s = await observe(page);
    const retry = s?.ui?.buttons?.some(b => b.enabled && /Retry/i.test(b.text));
    if (scenario === 'startup' && s?.ui?.active_menu === 'startup' && Date.now() >= nextLoadingCapture) {
      await screenshot(page, `loading-stage-${++loadingCapture}`);
      nextLoadingCapture = Date.now() + 12000;
    }
    return s?.ui?.active_menu === 'main' || retry ? s : null;
  }, 'production main menu or recoverable preparation failure');
  if (scenario === 'startup') {
    event({ event: 'menu_reached', startup: await page.evaluate(() => ({
      navigation_ms: performance.now(), boot: window.__ashenOathBoot, opening: window.__ashenOathOpeningState,
      light_loops: window.__ashenBoundedLightLoops || null,
    })) });
    if (!currentCase.graphics) {
      currentCase.graphics = await page.evaluate(() => {
        const gl = document.querySelector('#canvas')?.getContext('webgl2');
        if (!gl) return { context: 'unavailable' };
        const info = gl.getExtension('WEBGL_debug_renderer_info');
        return { context: 'webgl2', renderer: info ? gl.getParameter(info.UNMASKED_RENDERER_WEBGL) : gl.getParameter(gl.RENDERER),
          vendor: info ? gl.getParameter(info.UNMASKED_VENDOR_WEBGL) : gl.getParameter(gl.VENDOR), version: gl.getParameter(gl.VERSION) };
      });
      event({ event: 'graphics_device', ...currentCase.graphics });
    }
    if (options['webgl-profile']) {
      const profile = await page.evaluate(() => window.__ASHEN_WEBGL_PROFILE__ || null);
      const path = join(evidenceRoot, `${currentCase.name}-webgl-${currentCase.webgl_profiles?.length || 0}.json`);
      writeFileSync(path, JSON.stringify(profile, null, 2));
      (currentCase.webgl_profiles ||= []).push(path);
    }
    await screenshot(page, 'ready-menu');
  }
}
async function startGame(page, viewport, touch) {
  await waitFor(async () => (await observe(page))?.new_game_ready, 'New Game ready');
  await clickButton(page, 'New Game', viewport, touch);
  let openingSkipAttempted = false;
  // Close no story choices automatically: only a labelled Skip/Continue for an
  // opening scene, if one is actually presented, may release initial control.
  await waitFor(async () => {
    const s = await observe(page);
    if (!openingSkipAttempted && s?.ui?.focused_control === 'OpeningSceneSkip'
        && s.player?.can_control === false && !s.ui.loading_visible && !s.dialogue?.visible) {
      // The production observer omits this direct HUD overlay from buttons.
      // dialogue_panel.gd authors its canvas rect at right[-204,-24], y[24,80].
      // Activate only the focused cinematic Skip, using ordinary input.
      openingSkipAttempted = true;
      const p = { x: (s.ui.viewport.x - 114) * viewport.width / s.ui.viewport.x,
        y: 52 * viewport.height / s.ui.viewport.y };
      if (touch) await tap(page, p, true);
      else await page.keyboard.press('Enter');
      event({ event: 'opening_intro_skip', control: 'OpeningSceneSkip', label: 'Skip introduction',
        input: touch ? 'touch' : 'focused Enter', ...(touch ? { point: p } : {}) });
      return null;
    }
    if (s?.dialogue?.visible) {
      const button = s.ui.buttons?.find(b => b.enabled && /^(Skip|Continue|Close)$/.test(b.text));
      if (button) await tap(page, point(button, s, viewport), touch);
    }
    return playable(s) && s.zone === 'greyfen' ? s : null;
  }, 'New Game grants ordinary Greyfen control');
  if (scenario === 'startup') event({ event: 'first_control',
    navigation_ms: await page.evaluate(() => performance.now()),
    performance: (await observe(page))?.performance || null });
  await screenshot(page, 'new-game');
}
async function pause(page, viewport, touch) {
  if (touch) await tap(page, { x: viewport.width - 36, y: 36 }, true);
  else await page.keyboard.press('Escape');
  return waitFor(async () => {
    const s = await observe(page);
    return s?.paused && s.ui?.active_menu === 'pause' ? s : null;
  }, 'real pause input');
}
async function movement(page, viewport, touch) {
  const before = touch ? await stableGameplay(page)
    : await waitFor(async () => { const s = await observe(page); return playable(s) ? s : null; }, 'movement source ready');
  let finger = null;
  try {
    if (touch) {
      // An anchored joystick accepts an ordinary off-centre press. Prove the
      // press itself claims movement, then prove a drag changes its direction;
      // device=touch alone is insufficient because setup may select it.
      finger = await startFinger(page, 72, viewport.height - 112);
      const pressed = await waitFor(async () => {
        const s = await observe(page), a = before.player.position, b = s?.player?.position;
        return b && Math.hypot(b.x - a.x, b.z - a.z) > 0.35 ? s : null;
      }, 'off-centre touch press claims joystick movement', 30000);
      event({ event: 'touch_press_movement', before: before.player.position, after: pressed.player.position });
      const yaw = pressed.camera.yaw;
      const right = { x: Math.cos(yaw), z: -Math.sin(yaw) };
      await finger.move(116, viewport.height - 76);
      try {
        await waitFor(async () => {
          const s = await observe(page), b = s?.player?.position;
          return b && (b.x - pressed.player.position.x) * right.x + (b.z - pressed.player.position.z) * right.z > 0.15;
        }, 'held touch drag changes movement direction', 5000);
        event({ event: 'touch_drag_diagnostic', status: 'pass', before_timestamp: pressed.timestamp,
          after_timestamp: (await observe(page)).timestamp, after: (await observe(page)).player.position });
      } catch (error) {
        const after = await observe(page);
        event({ event: 'touch_drag_diagnostic', status: 'failed_not_functional_acceptance', error: String(error),
          before_timestamp: pressed.timestamp, after_timestamp: after.timestamp,
          before: pressed.player.position, after: after.player.position, input: after.input });
      }
      await finger.end();
      finger = null;
      const steeringStart = await stableGameplay(page);
      finger = await startFinger(page, 116, viewport.height - 76);
      await waitFor(async () => {
        const s = await observe(page), b = s?.player?.position;
        return b && (b.x - steeringStart.player.position.x) * right.x + (b.z - steeringStart.player.position.z) * right.z > 0.15;
      }, 'fresh anchored touch-stick press steers right', 30000);
      event({ event: 'anchored_touch_press_steering', before: steeringStart.player.position,
        after: (await observe(page)).player.position, coverage: 'Fresh press/release steering; held drag is a separate diagnostic' });
    } else await page.keyboard.down('w');
    if (touch) await waitFor(async () => (await observe(page))?.input?.device === 'touch', 'touch device remains selected during movement', 30000);
    await waitFor(async () => {
      const s = await observe(page);
      const a = before.player.position, b = s?.player?.position;
      return b && Math.hypot(b.x - a.x, b.z - a.z) > 0.35 ? s : null;
    }, touch ? 'touch-stick movement' : 'keyboard movement', 30000);
  } finally {
    if (finger) await finger.end().catch(() => {});
    else await page.keyboard.up('w');
  }
  event({ event: 'movement', input: touch ? 'touch-stick' : 'KeyW', before: before.player.position, after: (await observe(page)).player.position });
}
async function importFixture(page, payload, viewport, touch) {
  const state = await observe(page);
  if (state.ui.active_menu !== 'save_library') await clickButton(page, 'Saved Journeys', viewport, touch);
  const path = join(runRoot, `${payload.journey_id}.json`);
  writeFileSync(path, JSON.stringify({ format: 'ashen-oath-save', format_version: 1, save: payload }));
  const picker = page.waitForFileChooser({ timeout: 15000 });
  picker.catch(() => {});
  await clickButton(page, 'Import a Save File', viewport, touch);
  await (await picker).accept([path]);
  await waitFor(async () => {
    const files = await persistence(page);
    return Object.values(files).some(f => f.data?.journey_id === payload.journey_id);
  }, 'fixture imported through the actual file picker');
  await clickButton(page, payload.slot_name, viewport, touch, true);
  await screenshot(page, 'imported-slot');
}
function replaySeed(source, suffix, destination = 'greyfen') {
  const seed = structuredClone(source);
  Object.assign(seed, { game_id: 'ashen-oath', replay_session: true,
    journey_id: `hardening-replay-${suffix}`, slot_name: `Hardening Replay ${suffix}`,
    zone: destination, world_sector: destination, player_position: [0, 1, destination === 'greyfen' ? 7 : 10] });
  delete seed.world_position;
  return seed;
}
async function smoke(page, viewport, touch) {
  await startGame(page, viewport, touch);
  await movement(page, viewport, touch);
  if (scenario === 'startup') event({ event: 'post_movement_performance',
    performance: (await observe(page))?.performance || null });
  await pause(page, viewport, touch);
  await clickButton(page, 'Quick Save', viewport, touch);
  // Filename includes .json; keep the real durable value, never synthesize it.
  const files = await waitFor(async () => { const f = await persistence(page); return f['ashen_oath_save.json']?.data ? f : null; }, 'durable UI Quick Save');
  const source = files['ashen_oath_save.json'].data;
  assert(source.journey_id && !source.replay_session, 'New Game Quick Save must be campaign-owned');
  const expectedPosition = source.player_position;
  await screenshot(page, 'paused-save');
  await enterMenu(page, touch);
  await clickButton(page, 'Continue', viewport, touch);
  const resumed = await waitFor(async () => { const s = await observe(page); return playable(s) ? s : null; }, 'real Continue arrival');
  assert.equal(resumed.zone, source.zone);
  assert(Math.hypot(resumed.player.position.x - expectedPosition[0], resumed.player.position.z - expectedPosition[2]) < 1.5, 'Continue restored another position');
  await screenshot(page, 'continued');
  event({ event: 'durable_continue_restored', journey_id: source.journey_id, position: resumed.player.position,
    saved_position: expectedPosition, zone: resumed.zone });
  if (scenario === 'startup') return source;
  await pause(page, viewport, touch);
  // Continue legitimately schedules campaign autosaves. Force a subsequent UI
  // Quick Save and await its committed IDB generation before taking the byte
  // baseline; a pre-flush baseline can falsely blame those older pending writes
  // on the replay import.
  const previousQuick = (await persistence(page))['ashen_oath_save.json']?.text;
  await sleep(1100);
  const barrierAt = Date.now();
  await clickButton(page, 'Quick Save', viewport, touch);
  await waitFor(async () => {
    const f = (await persistence(page))['ashen_oath_save.json'];
    return f && f.text !== previousQuick && Date.parse(f.data.saved_at_utc + 'Z') >= barrierAt - 1000;
  }, 'post-Continue campaign Quick Save committed');
  const protectedFiles = files => Object.fromEntries(Object.entries(files).filter(([name]) =>
    /^ashen_oath_(save|autosave|checkpoint|before_decision|before_covenant|completed_campaign)\.json(?:\.bak)?$/.test(name)));
  let signature = '', stableSince = 0;
  const campaignBefore = await waitFor(async () => {
    const f = protectedFiles(await persistence(page));
    const next = JSON.stringify(f);
    if (next !== signature) { signature = next; stableSince = Date.now(); return null; }
    return Date.now() - stableSince >= 3000 ? f : null;
  }, 'stable durable campaign baseline after Continue');
  event({ event: 'campaign_baseline_durable', files: Object.fromEntries(Object.entries(campaignBefore).map(([name, f]) =>
    [name, createHash('sha256').update(f.text).digest('hex')])) });
  const seed = replaySeed(source, touch ? 'touch' : 'desktop');
  await importFixture(page, seed, viewport, touch);
  const afterImport = await persistence(page);
  for (const [name, old] of Object.entries(campaignBefore)) assert.equal(afterImport[name]?.text, old.text, `UI import replaced campaign file ${name}`);
  event({ event: 'campaign_unchanged_after_import' });
  await clickButton(page, 'Load This Journey', viewport, touch);
  await waitFor(async () => { const s = await observe(page); return playable(s) && s.zone === 'greyfen' ? s : null; }, 'imported replay arrival');
  await pause(page, viewport, touch);
  await clickButton(page, 'Quick Save', viewport, touch);
  const replayFiles = await waitFor(async () => {
    const f = await persistence(page);
    return f['ashen_oath_replay_save.json']?.data?.journey_id === seed.journey_id ? f : null;
  }, 'replay remains isolated after import and UI Quick Save');
  for (const [name, old] of Object.entries(campaignBefore)) {
    if (/^ashen_oath_(save|autosave|checkpoint|before_decision|before_covenant|completed_campaign)\.json(?:\.bak)?$/.test(name)) {
      assert.equal(replayFiles[name]?.text, old.text, `Imported replay replaced campaign file ${name}`);
    }
  }
  assert.equal(replayFiles['ashen_oath_replay_save.json'].data.replay_session, true);
  await screenshot(page, 'replay-isolated');
  event({ event: 'durable_replay_isolation', journey_id: seed.journey_id });
  return source;
}
async function metadata(page, viewport, touch) {
  const failed = await waitFor(async () => {
    const s = await observe(page);
    return s?.ui?.buttons?.some(b => b.enabled && /Retry/i.test(b.text)) ? s : null;
  }, 'stalled metadata surfaces a recoverable Retry', 45000);
  assert(fault.hits > 0, 'Metadata fault was not exercised');
  await screenshot(page, 'metadata-failed');
  const retry = failed.ui.buttons.find(b => b.enabled && /Retry/i.test(b.text));
  const initialHits = fault.hits;
  const retriedPath = fault.path;
  armFault('', '');
  await clickButton(page, retry.text, viewport, touch);
  await waitFor(async () => (await observe(page))?.new_game_ready, 'Retry obtains metadata and prepares New Game');
  assert(report.requests.filter(r => r.scenario === currentCase.name && r.path === retriedPath).length > initialHits, 'Retry reused a poisoned metadata promise');
  await startGame(page, viewport, touch);
  event({ event: 'metadata_retry_recovered', stalled_requests: initialHits });
}
async function routeTo(page, gateId) {
  const cache = observations.get(page);
  const requestId = ++cache.routeSerial;
  await page.evaluate(query => { window.__ashenOathReadOnlyRouteQuery = query; },
    { request_id: requestId, target_id: gateId });
  const route = await waitFor(() => cache.route?.request_id === requestId ? cache.route : null, 'read-only physical gate route', 30000);
  assert(route.read_only && route.ok && route.physical_connection, 'Gate route must be an ordinary physical connection');
  return route;
}
async function followPhysicalRoute(page, viewport, touch, route) {
  const waypoints = [...route.points, { x: route.crossing_point.x + route.crossing_direction.x * 0.8,
    y: route.crossing_point.y, z: route.crossing_point.z + route.crossing_direction.z * 0.8 }];
  const pressed = new Set();
  let finger = null;
  let fingerDirection = null;
  const deadline = Date.now() + timeoutMs;
  try {
    for (const waypoint of waypoints) {
      while (Date.now() < deadline) {
        const s = await observe(page);
        if (s?.ui?.loading_visible) return s;
        assert(s?.zone === 'greyfen', 'Physical route left Greyfen without the held download gate');
        const dx = waypoint.x - s.player.position.x, dz = waypoint.z - s.player.position.z;
        const distance = Math.hypot(dx, dz);
        if (distance < 0.35) break;
        const yaw = s.camera.yaw;
        const forward = (-Math.sin(yaw) * dx - Math.cos(yaw) * dz) / distance;
        const right = (Math.cos(yaw) * dx - Math.sin(yaw) * dz) / distance;
        if (touch) {
          const origin = { x: 72, y: viewport.height - 76 };
          // Ordinary anchored-pad press steering. Fresh off-centre contacts
          // avoid relying on the separately reported CDP held-drag diagnostic.
          if (!finger || !fingerDirection || Math.hypot(right - fingerDirection.right, forward - fingerDirection.forward) > 0.15) {
            if (finger) await finger.end();
            finger = await startFinger(page, origin.x + right * 36, origin.y - forward * 36);
            fingerDirection = { right, forward };
          }
        } else {
          const desired = new Set([...(forward > 0.3 ? ['w'] : forward < -0.3 ? ['s'] : []), ...(right > 0.3 ? ['d'] : right < -0.3 ? ['a'] : [])]);
          for (const key of pressed) if (!desired.has(key)) { await page.keyboard.up(key); pressed.delete(key); }
          for (const key of desired) if (!pressed.has(key)) { await page.keyboard.down(key); pressed.add(key); }
        }
        await sleep(150);
        await waitFor(async () => { const next = await observe(page); return next?.timestamp > s.timestamp ? next : null; }, 'fresh physical movement observation', 30000);
      }
      assert(Date.now() < deadline, 'Physical route deadline expired');
    }
    return waitFor(async () => { const s = await observe(page); return s?.ui?.loading_visible ? s : null; }, 'physical boundary opens destination loading UI', 10000);
  } finally {
    for (const key of pressed) await page.keyboard.up(key).catch(() => {});
    if (finger) await finger.end().catch(() => {});
  }
}
async function cancelTravel(page, viewport, touch) {
  if (!touch) { await page.keyboard.press('Escape'); return; }
  // Frozen observer omits overlay buttons. Authored _loading_layout is a
  // centered 600x220 CSS card; compact padding16 and the last VBox child has
  // height48. At the required960x540/default text scale this is(480,340).
  // The preceding screenshot records the visible Cancel and Return target.
  assert.equal(viewport.width, 960);
  assert.equal(viewport.height, 540);
  await tap(page, { x: 480, y: 340 }, true);
  event({ event: 'mobile_cancel_input', input: 'touch Cancel and Return', point: { x: 480, y: 340 } });
}
async function cold(page, viewport, touch, source) {
  // Import from the prepared main menu, so background destination prefetch does
  // not spend most of its own network deadline while a separate New Game runs.
  await waitFor(async () => (await observe(page))?.new_game_ready, 'main menu prepared for physical-travel fixture');
  const minimal = source || { version: 13, game_id: 'ashen-oath', zone: 'greyfen', inventory: { items: {}, ingredients: {} },
    quests: { active: {}, completed: {}, unlocked: {} }, story_state: { flags: {}, values: {}, evidence: {} }, world_state: {} };
  const seed = replaySeed(minimal, touch ? 'cold-gate-touch' : 'cold-gate-desktop');
  seed.player_position = [0, 1, -12];
  seed.quests.active.main_road_of_crows = { objectives: [{ id: 'speak_anwen', done: true }] };
  await importFixture(page, seed, viewport, touch);
  await clickButton(page, 'Load This Journey', viewport, touch);
  await waitFor(async () => { const s = await observe(page); return playable(s) && s.zone === 'greyfen' ? s : null; }, 'Greyfen physical-travel fixture arrival');
  await stableGameplay(page);
  const first = await followPhysicalRoute(page, viewport, touch, await routeTo(page, 'gate_wychwood'));
  assert(fault.hits > 0 && heldDownloads.size > 0, 'Cold adjacent download was not actually held');
  await screenshot(page, 'physical-travel-loading');
  await cancelTravel(page, viewport, touch);
  const cancelled = await waitFor(async () => { const s = await observe(page); return playable(s) && s.zone === 'greyfen' ? s : null; }, 'physical Cancel restores source gameplay');
  assert(Math.hypot(cancelled.player.position.x - first.player.position.x, cancelled.player.position.z - first.player.position.z) < 0.5, 'Cancel moved source player');
  await screenshot(page, 'physical-travel-cancelled');
  event({ event: 'physical_travel_cancelled', source: cancelled.player.position, shared_download_may_continue: true });
  // Re-approach using real input. Cancellation can legitimately leave the same
  // shared download alive; require a held request, never a second network fetch.
  const pendingStart = await followPhysicalRoute(page, viewport, touch, await routeTo(page, 'gate_wychwood'));
  const travelAt = Date.now();
  event({ event: 'physical_travel_retry_loading', at: travelAt });
  await sleep(22000);
  const pending = await observe(page);
  assert.equal(pending.zone, 'greyfen', 'Download replaced the source before destination readiness');
  assert(pending.ui.loading_visible, 'Physical travel failed before its 32-second download hold');
  assert(Math.hypot(pending.player.position.x - pendingStart.player.position.x, pending.player.position.z - pendingStart.player.position.z) < 0.5, 'Pending download moved the source player');
  await screenshot(page, 'physical-travel-22s-source-preserved');
  await sleep(Math.max(0, travelAt + 32000 - Date.now()));
  assert(heldDownloads.size > 0, 'No healthy shared request remained held until 32 seconds');
  armFault('', '');
  for (const held of [...heldDownloads]) { held.record.released_at = Date.now(); held.send(); }
  await waitFor(async () => { const s = await observe(page); return playable(s) && s.zone === 'wychwood' ? s : null; }, '32-second physical Wychwood arrival');
  event({ event: 'physical_cold_travel_arrived', hold_after_travel_ui_ms: Date.now() - travelAt, zone: 'wychwood', input: touch ? 'touch-stick' : 'WASD' });
  await screenshot(page, 'physical-cold-arrival');
}
async function runCase(name, touch, body, beforeNavigate = () => {}) {
  currentCase = { name, viewport: touch ? { width: 960, height: 540 } : { width: 1280, height: 720 },
    input: touch ? 'touch' : 'keyboard_mouse', status: 'running', events: [], screenshots: [], console: [], dom_input: [], started_at: new Date().toISOString() };
  report.cases.push(currentCase);
  console.log(`HARDENING CASE START: ${name} ${JSON.stringify(currentCase.viewport)}`);
  const result = currentCase;
  const context = await browser.createBrowserContext();
  const page = await context.newPage();
  if (options['light-loop-candidate']) {
    const source = readFileSync(resolve('web_boot_shell.html'), 'utf8').match(/<script id="ashen-bounded-light-loops">([\s\S]*?)<\/script>/)?.[1];
    assert(source, 'Bounded light loop source is missing');
    await page.evaluateOnNewDocument(source);
  }
  const cache = { latest: null, route: null, routeSerial: 0, phase: '' };
  observations.set(page, cache);
  await page.exposeFunction('__ASHEN_OATH_READ_ONLY_OBSERVATION__', payload => {
    try {
      const s = JSON.parse(payload);
      cache.latest = { timestamp: s.timestamp_ms, read_only: s.read_only, ready: s.ready, zone: s.zone,
        paused: s.paused, new_game_ready: s.new_game_ready, transition_pending: s.transition_pending,
        zone_load_request_pending: s.zone_load_request_pending, player: s.player, camera: s.camera,
        ui: s.ui, dialogue: s.dialogue, input: s.input, runtime_packs: s.runtime_packs,
        gates: s.gates, interactions: s.interactions, focus: s.focus,
        enemies: s.enemies, inventory: s.inventory, settings: s.settings, performance: s.performance };
      const phase = JSON.stringify([s.zone, s.ready, s.paused, s.ui?.active_menu, s.ui?.loading_visible, s.new_game_ready]);
      if (phase !== cache.phase) { cache.phase = phase; console.log(`HARDENING STATE: ${result.name} ${phase}`); }
    } catch { /* Ignore non-observation payloads. */ }
  });
  await page.exposeFunction('__HARDENING_ROUTE_OBSERVATION__', value => { cache.route = value; });
  await page.exposeFunction('__HARDENING_DOM_INPUT__', value => {
    if (result.dom_input.length < 400) result.dom_input.push(value);
  });
  await page.evaluateOnNewDocument(() => {
    let result = null;
    Object.defineProperty(window, '__ashenOathReadOnlyRouteResult', { configurable: true, get: () => result,
      set(value) { result = value; if (value?.read_only) window.__HARDENING_ROUTE_OBSERVATION__(value); } });
    // Passive capture observes delivery only. Never preventDefault, synthesize
    // DOM events or call a gameplay function to make an input check pass.
    for (const name of ['touchstart', 'touchmove', 'touchend', 'touchcancel', 'pointerdown', 'pointermove', 'pointerup', 'mousedown', 'mousemove', 'mouseup', 'keydown', 'keyup']) {
      window.addEventListener(name, event => {
        const point = event.changedTouches?.[0] || event;
        const rect = event.target?.getBoundingClientRect?.();
        window.__HARDENING_DOM_INPUT__({ type: event.type, trusted: event.isTrusted,
          target: event.target?.id || event.target?.tagName, x: point.clientX, y: point.clientY,
          pointer_type: event.pointerType, touches: event.touches?.length,
          key: event.key, code: event.code, repeat: event.repeat,
          movement_x: event.movementX, movement_y: event.movementY,
          fires_touch_events: event.sourceCapabilities?.firesTouchEvents,
          focused: document.hasFocus(), platform: navigator.platform,
          active_element: document.activeElement?.id || document.activeElement?.tagName,
          pointer_lock_element: document.pointerLockElement?.id,
          target_rect: rect ? { x: rect.x, y: rect.y, width: rect.width, height: rect.height } : null,
          at: performance.timeOrigin + performance.now() });
      }, { capture: true, passive: true });
    }
  });
  await page.setViewport({ ...currentCase.viewport, deviceScaleFactor: 1, isMobile: touch, hasTouch: touch });
  if (touch) {
    cache.input = await page.createCDPSession();
    await cache.input.send('Emulation.setTouchEmulationEnabled', { enabled: true, maxTouchPoints: 5 });
    await cache.input.send('Emulation.setUserAgentOverride', {
      userAgent: 'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Mobile Safari/537.36',
      platform: 'Android',
    });
    await cache.input.send('Emulation.setFocusEmulationEnabled', { enabled: true });
  }
  await page.bringToFront();
  if (options['webgl-profile']) await page.evaluateOnNewDocument(readFileSync(new URL('./webgl_startup_probe.js', import.meta.url), 'utf8'));
  page.setDefaultTimeout(15000);
  page.on('console', message => {
    result.console.push({ type: message.type(), text: message.text(), at: Date.now() });
    if (fault.kind === 'opening_unavailable'
        && /^Runtime pack opening failed: Error: opening pack HTTP 503$/.test(message.text())) {
      (result.expected_fault_errors ||= []).push(message.text());
      return;
    }
    if (/SCRIPT ERROR|Parse Error|\bERROR:|memory access out of bounds|RuntimeError:|Aborted\(/i.test(message.text())) runtimeErrors.push(message.text());
  });
  page.on('pageerror', error => { runtimeErrors.push(String(error)); result.console.push({ type: 'pageerror', text: String(error) }); });
  try {
    beforeNavigate();
    await enterMenu(page, touch);
    const returned = await body(page, currentCase.viewport, touch);
    result.status = 'pass';
    return returned;
  } catch (error) {
    result.status = 'fail'; result.error = String(error.stack || error);
    result.last_observation = await observe(page).catch(() => null);
    await screenshot(page, 'failure').catch(() => {});
    throw error;
  } finally {
    result.finished_at = new Date().toISOString();
    writeFileSync(reportPath, JSON.stringify(report, null, 2));
    await boundedClose(context.close());
    armFault('', '');
  }
}

try {
  if (options.inspect) {
    report.status = 'inputs_validated_not_executed';
    report.limits.push('--inspect does not execute browser tests');
  } else {
    const executable = options.browser || ['C:/Program Files/Google/Chrome/Application/chrome.exe',
      'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe'].find(existsSync);
    assert(executable && existsSync(executable), 'Chromium executable not found; pass --browser PATH');
    browser = await puppeteer.launch({ executablePath: executable, userDataDir: profile,
      headless: !options.headful, protocolTimeout: 120000,
      args: ['--no-sandbox', '--no-first-run', '--no-default-browser-check', '--disable-background-networking',
        '--disable-component-update', '--force-device-scale-factor=1'] });
    report.browser = { executable, version: await browser.version(), headless: !options.headful };
    let source;
    if (['all', 'startup', 'smoke'].includes(scenario)) {
      const startupDelay = () => {
        if (scenario === 'startup' && options['delay-opening']) {
          const delay = Number(options['delay-opening']);
          assert(Number.isFinite(delay) && delay > 0 && delay <= 60000, 'Invalid --delay-opening');
          armFault('cold_delay', new URL(packs.packs.opening.url, origin).pathname.replace(/^\//, ''), delay);
          currentCase.controlled_download_delay_ms = delay;
        }
      };
      if (mode !== 'touch') source = await runCase('desktop-smoke', false, smoke, startupDelay);
      if (mode !== 'desktop') await runCase('touch-smoke', true, smoke, startupDelay);
    }
    if (['all', 'metadata'].includes(scenario)) {
      for (const touch of mode === 'both' ? [false, true] : [mode === 'touch']) {
        for (const kind of metadataFaults) {
          await runCase(`${touch ? 'touch' : 'desktop'}-${kind}`, touch, metadata,
            () => armFault(kind, kind === 'opening_unavailable'
              ? new URL(packs.packs.opening.url, origin).pathname.replace(/^\//, '') : 'runtime_pack_manifest.json'));
        }
      }
    }
    if (['all', 'cold'].includes(scenario)) {
      for (const touch of mode === 'both' ? [false, true] : [mode === 'touch']) {
        await runCase(`${touch ? 'touch' : 'desktop'}-physical-cold-travel`, touch,
          (page, viewport) => cold(page, viewport, touch, source),
          () => armFault('cold_hold', new URL(packs.packs.adjacent.url, origin).pathname.replace(/^\//, '')));
      }
    }
    if (scenario === 'combat') {
      const helpers = { observe, waitFor, stableGameplay, clickButton, tap, startFinger,
        pause, importFixture, screenshot, event, sleep };
      for (const touch of mode === 'both' ? [false, true] : [mode === 'touch']) {
        await runCase(`${touch ? 'touch' : 'desktop'}-combat-${combatPhase}`, touch,
          (page, viewport) => combatModule.runCombatCase({ page, viewport, touch, helpers, source, phase: combatPhase }));
      }
    }
    assert.equal(runtimeErrors.length, 0, `Engine/browser errors: ${runtimeErrors.join('\n')}`);
    report.status = 'pass';
  }
} catch (error) {
  report.status = 'fail'; report.error = String(error.stack || error); process.exitCode = 1;
} finally {
  if (browser) {
    const pid = browser.process()?.pid;
    await boundedClose(browser.close());
    if (browser.connected && pid) spawnSync('taskkill', ['/PID', String(pid), '/T', '/F'], { windowsHide: true });
  }
  server.closeAllConnections();
  await new Promise(resolveClose => server.close(resolveClose));
  report.finished_at = new Date().toISOString();
  report.runtime_errors = runtimeErrors;
  if (!options['keep-profile'] && report.status !== 'fail' && existsSync(profile)) {
    assert(resolve(profile).startsWith(resolve(temporaryRoot) + sep) && dirname(profile) === runRoot, 'Unsafe profile cleanup target');
    try { rmSync(profile, { recursive: true, force: true, maxRetries: 5, retryDelay: 200 }); }
    catch (error) { report.profile_cleanup_error = String(error); }
  }
  report.profile = existsSync(profile) ? profile : null;
  mkdirSync(dirname(reportPath), { recursive: true });
  writeFileSync(reportPath, JSON.stringify(report, null, 2));
  console.log(`HARDENING BROWSER: ${report.status.toUpperCase()} build=${report.build_id} report=${reportPath}`);
}
