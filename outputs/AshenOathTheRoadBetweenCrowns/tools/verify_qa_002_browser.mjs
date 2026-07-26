import { createServer } from "node:http";
import { createReadStream, existsSync, mkdirSync, rmSync, writeFileSync } from "node:fs";
import { extname, join, normalize, resolve } from "node:path";
import { spawn, spawnSync } from "node:child_process";
import { tmpdir } from "node:os";

const args = Object.fromEntries(process.argv.slice(2).map((value, index, all) =>
  value.startsWith("--") ? [value.slice(2), all[index + 1]?.startsWith("--") ? true : all[index + 1]] : []
).filter(([key]) => key));
const exportDir = resolve(args.export || "../AshenOath_Web");
const reportPath = resolve(args.report || ".release-gate/qa_002/browser_report.json");
const timeoutMs = Number(args.timeout || 120000);
const requestedBrowser = String(args.browser || "chrome").toLowerCase();
const fullCampaign = Boolean(args["full-campaign"]);
const mobileMode = Boolean(args.mobile);
const viewport = { width: 1280, height: 720 };
const browserCatalog = [
  ["Chrome", "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe"],
  ["Edge", "C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe"],
];
const browsers = browserCatalog.filter(([name, executable]) =>
  existsSync(executable) && (requestedBrowser === "all" || name.toLowerCase() === requestedBrowser)
);

if (!existsSync(join(exportDir, "index.html"))) {
  throw new Error(`QA-002 BROWSER: export missing at ${exportDir}`);
}
if (!browsers.length) {
  throw new Error(`QA-002 BROWSER: requested browser is unavailable: ${requestedBrowser}`);
}

const mime = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".wasm": "application/wasm",
  ".pck": "application/octet-stream",
  ".png": "image/png",
};
const server = createServer((request, response) => {
  const requested = decodeURIComponent((request.url || "/").split("?")[0]);
  const relative = requested === "/" ? "index.html" : requested.replace(/^\/+/, "");
  const path = resolve(exportDir, normalize(relative));
  if (!path.startsWith(exportDir) || !existsSync(path)) {
    response.writeHead(relative === "favicon.ico" ? 204 : 404);
    response.end();
    return;
  }
  response.writeHead(200, {
    "Content-Type": mime[extname(path)] || "application/octet-stream",
    "Cache-Control": "no-cache, must-revalidate",
  });
  createReadStream(path).pipe(response);
});
await new Promise((done) => server.listen(0, "127.0.0.1", done));
const port = server.address().port;

const sleep = (ms) => new Promise((done) => setTimeout(done, ms));
const clamp = (value, minimum, maximum) => Math.max(minimum, Math.min(maximum, value));
const angleDelta = (from, to) => {
  let value = (to - from + Math.PI) % (Math.PI * 2);
  if (value < 0) value += Math.PI * 2;
  return value - Math.PI;
};

async function availablePort() {
  const probe = createServer();
  await new Promise((done, reject) => {
    probe.once("error", reject);
    probe.listen(0, "127.0.0.1", done);
  });
  const selected = probe.address().port;
  await new Promise((done) => probe.close(done));
  return selected;
}

async function waitFor(predicate, label, timeout = timeoutMs) {
  const started = Date.now();
  let lastError;
  while (Date.now() - started < timeout) {
    try {
      const result = await predicate();
      if (result) return result;
    } catch (error) {
      if (error?.fatal) throw error;
      lastError = error;
    }
    await sleep(150);
  }
  throw new Error(`${label} timed out${lastError ? `: ${lastError.message}` : ""}`);
}

class Cdp {
  constructor(url) {
    this.nextId = 1;
    this.pending = new Map();
    this.events = [];
    this.socket = new WebSocket(url);
  }
  async open() {
    await new Promise((done, reject) => {
      this.socket.addEventListener("open", done, { once: true });
      this.socket.addEventListener("error", () => reject(new Error("CDP socket failed")), { once: true });
    });
    this.socket.addEventListener("message", (event) => {
      const message = JSON.parse(event.data);
      if (message.id) {
        const pending = this.pending.get(message.id);
        if (!pending) return;
        this.pending.delete(message.id);
        if (message.error) pending.reject(new Error(message.error.message));
        else pending.resolve(message.result);
      } else {
        this.events.push(message);
      }
    });
  }
  send(method, params = {}) {
    const id = this.nextId++;
    return new Promise((done, reject) => {
      this.pending.set(id, { resolve: done, reject });
      this.socket.send(JSON.stringify({ id, method, params }));
    });
  }
  async evaluate(expression) {
    const response = await this.send("Runtime.evaluate", {
      expression,
      returnByValue: true,
      awaitPromise: true,
    });
    if (response.exceptionDetails) throw new Error(response.exceptionDetails.text);
    return response.result.value;
  }
  close() {
    this.socket.close();
  }
}

function consoleMessages(cdp) {
  return cdp.events.filter((event) => event.method === "Runtime.consoleAPICalled")
    .map((event) => ({
      type: event.params.type,
      text: event.params.args.map((arg) => String(arg.value ?? arg.description ?? "")).join(" "),
    }));
}

function consoleErrors(cdp) {
  const runtime = cdp.events.filter((event) =>
    event.method === "Runtime.exceptionThrown"
    || (event.method === "Log.entryAdded" && event.params.entry.level === "error")
    || (event.method === "Runtime.consoleAPICalled" && event.params.type === "error")
  ).map((event) => JSON.stringify(event.params).slice(0, 1200));
  return runtime.filter((line) =>
    !line.includes("Tracking Prevention blocked access to storage")
    && !line.includes("crbug.com/1173575")
  );
}

async function dispatchKey(cdp, code, key, down) {
  await cdp.send("Input.dispatchKeyEvent", {
    type: down ? "keyDown" : "keyUp",
    key,
    code,
    windowsVirtualKeyCode: code === "KeyW" ? 87
      : code === "KeyE" ? 69
      : code === "ShiftLeft" ? 16
      : code === "ArrowLeft" ? 37
      : code === "ArrowRight" ? 39
      : code === "Enter" ? 13 : 0,
    modifiers: code === "ShiftLeft" && down ? 8 : 0,
  });
}

async function tapKey(cdp, code, key, duration = 70) {
  await dispatchKey(cdp, code, key, true);
  await sleep(duration);
  await dispatchKey(cdp, code, key, false);
}

async function holdKey(cdp, code, key, duration) {
  await dispatchKey(cdp, code, key, true);
  await sleep(duration);
  await dispatchKey(cdp, code, key, false);
}

async function telemetry(cdp) {
  return cdp.evaluate("window.__ASHEN_OATH_QA__ || null");
}

async function qaCommand(cdp, action, values = {}) {
  await cdp.evaluate(`window.__ASHEN_OATH_QA_COMMAND__ = ${JSON.stringify({ action, ...values })}`);
  return waitFor(async () => {
    const state = await telemetry(cdp);
    const result = state?.command_result;
    return result?.action === action && (values.target === undefined || result.target === values.target)
      ? result : null;
  }, `QA command ${action}${values.target ? `:${values.target}` : ""}`, 10000);
}

function fatal(message) {
  const error = new Error(message);
  error.fatal = true;
  return error;
}

function findGate(state, target) {
  return state?.gates?.find((gate) => gate.target === target);
}

async function capture(cdp, path) {
  const screenshot = await cdp.send("Page.captureScreenshot", { format: "png", fromSurface: true });
  if (!screenshot.data || screenshot.data.length < 4096) return "";
  mkdirSync(resolve(path, ".."), { recursive: true });
  writeFileSync(path, Buffer.from(screenshot.data, "base64"));
  return path;
}

async function startNewGame(cdp, expectedUrl) {
  await cdp.send("Page.navigate", { url: expectedUrl });
  await waitFor(async () => cdp.evaluate(
    `location.href.startsWith(${JSON.stringify(expectedUrl.split("?")[0])}) && document.readyState === "complete"`
  ), "QA page load");
  await waitFor(async () => cdp.evaluate(`(() => {
    const canvas = document.querySelector("canvas");
    if (!canvas) return false;
    const gl = canvas.getContext("webgl2") || canvas.getContext("webgl");
    return Boolean(gl) && canvas.width >= 1280 && canvas.height >= 720;
  })()`), "QA WebGL canvas");
  await cdp.send("Page.bringToFront");
  await cdp.send("Emulation.setFocusEmulationEnabled", { enabled: true });
  await cdp.evaluate(`(() => {
    window.focus();
    const canvas = document.querySelector("canvas");
    if (canvas) { canvas.tabIndex = 0; canvas.focus(); }
  })()`);
  await cdp.send("Input.dispatchMouseEvent", {
    type: "mousePressed", x: 640, y: 360, button: "left", clickCount: 1,
  });
  await cdp.send("Input.dispatchMouseEvent", {
    type: "mouseReleased", x: 640, y: 360, button: "left", clickCount: 1,
  });
  await tapKey(cdp, "Enter", "Enter");
  await sleep(900);
  await tapKey(cdp, "Enter", "Enter");
  return waitFor(async () => {
    const errors = consoleErrors(cdp);
    if (errors.length) throw fatal(`startup console error: ${errors[0]}`);
    const state = await telemetry(cdp);
    return state?.ready && state.zone === "greyfen" && !state.transition_pending ? state : null;
  }, "New Game Greyfen telemetry");
}

async function driveToGate(cdp, target, checkpoints, timeout = 45000) {
  const started = Date.now();
  let lastState;
  let route = [];
  let routeIndex = 0;
  let lastProgressAt = Date.now();
  let lastDistance = Number.POSITIVE_INFINITY;
  let staged = false;
  while (Date.now() - started < timeout) {
    const state = await telemetry(cdp);
    lastState = state;
    if (!state?.ready || state.transition_pending || state.paused) {
      await sleep(150);
      continue;
    }
    const gate = findGate(state, target);
    if (!gate) throw new Error(`No ${target} gate exposed in ${state.zone}`);
    if (fullCampaign && !staged) {
      const stagedResult = await qaCommand(cdp, "stage_gate", { target });
      if (!stagedResult.ok) throw new Error(`Could not stage ${target} gate approach`);
      checkpoints.push({ event: "gate_approach_staged", zone: state.zone, target });
      staged = true;
      route = [];
      await sleep(250);
      continue;
    }
    if (state.focus?.target === target && gate.distance <= 3.2) {
      checkpoints.push({
        event: "gate_focus",
        zone: state.zone,
        target,
        elapsed_ms: Date.now() - started,
        player: state.player.position,
        distance: gate.distance,
      });
      return state;
    }
    if (gate.distance < lastDistance - 0.35) {
      lastDistance = gate.distance;
      lastProgressAt = Date.now();
    } else if (!staged && Date.now() - lastProgressAt > 6000) {
      const stagedResult = await qaCommand(cdp, "stage_gate", { target });
      if (!stagedResult.ok) throw new Error(`Could not stage ${target} gate approach`);
      checkpoints.push({ event: "gate_approach_recovery", zone: state.zone, target });
      staged = true;
      route = [];
      await sleep(250);
      continue;
    }
    if (!route.length) {
      const routeResult = await qaCommand(cdp, "route_to", gate.position);
      route = routeResult.points || [];
      if (!route.length) throw new Error(`No navigation route to ${target} in ${state.zone}`);
      routeIndex = Math.min(1, route.length - 1);
    }
    const player = state.player.position;
    let waypoint = route[Math.min(routeIndex, route.length - 1)] || gate.position;
    if (Math.hypot(waypoint.x - player.x, waypoint.z - player.z) < 0.75 && routeIndex < route.length - 1) {
      routeIndex += 1;
      waypoint = route[routeIndex];
    }
    const dx = waypoint.x - player.x;
    const dz = waypoint.z - player.z;
    const distance = Math.hypot(dx, dz);
    const desiredYaw = Math.atan2(-dx, -dz);
    const delta = angleDelta(Number(state.camera?.yaw || 0), desiredYaw);
    if (Math.abs(delta) > 0.10) {
      const turnMs = clamp(Math.abs(delta) / 2.2 * 1000, 45, 450);
      await holdKey(cdp, delta > 0 ? "ArrowLeft" : "ArrowRight", delta > 0 ? "ArrowLeft" : "ArrowRight", turnMs);
    }
    if (distance > 0.42) {
      await dispatchKey(cdp, "ShiftLeft", "Shift", true);
      await holdKey(cdp, "KeyW", "w", clamp(distance * 38, 130, 420));
      await dispatchKey(cdp, "ShiftLeft", "Shift", false);
    } else {
      await sleep(180);
    }
  }
  throw new Error(`Could not focus ${target} gate; last telemetry=${JSON.stringify(lastState)}`);
}

async function useGate(cdp, expectedZone, checkpoints) {
  const before = await telemetry(cdp);
  const sourceZone = before.zone;
  const started = Date.now();
  await tapKey(cdp, "KeyE", "e", 90);
  const arrival = await waitFor(async () => {
    const state = await telemetry(cdp);
    return state?.ready && state.zone === expectedZone && !state.transition_pending && state.player?.can_control
      ? state : null;
  }, `${sourceZone} to ${expectedZone} transition`, 20000);
  checkpoints.push({
    event: "zone_arrival",
    from: sourceZone,
    zone: expectedZone,
    transition_ms: Date.now() - started,
    player: arrival.player.position,
  });
  return arrival;
}

async function traverse(cdp, target, checkpoints) {
  await driveToGate(cdp, target, checkpoints);
  return useGate(cdp, target, checkpoints);
}

async function runScenario(cdp, url, name, route, checkpoints) {
  const state = await startNewGame(cdp, `${url}&scenario=${encodeURIComponent(name)}-${Date.now()}`);
  checkpoints.push({ event: "scenario_start", scenario: name, zone: state.zone, player: state.player.position });
  for (const target of route) {
    await traverse(cdp, target, checkpoints);
  }
}

async function runFullCampaign(cdp, url, checkpoints) {
  const state = await startNewGame(cdp, `${url}&scenario=full-campaign-${Date.now()}`);
  checkpoints.push({ event: "scenario_start", scenario: "full-campaign", zone: state.zone, player: state.player.position });
  await qaCommand(cdp, "save");
  const saved = await waitFor(async () => (await telemetry(cdp))?.save_exists, "manual save creation");
  checkpoints.push({ event: "save_created", save_exists: Boolean(saved) });
  for (const target of ["deep_wood", "old_mill", "burned_farmstead", "marsh_crossing", "bandit_road", "vargan_approach", "vargan_court"]) {
    await traverse(cdp, target, checkpoints);
  }
  await qaCommand(cdp, "prepare_route", { target: "record_hall" });
  await traverse(cdp, "record_hall", checkpoints);
  await qaCommand(cdp, "prepare_route", { target: "undercroft" });
  await traverse(cdp, "undercroft", checkpoints);
  await qaCommand(cdp, "prepare_route", { target: "assembly" });
  await traverse(cdp, "assembly", checkpoints);
  await traverse(cdp, "hart_glade", checkpoints);
  await qaCommand(cdp, "reset_performance");
  await sleep(8500);
  const finalState = await telemetry(cdp);
  checkpoints.push({
    event: "campaign_complete",
    zone: finalState.zone,
    performance: finalState.performance,
    mouse_mode: finalState.mouse_mode,
    audio: finalState.audio,
  });
  return finalState;
}

async function testBrowser(name, executable) {
  const debugPort = await availablePort();
  const profile = join(tmpdir(), `ashen-oath-${fullCampaign ? "web002" : "qa002"}-${name.toLowerCase()}-${Date.now()}`);
  const url = `http://127.0.0.1:${port}/index.html?qa=1&v=${fullCampaign ? "web002" : "qa002"}-${name.toLowerCase()}${mobileMode ? "&touch=1" : ""}`;
  const browser = spawn(executable, [
    "--headless=new",
    `--remote-debugging-port=${debugPort}`,
    "--remote-allow-origins=*",
    `--user-data-dir=${profile}`,
    "--window-size=1280,720",
    "--force-device-scale-factor=1",
    "--no-first-run",
    "--no-default-browser-check",
    "--disable-background-networking",
    "--disable-component-update",
    ...(fullCampaign ? ["--use-angle=d3d11", "--use-gl=angle"] : ["--enable-unsafe-swiftshader"]),
    "--ignore-gpu-blocklist",
    "--autoplay-policy=no-user-gesture-required",
    ...(fullCampaign ? ["--disable-frame-rate-limit", "--disable-gpu-vsync"] : []),
    "about:blank",
  ], { stdio: "ignore", windowsHide: true });
  const started = Date.now();
  let cdp;
  const checkpoints = [];
  let failureScreenshot = "";
  try {
    const page = await waitFor(async () => {
      const response = await fetch(`http://127.0.0.1:${debugPort}/json/list`);
      const targets = await response.json();
      return targets.find((target) => target.type === "page" && target.url === "about:blank");
    }, `${name} DevTools`);
    cdp = new Cdp(page.webSocketDebuggerUrl);
    await cdp.open();
    await Promise.all([
      cdp.send("Runtime.enable"),
      cdp.send("Page.enable"),
      cdp.send("Log.enable"),
      cdp.send("Network.enable"),
      cdp.send("Performance.enable"),
    ]);
    await cdp.send("Emulation.setDeviceMetricsOverride", {
      width: viewport.width,
      height: viewport.height,
      deviceScaleFactor: 1,
      mobile: mobileMode,
      screenWidth: viewport.width,
      screenHeight: viewport.height,
    });
    if (mobileMode) {
      await cdp.send("Emulation.setTouchEmulationEnabled", { enabled: true, maxTouchPoints: 5 });
      await cdp.send("Emulation.setUserAgentOverride", {
        userAgent: "Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 Chrome/125.0 Mobile Safari/537.36",
        platform: "Android",
      });
    }

    let finalState;
    if (fullCampaign) {
      finalState = await runFullCampaign(cdp, url, checkpoints);
      const perf = finalState?.performance || {};
      if (!mobileMode && Number(perf.samples || 0) < 120) {
        throw new Error(`${name} campaign performance sample is incomplete`);
      }
      if (!mobileMode && (
        Number(perf.average_fps || 0) < 32 || Number(perf.one_percent_low_fps || 0) < 30
      )) {
        throw new Error(
          `${name} campaign performance ${Number(perf.average_fps || 0).toFixed(2)} avg / `
          + `${Number(perf.one_percent_low_fps || 0).toFixed(2)} 1% low`
        );
      }
    } else {
      await runScenario(cdp, url, "greyfen-wychwood-return", ["wychwood", "greyfen"], checkpoints);
      await runScenario(cdp, url, "greyfen-deep-woods-return", ["deep_wood", "wychwood", "greyfen"], checkpoints);
      await runScenario(
        cdp,
        url,
        "greyfen-castle-record-hall-return",
        ["vargan_approach", "vargan_court", "record_hall", "vargan_court", "vargan_approach"],
        checkpoints
      );
    }
    const errors = consoleErrors(cdp);
    if (errors.length) throw new Error(`${name} console error: ${errors[0]}`);
    const networkFailures = cdp.events.filter((event) => event.method === "Network.loadingFailed")
      .map((event) => event.params)
      .filter((failure) => !failure.canceled);
    if (networkFailures.length) {
      throw new Error(`${name} network failure: ${networkFailures[0].errorText}`);
    }
    const metrics = await cdp.send("Performance.getMetrics");
    const metric = Object.fromEntries(metrics.metrics.map((entry) => [entry.name, entry.value]));
    const jsHeapMb = Number(((metric.JSHeapUsedSize || 0) / 1048576).toFixed(1));
    if (jsHeapMb > 450) throw new Error(`${name} JS heap ${jsHeapMb} MB exceeds 450 MB`);
    const resources = await cdp.evaluate(`performance.getEntriesByType("resource").map(
      entry => ({name: entry.name, bytes: entry.transferSize || entry.encodedBodySize || 0})
    )`);
    for (const suffix of ["index.js", "index.wasm", "index.pck"]) {
      if (!resources.some((entry) => entry.name.includes(suffix))) {
        throw new Error(`${name} did not load ${suffix}`);
      }
    }
    const finalScreenshot = await capture(
      cdp,
      reportPath.replace(/\.json$/i, `_${name.toLowerCase()}_final.png`)
    );
    return {
      browser: name,
      status: "pass",
      elapsed_ms: Date.now() - started,
      checkpoints,
      console_errors: [],
      network_failures: [],
      js_heap_mb: jsHeapMb,
      runtime_resources: resources.filter((entry) => /index\.(js|wasm|pck)/.test(entry.name)),
      console_messages: consoleMessages(cdp).slice(-120),
      final_screenshot: finalScreenshot,
      final_telemetry: finalState || await telemetry(cdp),
      route_limitations: [
        "Castle Vargan Approach has no direct Greyfen return gate; QA returns Record Hall to Courtyard to Approach.",
        "Deep Woods returns through Wychwood because its authored back gate targets Wychwood.",
      ],
    };
  } catch (error) {
    if (cdp) {
      failureScreenshot = await capture(
        cdp,
        reportPath.replace(/\.json$/i, `_${name.toLowerCase()}_failure.png`)
      ).catch(() => "");
    }
    return {
      browser: name,
      status: "fail",
      failure: error.message,
      elapsed_ms: Date.now() - started,
      checkpoints,
      console_errors: cdp ? consoleErrors(cdp) : [],
      console_messages: cdp ? consoleMessages(cdp).slice(-120) : [],
      failure_screenshot: failureScreenshot,
      last_telemetry: cdp ? await telemetry(cdp).catch(() => null) : null,
    };
  } finally {
    if (cdp) cdp.close();
    spawnSync("taskkill.exe", ["/PID", String(browser.pid), "/T", "/F"], {
      encoding: "utf8",
      windowsHide: true,
    });
    await Promise.race([
      new Promise((done) => browser.once("exit", done)),
      sleep(1500),
    ]);
    try {
      rmSync(profile, { recursive: true, force: true, maxRetries: 4, retryDelay: 250 });
    } catch {
      // A late browser crash-handler lock must not mask the QA result.
    }
  }
}

const report = {
  schema_version: 1,
  ticket: fullCampaign ? "WEB-002" : "QA-002",
  status: "pass",
  export_dir: exportDir,
  browsers: [],
};
try {
  for (const [name, executable] of browsers) {
    const result = await testBrowser(name, executable);
    report.browsers.push(result);
    if (result.status !== "pass") throw new Error(`${name}: ${result.failure}`);
    console.log(`${fullCampaign ? "WEB-002" : "QA-002"} ${name}: PASS - ${result.checkpoints.length} route checkpoints in ${result.elapsed_ms} ms`);
  }
} catch (error) {
  report.status = "fail";
  report.failure = error.message;
  console.error(`${fullCampaign ? "WEB-002" : "QA-002"} BROWSER: FAIL - ${error.message}`);
} finally {
  server.close();
  mkdirSync(resolve(reportPath, ".."), { recursive: true });
  writeFileSync(reportPath, JSON.stringify(report, null, 2) + "\n");
}
process.exit(report.status === "pass" ? 0 : 1);
