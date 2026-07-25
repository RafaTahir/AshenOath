import { createServer } from "node:http";
import { createReadStream, existsSync, mkdirSync, rmSync, writeFileSync } from "node:fs";
import { extname, join, normalize, resolve } from "node:path";
import { spawn, spawnSync } from "node:child_process";
import { tmpdir } from "node:os";

const args = Object.fromEntries(process.argv.slice(2).map((value, index, all) =>
  value.startsWith("--") ? [value.slice(2), all[index + 1]?.startsWith("--") ? true : all[index + 1]] : []
).filter(([key]) => key));
const exportDir = resolve(args.export || "../AshenOath_Web");
const reportPath = resolve(args.report || ".release-gate/web_001_browser_report.json");
const timeoutMs = Number(args.timeout || 90000);
const maxMemoryMb = Number(args["max-memory-mb"] || 450);
const requestedBrowser = String(args.browser || "").toLowerCase();
const mobileMode = Boolean(args.mobile);
const viewportWidth = mobileMode ? 960 : 1280;
const viewportHeight = mobileMode ? 540 : 720;
const browsers = [
  ["Chrome", "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe"],
  ["Edge", "C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe"],
].filter(([name, executable]) =>
  existsSync(executable) && (!requestedBrowser || name.toLowerCase() === requestedBrowser)
);

if (!existsSync(join(exportDir, "index.html"))) {
  throw new Error(`WEB BROWSER: export missing at ${exportDir}`);
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
  response.writeHead(200, {
    "Content-Type": mime[extname(path)] || "application/octet-stream",
    "Cache-Control": "no-cache, must-revalidate",
  });
  createReadStream(path).pipe(response);
});
await new Promise((resolveListen) => server.listen(0, "127.0.0.1", resolveListen));
const port = server.address().port;

const sleep = (ms) => new Promise((resolveSleep) => setTimeout(resolveSleep, ms));
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
  send(method, params = {}) {
    const id = this.nextId++;
    return new Promise((resolveSend, reject) => {
      this.pending.set(id, { resolve: resolveSend, reject });
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

async function testBrowser(name, executable) {
  const debugPort = await availablePort();
  const profile = join(tmpdir(), `ashen-oath-web001-${mobileMode ? "mobile-" : ""}${name.toLowerCase()}-${Date.now()}`);
  const url = `http://127.0.0.1:${port}/index.html?v=${mobileMode ? "mobile001" : "web001"}-${name.toLowerCase()}${mobileMode ? "&touch=1" : ""}`;
  const browser = spawn(executable, [
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
    "--enable-unsafe-swiftshader",
    "--ignore-gpu-blocklist",
    "--autoplay-policy=no-user-gesture-required",
    "about:blank",
  ], { stdio: "ignore" });
  const started = Date.now();
  let cdp;
  try {
    const page = await waitFor(async () => {
      const response = await fetch(`http://127.0.0.1:${debugPort}/json/list`);
      const targets = await response.json();
      return targets.find((target) => target.type === "page");
    }, `${name} DevTools`);
    cdp = new Cdp(page.webSocketDebuggerUrl);
    await cdp.open();
    await Promise.all([
      cdp.send("Runtime.enable"),
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
    const navigationStarted = Date.now();
    await cdp.send("Page.navigate", { url });
    await waitFor(async () => cdp.evaluate(
      `location.href.startsWith(${JSON.stringify(url.split("?")[0])}) && document.readyState === "complete"`
    ), `${name} page navigation`);
    let canvasDiagnostic = null;
    const canvas = await waitFor(async () => {
      canvasDiagnostic = await cdp.evaluate(`(() => {
      const canvas = document.querySelector("canvas");
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
    await cdp.send("Emulation.setFocusEmulationEnabled", { enabled: true });
    await cdp.evaluate(`(() => {
      window.focus();
      const canvas = document.querySelector("canvas");
      if (canvas) {
        canvas.tabIndex = 0;
        canvas.focus();
      }
      return document.hasFocus();
    })()`);
    await cdp.send("Input.dispatchMouseEvent", { type: "mousePressed", x: viewportWidth / 2, y: viewportHeight / 2, button: "left", clickCount: 1 });
    await cdp.send("Input.dispatchMouseEvent", { type: "mouseReleased", x: viewportWidth / 2, y: viewportHeight / 2, button: "left", clickCount: 1 });
    let newGameStarted = 0;
    for (let index = 0; index < 2; index++) {
      if (index === 1) newGameStarted = Date.now();
      await cdp.send("Input.dispatchKeyEvent", { type: "keyDown", key: "Enter", code: "Enter", windowsVirtualKeyCode: 13 });
      await cdp.send("Input.dispatchKeyEvent", { type: "keyUp", key: "Enter", code: "Enter", windowsVirtualKeyCode: 13 });
      await sleep(index === 0 ? 1200 : 300);
    }
    await waitFor(async () => {
      const logs = cdp.events.filter((event) => event.method === "Runtime.consoleAPICalled")
        .flatMap((event) => event.params.args.map((arg) => String(arg.value ?? arg.description ?? "")));
      return logs.some((line) => line.includes("LOADING: zone=greyfen playable_ms="));
    }, `${name} New Game startup`);
    const newGameReadyMs = Date.now() - newGameStarted;
    if (mobileMode) {
      await waitFor(async () => {
        const logs = cdp.events.filter((event) => event.method === "Runtime.consoleAPICalled")
          .flatMap((event) => event.params.args.map((arg) => String(arg.value ?? arg.description ?? "")));
        return logs.some((line) => line.includes("MOBILE_TOUCH: ready landscape=true"));
      }, `${name} mobile touch overlay`);
    }
    await sleep(1500);
    const errors = cdp.events.filter((event) =>
      event.method === "Runtime.exceptionThrown"
      || (event.method === "Log.entryAdded" && event.params.entry.level === "error")
      || (event.method === "Runtime.consoleAPICalled" && event.params.type === "error")
    ).map((event) => JSON.stringify(event.params).slice(0, 600));
    if (errors.length) throw new Error(`${name} console error: ${errors[0]}`);
    const metrics = await cdp.send("Performance.getMetrics");
    const metric = Object.fromEntries(metrics.metrics.map((entry) => [entry.name, entry.value]));
    const jsHeapMb = (metric.JSHeapUsedSize || 0) / 1048576;
    const workingSetMb = processTreeMemoryMb(browser.pid);
    if (jsHeapMb > maxMemoryMb) {
      throw new Error(`${name} runtime heap uses ${jsHeapMb.toFixed(1)} MB (limit ${maxMemoryMb} MB)`);
    }
    const screenshot = await cdp.send("Page.captureScreenshot", { format: "png", fromSurface: true });
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
      canvas,
      js_heap_mb: Number(jsHeapMb.toFixed(1)),
      process_tree_mb: workingSetMb,
      resources: resources.filter((entry) => /index\.(js|wasm|pck)/.test(entry.name)),
      console_errors: [],
      screenshot: screenshotPath,
    };
  } finally {
    if (cdp) cdp.close();
    spawnSync("taskkill.exe", ["/PID", String(browser.pid), "/T", "/F"], {
      encoding: "utf8",
      windowsHide: true,
    });
    await Promise.race([
      new Promise((resolveExit) => browser.once("exit", resolveExit)),
      sleep(1500),
    ]);
    try {
      rmSync(profile, { recursive: true, force: true, maxRetries: 4, retryDelay: 250 });
    } catch {
      // A late Crashpad handle must not mask the browser/game acceptance result.
    }
  }
}

const report = { schema_version: 1, status: "pass", mode: mobileMode ? "mobile-landscape-emulation" : "desktop", export_dir: exportDir, browsers: [] };
try {
  for (const [name, executable] of browsers) {
    const result = await testBrowser(name, executable);
    report.browsers.push(result);
    console.log(
      `WEB BROWSER ${name}: PASS - ${result.canvas.width}x${result.canvas.height} WebGL${result.canvas.webgl}, `
      + `engine ${result.engine_ready_ms} ms, New Game ${result.new_game_ready_ms} ms, `
      + `heap ${result.js_heap_mb} MB`
    );
  }
} catch (error) {
  report.status = "fail";
  report.failure = error.message;
  console.error(`WEB BROWSER: FAIL - ${error.message}`);
} finally {
  server.close();
  mkdirSync(resolve(reportPath, ".."), { recursive: true });
  writeFileSync(reportPath, JSON.stringify(report, null, 2) + "\n");
}
process.exit(report.status === "pass" ? 0 : 1);
