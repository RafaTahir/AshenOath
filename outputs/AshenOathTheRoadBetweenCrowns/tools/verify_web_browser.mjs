import { createServer } from "node:http";
import { createReadStream, existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { extname, join, normalize, resolve } from "node:path";
import { spawn, spawnSync } from "node:child_process";
import { gzipSync, gunzipSync } from "node:zlib";

const args = Object.fromEntries(process.argv.slice(2).map((value, index, all) =>
  value.startsWith("--") ? [value.slice(2), !all[index + 1] || all[index + 1].startsWith("--") ? true : all[index + 1]] : []
).filter(([key]) => key));
const exportDir = resolve(args.export || "../AshenOath_Web");
const targetUrl = args.url ? String(args.url) : "";
const reportPath = resolve(args.report || ".release-gate/web_001_browser_report.json");
const timeoutMs = Number(args.timeout || 90000);
const maxMemoryMb = Number(args["max-memory-mb"] || 450);
const requestedBrowser = String(args.browser || "").toLowerCase();
const mobileMode = Boolean(args.mobile);
const bridgeCrossing = Boolean(args["bridge-crossing"]);
const interactionSmoke = Boolean(args["interaction-smoke"]);
const persistenceSmoke = Boolean(args["persistence-smoke"]);
const manualSave = Boolean(args["manual-save"]);
const checkpointWaitMs = Number(args["checkpoint-wait-ms"] || 45000);
const uiAcceptance = Boolean(args["ui-acceptance"]);
const openingPresence = Boolean(args["opening-presence"]);
const QA_TEMP_ROOT = "D:\\Temp\\AshenOath";
mkdirSync(QA_TEMP_ROOT, { recursive: true });
// Hardware WebGL is the release acceptance path. Software remains available
// only when explicitly requested for diagnostics on machines without a usable
// accelerated browser profile.
const rendererMode = String(args.renderer || process.env.ASHEN_OATH_BROWSER_RENDERER || "hardware").toLowerCase();
const useSoftwareRenderer = rendererMode !== "hardware";
const viewportWidth = mobileMode ? 960 : 1280;
const viewportHeight = mobileMode ? 540 : 720;
// The Godot menu is rendered inside the canvas, so its action point must scale
// with the emulated viewport. The old desktop pixel coordinate landed outside
// the mobile canvas and made a clean runtime look like a readiness timeout.
const menuInputPoint = {
  x: viewportWidth * (1015 / 1280),
  // The compact native-720p menu places New Game near the top of the
  // right-hand panel. The previous point landed below that button.
  y: viewportHeight * (128 / 720),
};
const browsers = [
  ["Chrome", "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe"],
  ["Edge", "C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe"],
].filter(([name, executable]) =>
  existsSync(executable) && (!requestedBrowser || name.toLowerCase() === requestedBrowser)
);

async function dispatchPrimaryActivation(cdp, point) {
  if (!mobileMode) {
    await cdp.send("Input.dispatchMouseEvent", {
      type: "mousePressed", x: point.x, y: point.y, button: "left", clickCount: 1,
    }, 60000);
    await sleep(70);
    await cdp.send("Input.dispatchMouseEvent", {
      type: "mouseReleased", x: point.x, y: point.y, button: "left", clickCount: 1,
    }, 60000);
    return;
  }
  // Mobile emulation has touch enabled. Drive the same pointer path as a
  // phone/tablet instead of sending a desktop mouse command through Chrome's
  // touch compositor, which can leave Input.dispatchMouseEvent pending while
  // the WebGL canvas is starting on Intel/ANGLE.
  const touchPoint = { id: 1, x: point.x, y: point.y, radiusX: 1, radiusY: 1, force: 1 };
  await cdp.send("Input.dispatchTouchEvent", {
    type: "touchStart", touchPoints: [touchPoint], modifiers: 0,
  }, 60000);
  await sleep(70);
  await cdp.send("Input.dispatchTouchEvent", {
    type: "touchEnd", touchPoints: [], modifiers: 0,
  }, 60000);
}

if (!targetUrl && !existsSync(join(exportDir, "index.html"))) {
  throw new Error(`WEB BROWSER: export missing at ${exportDir}`);
}

async function dispatchFocusedMenuActivation(cdp) {
  // Godot's menu is rendered inside the canvas. Keyboard activation follows
  // the real focus path and remains stable when the Web canvas switches from
  // the authored 1080p menu layout to the native 720p gameplay viewport.
  await cdp.send("Input.dispatchKeyEvent", {
    type: "keyDown", key: "Enter", code: "Enter", text: "\r", unmodifiedText: "\r", windowsVirtualKeyCode: 13,
  }, 60000);
  await cdp.send("Input.dispatchKeyEvent", {
    type: "keyUp", key: "Enter", code: "Enter", windowsVirtualKeyCode: 13,
  }, 60000);
}
if ((!requestedBrowser && browsers.length !== 2) || (requestedBrowser && browsers.length !== 1)) {
  throw new Error("WEB BROWSER: Chrome and Edge are both required for WEB-001");
}

const mime = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".wasm": "application/wasm",
  ".pck": "application/octet-stream",
  ".png": "image/png",
};
// Prime the exact candidate bytes before timing navigation. Reading large PCK
// files from the D: workspace while the browser is waiting measures antivirus
// and disk latency rather than Web startup. Production serves these responses
// compressed, so mirror that behavior without changing the artifact itself.
const serverFileCache = new Map();
const serverGzipCache = new Map();
for (const relative of [
  "index.html",
  "index.js",
  "index.wasm",
  "index.pck",
  "index.png",
  "index.audio.worklet.js",
  "index.audio.position.worklet.js",
  "runtime_pack_manifest.json",
  "release_manifest.json",
  "packs/opening.pck",
  "packs/campaign.pck",
  "packs/characters.pck",
  "packs/monsters.pck",
  "packs/audio.pck",
  "packs/quality_materials.pck",
]) {
  const path = resolve(exportDir, relative);
  if (!existsSync(path)) continue;
  const payload = readFileSync(path);
  const encodedWasm = relative === "index.wasm" && payload[0] === 0x1f && payload[1] === 0x8b;
  serverFileCache.set(relative, encodedWasm ? gunzipSync(payload) : payload);
  // Godot PCKs are already packed binary containers. Serving them through an
  // additional HTTP gzip stream makes an interrupted navigation surface a
  // StreamPeerGZIP decode error, unlike production's octet-stream delivery.
  if (relative !== "index.png" && extname(relative) !== ".pck") {
    serverGzipCache.set(relative, encodedWasm ? payload : gzipSync(payload, { level: 6 }));
  }
}
const server = createServer((request, response) => {
  const relative = decodeURIComponent((request.url || "/").split("?")[0]) === "/"
    ? "index.html"
    : decodeURIComponent((request.url || "/").split("?")[0]).replace(/^\/+/, "");
  const path = resolve(exportDir, normalize(relative));
  if (!path.startsWith(exportDir) || !existsSync(path)) {
    response.writeHead(relative === "favicon.ico" ? 204 : 404);
    response.end();
    return;
  }
  const acceptsGzip = /\bgzip\b/i.test(String(request.headers["accept-encoding"] || ""));
  const cached = serverFileCache.get(relative);
  const compressed = acceptsGzip ? serverGzipCache.get(relative) : null;
  const headers = {
    "Content-Type": mime[extname(path)] || "application/octet-stream",
    "Cache-Control": relative === "index.html" || relative.endsWith("manifest.json")
      ? "no-cache, must-revalidate"
      : "public, max-age=31536000, immutable",
  };
  if (compressed) headers["Content-Encoding"] = "gzip";
  response.writeHead(200, headers);
  if (compressed) {
    response.end(compressed);
  } else if (cached) {
    response.end(cached);
  } else {
    createReadStream(path).pipe(response);
  }
});
if (!targetUrl) await new Promise((resolveListen) => server.listen(0, "127.0.0.1", resolveListen));
const port = targetUrl ? 0 : server.address().port;

const sleep = (ms) => new Promise((resolveSleep) => setTimeout(resolveSleep, ms));
async function removeTemporaryProfile(profile) {
  // Chromium may keep a Crashpad handle briefly after the browser process has
  // exited. Retry the isolated profile cleanup so successful QA runs do not
  // accumulate browser state in the dedicated temp root.
  const deadline = Date.now() + 8000;
  while (existsSync(profile) && Date.now() < deadline) {
    try {
      rmSync(profile, { recursive: true, force: true, maxRetries: 2, retryDelay: 150 });
    } catch {
      // The next retry handles late browser-owned handles.
    }
    if (!existsSync(profile)) return true;
    await sleep(250);
  }
  return !existsSync(profile);
}
async function fetchJson(url) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 5000);
  try {
    const response = await fetch(url, { signal: controller.signal });
    return await response.json();
  } finally {
    clearTimeout(timeout);
  }
}
async function availablePort() {
  const probe = createServer();
  await new Promise((resolveListen, reject) => {
    probe.once("error", reject);
    probe.listen(0, "127.0.0.1", resolveListen);
  });
  const selected = probe.address().port;
  await new Promise((resolveClose) => probe.close(resolveClose));
  return selected;
}

async function waitFor(predicate, label, timeout = timeoutMs) {
  const started = Date.now();
  let lastError;
  while (Date.now() - started < timeout) {
    try {
      const value = await predicate();
      if (value) return value;
    } catch (error) {
      lastError = error;
    }
    await sleep(250);
  }
  throw new Error(`${label} timed out${lastError ? `: ${lastError.message}` : ""}`);
}

function processTreeMemoryMb(rootPid) {
  const script = [
    `$rootPid=${rootPid}`,
    "$all=@(Get-CimInstance Win32_Process)",
    "$ids=New-Object System.Collections.Generic.List[int]",
    "$ids.Add($rootPid)",
    "for($i=0;$i -lt 8;$i++){",
    "  $added=$false",
    "  foreach($p in $all){if($ids.Contains([int]$p.ParentProcessId) -and -not $ids.Contains([int]$p.ProcessId)){$ids.Add([int]$p.ProcessId);$added=$true}}",
    "  if(-not $added){break}",
    "}",
    "$sum=0",
    "foreach($id in $ids){$p=Get-Process -Id $id -ErrorAction SilentlyContinue;if($p){$sum+=$p.WorkingSet64}}",
    "[math]::Round($sum/1MB,1)",
  ].join(";");
  const result = spawnSync("powershell.exe", ["-NoProfile", "-Command", script], { encoding: "utf8" });
  return Number((result.stdout || "").trim()) || 0;
}

class Cdp {
  constructor(url) {
    this.nextId = 1;
    this.pending = new Map();
    this.events = [];
    this.socket = new WebSocket(url);
  }
  async open() {
    await new Promise((resolveOpen, reject) => {
      this.socket.addEventListener("open", resolveOpen, { once: true });
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
  send(method, params = {}, timeoutMs = 15000) {
    const id = this.nextId++;
    return new Promise((resolveSend, reject) => {
      const timer = setTimeout(() => {
        this.pending.delete(id);
        reject(new Error(`CDP ${method} timed out`));
      }, timeoutMs);
      this.pending.set(id, {
        resolve: (value) => { clearTimeout(timer); resolveSend(value); },
        reject: (error) => { clearTimeout(timer); reject(error); },
      });
      this.socket.send(JSON.stringify({ id, method, params }));
    });
  }
  async evaluate(expression, timeoutMs = 60000) {
    const response = await this.send("Runtime.evaluate", {
      expression,
      returnByValue: true,
      awaitPromise: true,
    }, timeoutMs);
    if (response.exceptionDetails) throw new Error(response.exceptionDetails.text);
    return response.result.value;
  }
  close() {
    this.socket.close();
  }
}

async function captureViewportScreenshot(cdp, name) {
  let surfaceError = null;
  try {
    return {
      ...(await cdp.send("Page.captureScreenshot", {
        format: "png",
        fromSurface: true,
        captureBeyondViewport: false,
      })),
      capture_mode: "surface",
    };
  } catch (error) {
    surfaceError = error;
  }
  // Some managed ANGLE configurations can render the WebGL surface but hang
  // when the compositor is asked to capture it. A viewport capture is still a
  // real rendered screenshot; retain the first failure in the final error if
  // this second bounded attempt also fails.
  try {
    return {
      ...(await cdp.send("Page.captureScreenshot", {
        format: "png",
        fromSurface: false,
        captureBeyondViewport: false,
      })),
      capture_mode: "viewport",
    };
  } catch (viewportError) {
    throw new Error(
      `${name} screenshot capture failed: surface=${surfaceError?.message || "unknown"}; `
      + `viewport=${viewportError.message}`
    );
  }
}

async function testBrowser(name, executable) {
  const debugPort = await availablePort();
  const profile = join(QA_TEMP_ROOT, `ashen-oath-web001-${mobileMode ? "mobile-" : ""}${name.toLowerCase()}-${Date.now()}`);
  mkdirSync(profile, { recursive: true });
  const baseUrl = targetUrl || `http://127.0.0.1:${port}/index.html?v=${mobileMode ? "mobile001" : "web001"}-${name.toLowerCase()}${mobileMode ? "&touch=1" : ""}`;
  const url = bridgeCrossing || interactionSmoke || persistenceSmoke
    ? `${baseUrl}${baseUrl.includes("?") ? "&" : "?"}observe=1`
    : baseUrl;
  const browserArgs = [
    "--headless=new",
    `--remote-debugging-port=${debugPort}`,
    "--remote-allow-origins=*",
    `--user-data-dir=${profile}`,
    `--window-size=${viewportWidth},${viewportHeight}`,
    "--force-device-scale-factor=1",
    "--no-first-run",
    "--no-default-browser-check",
    "--disable-background-networking",
    "--disable-component-update",
    // The managed runner crashes Chrome's renderer sandbox before WebGL can
    // initialize. This is an isolated local acceptance browser, not a
    // production runtime, so use the stable renderer path for the test.
    "--no-sandbox",
    "about:blank",
  ];
  if (useSoftwareRenderer) {
    // The managed Windows runner cannot start Chrome's sandboxed GPU
    // subprocess reliably. Keep WebGL available in-process for diagnostics.
    // Hardware acceptance explicitly omits these flags.
    browserArgs.splice(browserArgs.length - 1, 0,
      "--in-process-gpu",
      "--disable-gpu-sandbox",
      "--use-angle=swiftshader",
      "--enable-unsafe-swiftshader",
      "--ignore-gpu-blocklist",
    );
  }
  const browser = spawn(executable, browserArgs, { stdio: "ignore", windowsHide: true });
  const started = Date.now();
  let cdp;
  try {
    const page = await waitFor(async () => {
      const targets = await fetchJson(`http://127.0.0.1:${debugPort}/json/list`);
      return targets.find((target) => target.type === "page" && target.url === "about:blank");
    }, `${name} DevTools`);
    cdp = new Cdp(page.webSocketDebuggerUrl);
    await cdp.open();
    await Promise.all([
      cdp.send("Page.enable"),
      cdp.send("Log.enable"),
      cdp.send("Performance.enable"),
      cdp.send("Network.enable"),
    ]);
    await cdp.send("Emulation.setDeviceMetricsOverride", {
      width: viewportWidth,
      height: viewportHeight,
      deviceScaleFactor: 1,
      mobile: mobileMode,
      screenWidth: viewportWidth,
      screenHeight: viewportHeight,
    });
    if (mobileMode) {
      await cdp.send("Emulation.setTouchEmulationEnabled", {
        enabled: true,
        maxTouchPoints: 5,
      });
      await cdp.send("Emulation.setUserAgentOverride", {
        userAgent: "Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 Chrome/125.0 Mobile Safari/537.36",
        platform: "Android",
      });
    }
    // Chrome's initial about:blank target has no live renderer, so Runtime
    // domain enablement cannot complete until it has navigated once. Use a
    // tiny data document to establish the renderer while all instrumentation
    // remains attached before the game URL is loaded.
    await cdp.send("Page.navigate", { url: "data:text/html,<body></body>" });
    await cdp.send("Runtime.enable");
    const navigationStarted = Date.now();
    await cdp.send("Page.navigate", { url });
    // The authored shell starts the engine while the document is still
    // loading its large Web runtime and external packs. Waiting for the
    // browser's final readyState can therefore turn a healthy page into a
    // false navigation timeout. The boot root and start control are the
    // meaningful navigation boundary; later waits verify engine readiness.
    const expectedOrigin = new URL(url).origin;
    await waitFor(async () => cdp.evaluate(
      `location.origin === ${JSON.stringify(expectedOrigin)} && Boolean(document.querySelector("#boot"))`
    ), `${name} page navigation`).catch(async (error) => {
      let diagnostic = null;
      try {
        diagnostic = await cdp.evaluate(`(() => ({
          href: location.href,
          ready_state: document.readyState,
          title: document.title,
          body: document.body?.innerText?.slice(0, 300) || "",
          boot: Boolean(document.querySelector("#boot")),
          canvas: Boolean(document.querySelector("#canvas")),
        }))()`);
      } catch {}
      const eventTail = cdp.events.filter((event) =>
        event.method === "Runtime.exceptionThrown"
        || event.method === "Log.entryAdded"
        || event.method === "Network.loadingFailed"
      ).slice(-8).map((event) => JSON.stringify(event.params).slice(0, 500));
      throw new Error(`${error.message}; navigation=${JSON.stringify(diagnostic)}; events=${eventTail.join(" | ")}`);
    });
    // The production Web preset uses the authored HTML boot shell. Its main
    // Godot canvas intentionally remains 300x150 until the player activates
    // the visible "Enter the Road" control. Activate that control through
    // browser input before asserting engine-canvas dimensions.
    const bootButton = await waitFor(async () => cdp.evaluate(`(() => {
      const button = document.querySelector("#start");
      if (!button || button.disabled) return null;
      const rect = button.getBoundingClientRect();
      return {x: rect.left + rect.width / 2, y: rect.top + rect.height / 2};
    })()`), `${name} boot-shell start control`);
    if (bootButton) {
      await dispatchPrimaryActivation(cdp, bootButton);
    }
    let canvasDiagnostic = null;
    const canvas = await waitFor(async () => {
      canvasDiagnostic = await cdp.evaluate(`(() => {
      const canvas = document.querySelector("#canvas");
      if (!canvas) return {ready: false, reason: "missing", body: document.body.innerText.slice(0, 200)};
      const gl = canvas.getContext("webgl2") || canvas.getContext("webgl");
      return {
        ready: Boolean(gl) && canvas.width >= ${viewportWidth} && canvas.height >= ${viewportHeight},
        reason: gl ? "dimensions" : "webgl",
        width: canvas.width,
        height: canvas.height,
        clientWidth: canvas.clientWidth,
        clientHeight: canvas.clientHeight,
        webgl: gl ? (gl instanceof WebGL2RenderingContext ? 2 : 1) : 0,
        body: document.body.innerText.slice(0, 300),
      };
    })()`);
      return canvasDiagnostic?.ready ? canvasDiagnostic : null;
    }, `${name} ${viewportWidth}x${viewportHeight} WebGL canvas`).catch((error) => {
      const eventTail = cdp.events.filter((event) =>
        event.method === "Runtime.exceptionThrown"
        || event.method === "Log.entryAdded"
        || event.method === "Runtime.consoleAPICalled"
      ).slice(-8).map((event) => JSON.stringify(event.params).slice(0, 350));
      throw new Error(
        `${error.message}; last state ${JSON.stringify(canvasDiagnostic)}; events ${eventTail.join(" | ")}`
      );
    });
    const engineReadyMs = Date.now() - navigationStarted;
    const resources = await cdp.evaluate(`performance.getEntriesByType("resource").map(
      entry => ({name: entry.name, bytes: entry.transferSize || entry.encodedBodySize || 0})
    )`);
    for (const suffix of ["index.js", "index.wasm", "index.pck"]) {
      if (!resources.some((entry) => entry.name.includes(suffix))) {
        throw new Error(`${name} did not load ${suffix}`);
      }
    }
    await cdp.send("Page.bringToFront");
    // Focus emulation is optional in headless Chromium. Some managed builds
    // accept the command but never acknowledge it; real pointer/keyboard
    // dispatch below remains the authoritative input check.
    await cdp.send("Emulation.setFocusEmulationEnabled", { enabled: true }).catch(() => {});
    await cdp.evaluate(`(() => {
      window.focus();
      const canvas = document.querySelector("#canvas");
      if (canvas) {
        canvas.tabIndex = 0;
        canvas.focus();
      }
      return document.hasFocus();
    })()`);
    const consoleLines = () => cdp.events.flatMap((event) => {
      if (event.method === "Runtime.consoleAPICalled") {
        return event.params.args.map((arg) => String(arg.value ?? arg.description ?? ""));
      }
      if (event.method === "Log.entryAdded") return [String(event.params.entry.text || "")];
      return [];
    });
    const networkLines = () => cdp.events.filter((event) =>
      event.method === "Network.requestWillBeSent"
      || event.method === "Network.responseReceived"
      || event.method === "Network.loadingFailed"
    ).filter((event) => {
      const urlValue = event.params.request?.url || event.params.response?.url || "";
      return /index\.(js|wasm|pck)|packs\//.test(urlValue);
    }).slice(-20).map((event) => {
      const params = event.params;
      const urlValue = params.request?.url || params.response?.url || "";
      return `${event.method.split(".").pop()} ${urlValue} ${params.errorText || params.response?.status || ""}`;
    });
    // Canvas dimensions arrive before the Godot scene has finished creating
    // its launch/main menu. Wait for the runtime-ready marker so the first
    // Enter key is delivered to an actual menu instead of disappearing during
    // engine startup.
    await waitFor(async () => {
      return consoleLines().some((line) => line.includes("LOADING: runtime ready total="));
    }, `${name} Godot runtime readiness`).catch((error) => {
      throw new Error(`${error.message}; console=${JSON.stringify(consoleLines().slice(-20))}; network=${JSON.stringify(networkLines())}`);
    });
    if (openingPresence) {
      await waitFor(async () => cdp.evaluate(`(() => {
        const opening = window.__ashenOathOpeningState;
        if (opening?.state === "failed") throw new Error(opening.message || "Greyfen preparation failed");
        return opening?.state === "ready" && document.querySelector("#boot")?.classList.contains("hidden");
      })()`), `${name} visible New Game menu`);
    }
    // Keep a diagnostic of the actual compact menu geometry. This is useful
    // when a browser delivers a healthy canvas but misses a player click;
    // it is written beside the report and never enters the game export.
    await sleep(250);
    const menuScreenshot = await captureViewportScreenshot(cdp, `${name} menu`);
    const menuScreenshotPath = reportPath.replace(/\.json$/i, `_menu_${name.toLowerCase()}.png`);
    mkdirSync(resolve(menuScreenshotPath, ".."), { recursive: true });
    writeFileSync(menuScreenshotPath, Buffer.from(menuScreenshot.data, "base64"));
    let settingsScreenshotPath = null;
    const settingsPageScreenshots = [];
    if (uiAcceptance) {
      if (mobileMode) throw new Error("UI acceptance requires the desktop viewport");
      await dispatchPrimaryActivation(cdp, { x: menuInputPoint.x, y: viewportHeight * (361 / 720) });
      await sleep(300);
      const settingsScreenshot = await captureViewportScreenshot(cdp, `${name} settings`);
      if (settingsScreenshot.data === menuScreenshot.data) throw new Error(`${name} Settings did not open by mouse`);
      settingsScreenshotPath = reportPath.replace(/\.json$/i, `_settings_${name.toLowerCase()}.png`);
      writeFileSync(settingsScreenshotPath, Buffer.from(settingsScreenshot.data, "base64"));
      settingsPageScreenshots.push(settingsScreenshotPath);
      let previousPageImage = settingsScreenshot.data;
      for (let page = 2; page <= 3; page += 1) {
        await dispatchPrimaryActivation(cdp, { x: menuInputPoint.x, y: viewportHeight * (496 / 720) });
        await sleep(200);
        const pageImage = await captureViewportScreenshot(cdp, `${name} settings page ${page}`);
        if (pageImage.data === previousPageImage) throw new Error(`${name} Settings page ${page} is unreachable`);
        const pagePath = reportPath.replace(/\.json$/i, `_settings_page${page}_${name.toLowerCase()}.png`);
        writeFileSync(pagePath, Buffer.from(pageImage.data, "base64"));
        settingsPageScreenshots.push(pagePath);
        previousPageImage = pageImage.data;
      }
      await cdp.send("Input.dispatchKeyEvent", { type: "keyDown", key: "Escape", code: "Escape", windowsVirtualKeyCode: 27 });
      await cdp.send("Input.dispatchKeyEvent", { type: "keyUp", key: "Escape", code: "Escape", windowsVirtualKeyCode: 27 });
      await sleep(250);
    }
    // The visible launch action either starts the desktop prewarm or, on Web,
    // confirms that New Game may use the bounded active build.
    if (!mobileMode) {
      await cdp.send("Input.dispatchMouseEvent", { type: "mouseMoved", x: menuInputPoint.x, y: menuInputPoint.y, button: "none" });
    }
    // Exercise the actual New Game control while the opening is preparing.
    // The click queues the request; the key event covers browsers that do not
    // deliver a canvas pointer event on the first compact-menu frame.
    const newGameRequestedAt = Date.now();
    await dispatchPrimaryActivation(cdp, menuInputPoint);
    if (!uiAcceptance && !openingPresence) await dispatchFocusedMenuActivation(cdp);
    await waitFor(async () => consoleLines().some((line) =>
      line.includes("LOADING: Greyfen prewarmed total=")
      || line.includes("LOADING: Greyfen prewarm deferred for Web")
    ), `${name} Greyfen readiness`).catch((error) => {
      throw new Error(`${error.message}; console=${JSON.stringify(consoleLines().slice(-30))}; network=${JSON.stringify(networkLines())}; canvas=${JSON.stringify(canvasDiagnostic)}`);
    });
    const queuedNewGame = consoleLines().some((line) => line.includes("LOADING: new_game_stage="));
    if (!queuedNewGame) {
      if (uiAcceptance || openingPresence) throw new Error(`${name} New Game mouse click did not queue the start`);
      if (!mobileMode) {
        await cdp.send("Input.dispatchMouseEvent", { type: "mouseMoved", x: menuInputPoint.x, y: menuInputPoint.y, button: "none" });
      }
      await dispatchPrimaryActivation(cdp, menuInputPoint);
      await dispatchFocusedMenuActivation(cdp);
    }
    await waitFor(async () => {
      return consoleLines().some((line) => line.includes("LOADING: new_game_stage=ready elapsed=")
        || line.includes("LOADING: zone=greyfen playable_ms="));
    }, `${name} New Game startup`).catch((error) => {
      throw new Error(`${error.message}; console=${JSON.stringify(consoleLines().slice(-30))}`);
    });
    const runtimeReadyLine = consoleLines().findLast((line) => line.includes("LOADING: new_game_stage=ready elapsed="));
    const runtimeReadyMatch = runtimeReadyLine?.match(/elapsed=([0-9.]+)/);
    const measuredRuntimeReadyMs = runtimeReadyMatch ? Number(runtimeReadyMatch[1]) : null;
    const newGameReadyMs = measuredRuntimeReadyMs ?? (Date.now() - newGameRequestedAt);
    // Capture the user-visible click-to-control boundary now. The previous
    // report calculated this value at function return, accidentally including
    // bridge traversal, screenshots, and diagnostics after gameplay started.
    const newGameAcceptedAt = Date.now();
    const newGameWallClockMs = newGameAcceptedAt - newGameRequestedAt;
    let openingScreenshotPath = null;
    if (openingPresence) {
      const firstView = await captureViewportScreenshot(cdp, `${name} Greyfen first control`);
      openingScreenshotPath = reportPath.replace(/\.json$/i, `_first_control_${name.toLowerCase()}.png`);
      writeFileSync(openingScreenshotPath, Buffer.from(firstView.data, "base64"));
    }
    if (mobileMode) {
      await waitFor(async () => {
        const logs = cdp.events.filter((event) => event.method === "Runtime.consoleAPICalled")
          .flatMap((event) => event.params.args.map((arg) => String(arg.value ?? arg.description ?? "")));
        return logs.some((line) => line.includes("MOBILE_TOUCH: ready landscape=true"));
      }, `${name} mobile touch overlay`);
    }
    await sleep(1500);
    let uiEvidence = null;
    if (uiAcceptance) {
      await waitFor(async () => consoleLines().some((line) => line.includes("LOADING: Greyfen deferred_detail complete")),
        `${name} complete Greyfen presentation`, 60000);
      await cdp.send("Emulation.setDeviceMetricsOverride", {
        width: 1920, height: 1080, deviceScaleFactor: 1, mobile: false,
        screenWidth: 1920, screenHeight: 1080,
      });
      await waitFor(async () => cdp.evaluate(`(() => {
        const canvas = document.querySelector("#canvas");
        return canvas && canvas.clientWidth === 1920 && canvas.clientHeight === 1080;
      })()`), `${name} 1080p resize`);
      const resized = await captureViewportScreenshot(cdp, `${name} 1080p gameplay`);
      const resizedPath = reportPath.replace(/\.json$/i, `_1080p_${name.toLowerCase()}.png`);
      writeFileSync(resizedPath, Buffer.from(resized.data, "base64"));
      await cdp.send("Emulation.setDeviceMetricsOverride", {
        width: 1280, height: 720, deviceScaleFactor: 1, mobile: false,
        screenWidth: 1280, screenHeight: 720,
      });
      await waitFor(async () => cdp.evaluate(`(() => {
        const canvas = document.querySelector("#canvas");
        return canvas && canvas.clientWidth === 1280 && canvas.clientHeight === 720;
      })()`), `${name} native 720p restore`);
      uiEvidence = { menu_screenshot: menuScreenshotPath, settings_screenshot: settingsScreenshotPath,
        settings_page_screenshots: settingsPageScreenshots, resized_screenshot: resizedPath,
        new_game_input: "mouse_only", opening_detail_complete: true };
    }
    let bridgeCrossingResult = null;
    if (bridgeCrossing) {
      const before = await waitFor(async () => cdp.evaluate(`(() => {
        const state = window.__ashenOathReadOnlyObservation;
        return state?.read_only && state?.zone === "greyfen" && state?.player?.can_control ? state : null;
      })()`), `${name} read-only production observation`);
      const startZ = Number(before.player.position.z);
      if (!Number.isFinite(startZ) || startZ < 7.0) {
        throw new Error(`${name} bridge proof started outside the Greyfen south approach: z=${startZ}`);
      }
      await cdp.send("Input.dispatchKeyEvent", {
        type: "keyDown", key: "w", code: "KeyW", windowsVirtualKeyCode: 87, nativeVirtualKeyCode: 87,
      }, 60000);
      let after;
      try {
        after = await waitFor(async () => cdp.evaluate(`(() => {
          const state = window.__ashenOathReadOnlyObservation;
          const z = Number(state?.player?.position?.z);
          return state?.read_only && state?.zone === "greyfen" && z < 1.95 ? state : null;
        })()`), `${name} physical Greyfen bridge crossing`, 15000);
      } finally {
        await cdp.send("Input.dispatchKeyEvent", {
          type: "keyUp", key: "w", code: "KeyW", windowsVirtualKeyCode: 87, nativeVirtualKeyCode: 87,
        }, 60000).catch(() => {});
      }
      bridgeCrossingResult = {
        input: "KeyW",
        start_position: before.player.position,
        end_position: after.player.position,
        zone: after.zone,
        on_floor: after.player.on_floor,
        read_only_observation: true,
      };
      if (!after.player.on_floor) throw new Error(`${name} bridge crossing ended off floor`);
    }
    let interactionResult = null;
    let checkpointPauseBudgetMs = 0;
    if (interactionSmoke) {
      const keyDown = async (key, code, virtualKeyCode) => cdp.send("Input.dispatchKeyEvent", {
        type: "keyDown", key, code, windowsVirtualKeyCode: virtualKeyCode, nativeVirtualKeyCode: virtualKeyCode,
      }, 60000);
      const keyUp = async (key, code, virtualKeyCode) => cdp.send("Input.dispatchKeyEvent", {
        type: "keyUp", key, code, windowsVirtualKeyCode: virtualKeyCode, nativeVirtualKeyCode: virtualKeyCode,
      }, 60000);
      const beforeInteraction = await cdp.evaluate(`window.__ashenOathReadOnlyObservation`);
      await keyDown("w", "KeyW", 87);
      let focused;
      try {
        focused = await waitFor(async () => cdp.evaluate(`(() => {
          const state = window.__ashenOathReadOnlyObservation;
          return state?.read_only && state?.zone === "greyfen"
            && state?.focus?.id === "sister_anwen" ? state : null;
        })()`), `${name} physical Sister Anwen focus`, 15000);
      } finally {
        await keyUp("w", "KeyW", 87).catch(() => {});
      }
      const dialoguePauseStartedAt = Date.now();
      await keyDown("e", "KeyE", 69);
      await sleep(90);
      await keyUp("e", "KeyE", 69);
      const dialogue = await waitFor(async () => cdp.evaluate(`(() => {
        const state = window.__ashenOathReadOnlyObservation;
        return state?.read_only && state?.paused ? state : null;
      })()`), `${name} Sister Anwen dialogue`, 10000);
      let dialoguePages = 0;
      for (; dialoguePages < 12; dialoguePages += 1) {
        const state = await cdp.evaluate(`window.__ashenOathReadOnlyObservation`);
        if (!state?.paused) break;
        await keyDown("Enter", "Enter", 13);
        await sleep(90);
        await keyUp("Enter", "Enter", 13);
        await sleep(350);
      }
      const afterDialogue = await waitFor(async () => cdp.evaluate(`(() => {
        const state = window.__ashenOathReadOnlyObservation;
        return state?.read_only && !state?.paused && state?.player?.can_control ? state : null;
      })()`), `${name} dialogue input release`, 10000);
      checkpointPauseBudgetMs += Date.now() - dialoguePauseStartedAt;
      interactionResult = {
        input: "KeyW + KeyE + Enter",
        start_position: beforeInteraction?.player?.position || null,
        focus_position: focused?.player?.position || null,
        focus_name: focused?.focus?.id || null,
        dialogue_paused: Boolean(dialogue?.paused),
        pages_advanced: dialoguePages,
        control_restored: Boolean(afterDialogue?.player?.can_control),
        read_only_observation: true,
      };
    }
    let persistenceResult = null;
    if (persistenceSmoke) {
      let pauseScreenshotPath = null;
      if (manualSave) {
        const pressKey = async (key, code, windowsVirtualKeyCode) => {
          await cdp.send("Input.dispatchKeyEvent", { type: "keyDown", key, code, windowsVirtualKeyCode });
          await cdp.send("Input.dispatchKeyEvent", { type: "keyUp", key, code, windowsVirtualKeyCode });
        };
        await pressKey("Escape", "Escape", 27);
        await waitFor(async () => cdp.evaluate(`window.__ashenOathReadOnlyObservation?.paused === true`),
          `${name} physical pause menu`);
        const pauseScreenshot = await captureViewportScreenshot(cdp, `${name} pause menu before save`);
        pauseScreenshotPath = reportPath.replace(/\.json$/i, `_pause_${name.toLowerCase()}.png`);
        writeFileSync(pauseScreenshotPath, Buffer.from(pauseScreenshot.data, "base64"));
        await dispatchPrimaryActivation(cdp, {
          x: viewportWidth * (1015 / 1280),
          y: viewportHeight * (149 / 720),
        });
        await sleep(2000);
      } else {
        // The automatic opening checkpoint uses in-game time, which may lag
        // wall time during Web pack hydration. This legacy timing is retained
        // for diagnosis; the manual path verifies an actual player Save action.
        const checkpointReadyAt = newGameAcceptedAt + checkpointWaitMs + checkpointPauseBudgetMs;
        if (Date.now() < checkpointReadyAt) await sleep(checkpointReadyAt - Date.now());
      }
      const repeatEventStart = cdp.events.length;
      const repeatNavigationStarted = Date.now();
      // Page.navigate can wait indefinitely for the live Godot document to
      // finish its unload path. Schedule the same-profile navigation inside
      // the page so CDP regains control before the old runtime tears down.
      await cdp.evaluate(`(() => {
        setTimeout(() => { location.href = ${JSON.stringify(url)}; }, 0);
        return true;
      })()`);
      await waitFor(async () => cdp.evaluate(
        `location.href.startsWith(${JSON.stringify(baseUrl)}) && Boolean(document.querySelector("#boot"))`
      ), `${name} warm page navigation`);
      const repeatBootButton = await waitFor(async () => cdp.evaluate(`(() => {
        const button = document.querySelector("#start");
        if (!button || button.disabled) return null;
        const rect = button.getBoundingClientRect();
        return {x: rect.left + rect.width / 2, y: rect.top + rect.height / 2};
      })()`), `${name} warm boot-shell start control`);
      await dispatchPrimaryActivation(cdp, repeatBootButton);
      const repeatConsoleLines = () => cdp.events.slice(repeatEventStart).flatMap((event) => {
        if (event.method === "Runtime.consoleAPICalled") {
          return event.params.args.map((arg) => String(arg.value ?? arg.description ?? ""));
        }
        if (event.method === "Log.entryAdded") return [String(event.params.entry.text || "")];
        return [];
      });
      await waitFor(async () => repeatConsoleLines().some((line) =>
        line.includes("LOADING: runtime ready total=")
      ), `${name} warm runtime readiness`);
      const repeatEngineReadyMs = Date.now() - repeatNavigationStarted;
      // Engine readiness is not menu readiness: the HTML shell stays over
      // Godot until opening prewarm publishes its ready state.
      await waitFor(async () => cdp.evaluate(`(() => {
        const boot = document.querySelector("#boot");
        return window.__ashenOathBoot?.state === "ready" && boot?.classList.contains("hidden");
      })()`), `${name} warm opening menu readiness`);
      await sleep(250);
      await cdp.send("Page.bringToFront");
      await cdp.evaluate(`(() => {
        window.focus();
        const canvas = document.querySelector("#canvas");
        if (canvas) { canvas.tabIndex = 0; canvas.focus(); }
      })()`);
      const continuePoint = {
        x: viewportWidth * (1015 / 1280),
        y: viewportHeight * (216 / 720),
      };
      const warmMenuScreenshot = await captureViewportScreenshot(cdp, `${name} warm menu`);
      const warmMenuScreenshotPath = reportPath.replace(/\.json$/i, `_warm_menu_${name.toLowerCase()}.png`);
      writeFileSync(warmMenuScreenshotPath, Buffer.from(warmMenuScreenshot.data, "base64"));
      const continueRequestedAt = Date.now();
      const readContinued = () => cdp.evaluate(`(() => {
        const state = window.__ashenOathReadOnlyObservation;
        return state?.read_only && state?.game_started && state?.zone === "greyfen"
          && state?.player?.can_control ? state : null;
      })()`);
      let continueActivation = "mouse";
      await dispatchPrimaryActivation(cdp, continuePoint);
      let continued;
      try {
        continued = await waitFor(readContinued, `${name} first Continue activation`, 2000).catch(() => null);
        if (!continued) {
          // Managed headless Chromium can lose the first canvas pointer-up
          // while ANGLE is settling. A second real click is the same bounded
          // recovery used by the visible New Game path.
          continueActivation = "mouse retry";
          await dispatchPrimaryActivation(cdp, continuePoint);
          continued = await waitFor(readContinued, `${name} retried Continue activation`, 3000).catch(() => null);
        }
        if (!continued) {
          // Keep a real-input fallback for browsers that render the canvas but
          // suppress pointer activation in headless mode. The bounded mouse
          // retry has already focused the visible Continue row, so keyboard
          // activation must not navigate away from it.
          continueActivation = "keyboard fallback";
          for (const event of [
            { type: "keyDown", key: "Enter", code: "Enter", text: "\r", unmodifiedText: "\r", windowsVirtualKeyCode: 13 },
            { type: "keyUp", key: "Enter", code: "Enter", windowsVirtualKeyCode: 13 },
          ]) await cdp.send("Input.dispatchKeyEvent", event, 60000);
          continued = await waitFor(readContinued, `${name} persisted Continue startup`, 25000);
        }
      } catch (error) {
        const failureScreenshot = await captureViewportScreenshot(cdp, `${name} Continue failure`).catch(() => null);
        const failureScreenshotPath = reportPath.replace(/\.json$/i, `_continue_failure_${name.toLowerCase()}.png`);
        if (failureScreenshot?.data) {
          writeFileSync(failureScreenshotPath, Buffer.from(failureScreenshot.data, "base64"));
        }
        const diagnostic = await cdp.evaluate(`(() => ({
          href: location.href,
          title: document.title,
          focused: document.hasFocus(),
          active_element: document.activeElement?.id || document.activeElement?.tagName || "",
          boot: window.__ashenOathBoot || null,
          observation: window.__ashenOathReadOnlyObservation || null,
        }))()`).catch(() => null);
        throw new Error(`${error.message}; warm_menu=${warmMenuScreenshotPath}; `
          + `failure_screen=${failureScreenshot?.data ? failureScreenshotPath : "unavailable"}; `
          + `diagnostic=${JSON.stringify(diagnostic)}; console=${JSON.stringify(repeatConsoleLines().slice(-40))}`);
      }
      persistenceResult = {
        input: continueActivation,
        save_mode: manualSave ? "pause_menu" : "opening_checkpoint",
        pause_screenshot: pauseScreenshotPath,
        checkpoint_wait_ms: manualSave ? null : checkpointWaitMs,
        repeat_engine_ready_ms: repeatEngineReadyMs,
        continue_ready_ms: Date.now() - continueRequestedAt,
        zone: continued.zone,
        player_position: continued.player.position,
        warm_menu_screenshot: warmMenuScreenshotPath,
        read_only_observation: true,
      };
    }
    const errorEvents = cdp.events.filter((event) =>
      event.method === "Runtime.exceptionThrown"
      || (event.method === "Log.entryAdded" && event.params.entry.level === "error")
      || (event.method === "Runtime.consoleAPICalled" && event.params.type === "error")
    );
    if (errorEvents.length) {
      const messages = errorEvents.map((event) => {
        const params = event.params || {};
        if (event.method === "Runtime.exceptionThrown") {
          return { method: event.method, message: params.exceptionDetails?.text || params.exceptionDetails?.exception?.description || "unknown exception" };
        }
        if (event.method === "Log.entryAdded") {
          return { method: event.method, message: params.entry?.text || "unknown log error" };
        }
        return { method: event.method, message: (params.args || []).map((arg) => arg.value ?? arg.description ?? "").join(" ") };
      });
      throw new Error(`${name} console error batch: ${JSON.stringify(messages).slice(0, 12000)}`);
    }
    const metrics = await cdp.send("Performance.getMetrics");
    const metric = Object.fromEntries(metrics.metrics.map((entry) => [entry.name, entry.value]));
    const jsHeapMb = (metric.JSHeapUsedSize || 0) / 1048576;
    const workingSetMb = processTreeMemoryMb(browser.pid);
    if (jsHeapMb > maxMemoryMb) {
      throw new Error(`${name} runtime heap uses ${jsHeapMb.toFixed(1)} MB (limit ${maxMemoryMb} MB)`);
    }
    let screenshot;
    try {
      screenshot = await captureViewportScreenshot(cdp, name);
    } catch (error) {
      const runtimeTail = consoleLines().filter((line) => /LOADING:|ZONE_COMPOSITION|ERROR|SCRIPT ERROR/.test(line)).slice(-40);
      throw new Error(`${error.message}; runtime=${JSON.stringify(runtimeTail)}; network=${JSON.stringify(networkLines())}`);
    }
    if (!screenshot.data || screenshot.data.length < 4096) throw new Error(`${name} screenshot is blank`);
    const screenshotPath = reportPath.replace(/\.json$/i, `_${name.toLowerCase()}.png`);
    mkdirSync(resolve(screenshotPath, ".."), { recursive: true });
    writeFileSync(screenshotPath, Buffer.from(screenshot.data, "base64"));
    return {
      browser: name,
      mode: mobileMode ? "mobile-landscape-emulation" : "desktop",
      status: "pass",
      total_startup_ms: Date.now() - started,
      engine_ready_ms: engineReadyMs,
      new_game_ready_ms: newGameReadyMs,
      new_game_wall_clock_ms: newGameWallClockMs,
      new_game_requested_ms: newGameRequestedAt - navigationStarted,
      canvas,
      js_heap_mb: Number(jsHeapMb.toFixed(1)),
      process_tree_mb: workingSetMb,
      runtime_logs: consoleLines().filter((line) => /LOADING: (new_game|zone_|Greyfen|startup_pack)|ZONE_COMPOSITION/.test(line)),
      resources: resources.filter((entry) => /index\.(js|wasm|pck)/.test(entry.name)),
      console_errors: [],
      bridge_crossing: bridgeCrossingResult,
      interaction_smoke: interactionResult,
      persistence_smoke: persistenceResult,
      ui_acceptance: uiEvidence,
      screenshot: screenshotPath,
      opening_first_control_screenshot: openingScreenshotPath,
      screenshot_capture_mode: screenshot.capture_mode,
      profile_dir: profile,
    };
  } finally {
    if (cdp) cdp.close();
    terminateIsolatedBrowser(browser, profile);
    await Promise.race([
      new Promise((resolveExit) => browser.once("exit", resolveExit)),
      sleep(1500),
    ]);
    if (!(await removeTemporaryProfile(profile))) {
      console.warn(`WEB BROWSER ${name}: temporary profile could not be removed: ${profile}`);
    }
  }
}

function terminateIsolatedBrowser(browser, profile) {
  // Chromium/Edge can relaunch the visible root and leave renderer/utility
  // children behind. Match only this test's unique temporary profile so the
  // cleanup cannot touch a user's normal browser session.
  spawnSync("taskkill.exe", ["/PID", String(browser.pid), "/T", "/F"], {
    encoding: "utf8",
    windowsHide: true,
  });
  if (process.platform !== "win32") return;
  const escapedProfile = profile.replace(/'/g, "''");
  const command = [
    `$profile = '${escapedProfile}'`,
    "$ids = @(Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -and $_.CommandLine.Contains($profile) } | Select-Object -ExpandProperty ProcessId)",
    "foreach ($id in $ids) { Stop-Process -Id $id -Force -ErrorAction SilentlyContinue }",
  ].join("; ");
  spawnSync("powershell.exe", ["-NoProfile", "-NonInteractive", "-Command", command], {
    encoding: "utf8",
    windowsHide: true,
  });
}

const report = { schema_version: 1, status: "pass", mode: mobileMode ? "mobile-landscape-emulation" : "desktop", target_url: targetUrl || null, export_dir: exportDir, qa_temp_root: QA_TEMP_ROOT, browsers: [] };
try {
  for (const [name, executable] of browsers) {
    const result = await testBrowser(name, executable);
    report.browsers.push(result);
    console.log(
      `WEB BROWSER ${name}: PASS - ${result.canvas.width}x${result.canvas.height} WebGL${result.canvas.webgl}, `
      + `engine ${result.engine_ready_ms} ms, New Game ${result.new_game_ready_ms} ms, `
      + `heap ${result.js_heap_mb} MB, profile ${result.profile_dir} (cleaned)`
    );
  }
} catch (error) {
  report.status = "fail";
  report.failure = error.message;
  console.error(`WEB BROWSER: FAIL - ${error.message}`);
} finally {
  if (!targetUrl) server.close();
  mkdirSync(resolve(reportPath, ".."), { recursive: true });
  writeFileSync(reportPath, JSON.stringify(report, null, 2) + "\n");
}
process.exit(report.status === "pass" ? 0 : 1);
