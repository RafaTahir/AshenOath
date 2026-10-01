import { createServer } from "node:http";
import { createReadStream, existsSync, mkdirSync, readFileSync, rmSync, statSync, writeFileSync } from "node:fs";
import { extname, join, normalize, resolve } from "node:path";
import { spawn, spawnSync } from "node:child_process";
import { gzipSync, gunzipSync } from "node:zlib";
import { artifactIdentity } from "./qa_002_artifact_identity.mjs";
import { measureFirefoxContentMemory } from "./firefox_content_memory.mjs";
import { measureChromiumRendererMemory } from "./chromium_renderer_memory.mjs";
import { ZonePerformanceEvidence, requireZonePerformance } from "./qa_002_zone_performance.mjs";

const args = {};
for (let index = 2; index < process.argv.length; index += 1) {
  const value = process.argv[index];
  if (!value.startsWith("--")) continue;
  const key = value.slice(2);
  const next = process.argv[index + 1];
  if (next && !next.startsWith("--")) {
    args[key] = next;
    index += 1;
  } else {
    args[key] = true;
  }
}
const exportDir = resolve(args.export || "../AshenOath_Web");
const reportPath = resolve(args.report || ".release-gate/qa_002/browser_report.json");
const timeoutMs = Number(args.timeout || 120000);
const requestedBrowser = String(args.browser || "chrome").toLowerCase();
const acceptanceProfile = String(args["acceptance-profile"] || "strict");
if (!["strict", "functional_candidate"].includes(acceptanceProfile)) throw new Error("Unknown acceptance profile");
const functionalCandidate = acceptanceProfile === "functional_candidate";
const rendererMode = String(args.renderer || "software").toLowerCase();
const presentationMode = args.headed ? "headed" : "headless";
if (!["hardware", "software"].includes(rendererMode)) throw new Error("--renderer must be hardware or software");
if (!["all", "chromium", "chrome", "edge", "firefox"].includes(requestedBrowser)) {
  throw new Error("--browser must be all, chromium, chrome, edge or firefox");
}
const fullCampaign = Boolean(args["full-campaign"]);
const diagnosticPreparation = Boolean(args["diagnostic-preparation"]);
const productionObserver = Boolean(args["production-observer"]);
const openingOnly = Boolean(args["opening-only"]);
const throughCemetery = Boolean(args["through-cemetery"]);
const throughBellEater = Boolean(args["through-bell-eater"]);
const throughTeeth = Boolean(args["through-teeth"]);
const throughRegister = Boolean(args["through-register"]);
const throughRootbound = Boolean(args["through-rootbound"]);
const throughNames = Boolean(args["through-names"]);
const throughAshPreparation = Boolean(args["through-ash-prep"]);
const throughAsh = Boolean(args["through-ash"]);
const throughSoldier = Boolean(args["through-soldier"]);
const throughCastle = Boolean(args["through-castle"]);
const throughRecordHall = Boolean(args["through-record-hall"]);
const throughLastWitness = Boolean(args["through-last-witness"]);
const throughAssembly = Boolean(args["through-assembly"]);
const throughFinale = Boolean(args["through-finale"]);
const endingMatrix = Boolean(args["ending-matrix"]);
const shrineMatrix = Boolean(args["shrine-matrix"]);
const ledgerMatrix = Boolean(args["ledger-matrix"]);
const edricMatrix = Boolean(args["edric-matrix"]);
const millMatrix = Boolean(args["mill-matrix"]);
const sennMatrix = Boolean(args["senn-matrix"]);
const reportMatrix = Boolean(args["report-matrix"]);
const widowMatrix = Boolean(args["widow-matrix"]);
const ironMatrix = Boolean(args["iron-matrix"]);
const returnedSoldierMatrix = Boolean(args["returned-soldier-matrix"]);
const bitterRootsMatrix = Boolean(args["bitter-roots-matrix"]);
const blackDogMatrix = Boolean(args["black-dog-matrix"]);
const namedDeadMatrix = Boolean(args["named-dead-matrix"]);
const rooksMapMatrix = Boolean(args["rooks-map-matrix"]);
const millersMeasureMatrix = Boolean(args["millers-measure-matrix"]);
const bannerlessMatrix = Boolean(args["bannerless-matrix"]);
const openingSaveContinue = Boolean(args["opening-save-continue"]);
const browserSmoke = Boolean(args["browser-smoke"]);
const partialCampaign = throughCemetery || throughBellEater || throughTeeth || throughRegister
  || throughRootbound || throughNames || throughAshPreparation || throughAsh
  || throughSoldier || throughCastle || throughRecordHall || throughLastWitness
  || throughAssembly || throughFinale || endingMatrix || shrineMatrix || ledgerMatrix || edricMatrix || millMatrix || sennMatrix || reportMatrix || widowMatrix || ironMatrix || returnedSoldierMatrix || bitterRootsMatrix || blackDogMatrix || namedDeadMatrix || rooksMapMatrix || millersMeasureMatrix || bannerlessMatrix || openingSaveContinue || browserSmoke;
const routeTimeoutMs = Number(args["route-timeout"] || (fullCampaign ? 45 * 60 * 1000
  : partialCampaign ? 20 * 60 * 1000 : timeoutMs));
if (!Number.isFinite(routeTimeoutMs) || routeTimeoutMs < 120000 || routeTimeoutMs > 90 * 60 * 1000) {
  throw new Error("Route deadline must be between 2 and 90 minutes");
}
if (Number(openingOnly) + Number(throughCemetery) + Number(throughBellEater) + Number(throughTeeth) + Number(throughRegister) + Number(throughRootbound) + Number(throughNames) + Number(throughAshPreparation) + Number(throughAsh) + Number(throughSoldier) + Number(throughCastle) + Number(throughRecordHall) + Number(throughLastWitness) + Number(throughAssembly) + Number(throughFinale) + Number(endingMatrix) + Number(shrineMatrix) + Number(ledgerMatrix) + Number(edricMatrix) + Number(millMatrix) + Number(sennMatrix) + Number(reportMatrix) + Number(widowMatrix) + Number(ironMatrix) + Number(returnedSoldierMatrix) + Number(bitterRootsMatrix) + Number(blackDogMatrix) + Number(namedDeadMatrix) + Number(rooksMapMatrix) + Number(millersMeasureMatrix) + Number(bannerlessMatrix) + Number(openingSaveContinue) + Number(browserSmoke) + Number(fullCampaign) > 1) {
  throw new Error("Opening, cemetery, Bell-Eater, Teeth, register, Rootbound, Names, Ash preparation, Ash, Soldier, Castle, Record Hall, Last Witness, Assembly, Finale, ending matrix, shrine matrix, ledger matrix, Edric matrix, mill matrix, Senn matrix, report matrix, Widow, Iron, Returned Soldier, Bitter Roots, Black Dog, Named Dead, Rook's map, Miller's measure, Bannerless, Save/Continue, and full campaign are separate route scopes");
}
if (productionObserver && diagnosticPreparation) throw new Error("Production observation cannot use diagnostic preparation");
if (partialCampaign && !productionObserver && !diagnosticPreparation) {
  throw new Error("Player-driven campaign slices require --production-observer for a passing result");
}
const dialogueInput = String(args["dialogue-input"] || "mouse");
if (!["mouse", "keyboard"].includes(dialogueInput)) throw new Error("--dialogue-input must be mouse or keyboard");
const mobileMode = Boolean(args.mobile);
if (mobileMode && ["all", "firefox"].includes(requestedBrowser)) {
  throw new Error("Firefox mobile emulation is unsupported; use --browser chromium for Chrome and Edge");
}
const stopAfter = String(args["stop-after"] || "").toLowerCase();
const repeatStartup = Boolean(args["repeat-startup"]);
const startupObservationMs = Number(args["startup-observation-ms"] || 15000);
const startupDiagnostic = args["startup-observation-ms"] !== undefined;
if (!Number.isFinite(startupObservationMs) || startupObservationMs < 15000 || startupObservationMs > 120000) {
  throw new Error("Startup observation must be between 15000 and 120000 ms; overrides are diagnostic-only");
}
if (fullCampaign && (!productionObserver || diagnosticPreparation || stopAfter || startupDiagnostic || repeatStartup)) {
  throw new Error("Full-campaign route requires production read-only observation and a complete, non-diagnostic run");
}
const traceMovement = Boolean(args["trace-movement"]);
// A held key persists until keyUp. Reassertion is an explicit diagnostic mode,
// not ordinary route input: slow acknowledgements made it dominate wall time.
const noRearm = !Boolean(args["reassert-movement"]) || Boolean(args["no-rearm"]);
const QA_TEMP_ROOT = "D:\\Temp\\AshenOath";
mkdirSync(QA_TEMP_ROOT, { recursive: true });
// A hardware desktop campaign must enforce its own browser FPS floor; native
// Compatibility performance is an additional, independent release gate.
const enforcePerformance = String(args["enforce-performance"] || (!functionalCandidate && fullCampaign && !mobileMode && rendererMode === "hardware" ? "true" : "false")) === "true";
if (!functionalCandidate && fullCampaign && !mobileMode && rendererMode === "hardware" && !enforcePerformance) {
  throw new Error("Hardware desktop campaign performance cannot be disabled");
}
// Browser route deadlines must remain shorter than the enclosing movement and
// interaction deadlines. A stalled renderer should produce a bounded report,
// not hold the route open until every outer timeout has expired.
const CDP_EVALUATE_TIMEOUT_MS = 10000;
const INPUT_TIMEOUT_MS = 10000;
const TELEMETRY_TIMEOUT_MS = 2500;
const CDP_OPEN_TIMEOUT_MS = 10000;
const OBSERVATION_BINDING = productionObserver
  ? "__ASHEN_OATH_READ_ONLY_OBSERVATION__" : "__ASHEN_OATH_QA_OBSERVATION__";
const ROUTE_BINDING = "__ASHEN_OATH_READ_ONLY_ROUTE__";
const OBSERVATION_WAIT_MS = 900;
const POST_INTERACTION_SETTLE_MS = 1200;
const INTERACTION_CATALOG_GRACE_MS = 5000;
const viewport = { width: 1280, height: 720 };
let commandSequence = 0;
function registeredFirefoxPath() {
  for (const hive of ["HKCU", "HKLM"]) {
    const key = `${hive}\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\App Paths\\firefox.exe`;
    const result = spawnSync("reg.exe", ["query", key, "/ve"], { encoding: "utf8", windowsHide: true });
    const path = result.stdout?.match(/REG_(?:EXPAND_)?SZ\s+([^\r\n]+)/)?.[1]?.trim();
    if (path && existsSync(path)) return path;
  }
  return "";
}
const firefoxExecutable = [
  "C:\\Program Files\\Mozilla Firefox\\firefox.exe",
  "C:\\Program Files (x86)\\Mozilla Firefox\\firefox.exe",
  registeredFirefoxPath(),
].find((path) => path && existsSync(path));
const browserCatalog = [
  ["Chrome", "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe"],
  ["Edge", "C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe"],
  ["Firefox", firefoxExecutable],
];
const browsers = browserCatalog.filter(([name, executable]) =>
  executable && existsSync(executable)
  && (requestedBrowser === "all" || (requestedBrowser === "chromium" && name !== "Firefox")
    || name.toLowerCase() === requestedBrowser)
);
if (requestedBrowser === "all" && browsers.length !== browserCatalog.length) {
  const missing = browserCatalog.filter(([, executable]) => !executable || !existsSync(executable))
    .map(([name]) => name);
  throw new Error(`QA-002 BROWSER: --browser all requires Chrome, Edge and Firefox; missing ${missing.join(', ')}`);
}
if (requestedBrowser === "chromium" && browsers.length !== 2) {
  const missing = browserCatalog.slice(0, 2).filter(([, executable]) => !existsSync(executable))
    .map(([name]) => name);
  throw new Error(`QA-002 BROWSER: --browser chromium requires Chrome and Edge; missing ${missing.join(', ')}`);
}

if (!existsSync(join(exportDir, "index.html"))) {
  throw new Error(`QA-002 BROWSER: export missing at ${exportDir}`);
}
const qaPckPath = join(exportDir, "index.pck");
const sourceManifestPath = resolve(process.cwd(), "runtime_pack_manifest.json");
const canonicalQaExport = resolve(process.cwd(), "..", ".release-gate", "AshenOath_QA");
const selectedPckStat = existsSync(qaPckPath) ? statSync(qaPckPath) : null;
const sourceManifestStat = existsSync(sourceManifestPath) ? statSync(sourceManifestPath) : null;
const canonicalPckPath = join(canonicalQaExport, "index.pck");
const canonicalPckStat = existsSync(canonicalPckPath) ? statSync(canonicalPckPath) : null;
if (!selectedPckStat) {
  throw new Error(`QA-002 BROWSER: export missing index.pck at ${exportDir}`);
}
if (sourceManifestStat && selectedPckStat.mtimeMs + 1000 < sourceManifestStat.mtimeMs) {
  throw new Error(`QA-002 BROWSER: export is older than runtime_pack_manifest.json; export from the current source: ${exportDir}`);
}
if (!productionObserver && canonicalPckStat && canonicalPckStat.mtimeMs > selectedPckStat.mtimeMs + 1000
  && resolve(exportDir) !== canonicalQaExport) {
  throw new Error(`QA-002 BROWSER: stale QA export selected at ${exportDir}; use ${canonicalQaExport}`);
}
if (!browsers.length) {
  throw new Error(`QA-002 BROWSER: requested browser is unavailable: ${requestedBrowser}`);
}
const candidateIdentity = artifactIdentity(exportDir);

const mime = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".wasm": "application/wasm",
  ".pck": "application/octet-stream",
  ".png": "image/png",
};
// D: is the canonical workspace, but sequential antivirus/disk reads from it
// can make localhost transfer tens of megabytes slower than the production
// CDN and contaminate browser startup measurements. Prime only the immutable
// candidate files before navigation; this cost is outside the measured route
// and keeps the HTTP behavior representative without changing game bytes.
const serverFileCache = new Map();
const serverGzipCache = new Map();
for (const relative of [
  "index.html",
  "index.js",
  "index.wasm",
  "index.pck",
  "runtime_pack_manifest.json",
  "packs/opening.pck",
]) {
  const path = resolve(exportDir, relative);
  if (existsSync(path)) {
    const payload = readFileSync(path);
    const encodedWasm = relative === "index.wasm" && payload[0] === 0x1f && payload[1] === 0x8b;
    serverFileCache.set(relative, encodedWasm ? gunzipSync(payload) : payload);
    // Vercel serves the production HTML, JavaScript, WebAssembly, and PCK
    // responses with gzip. Prepare equivalent bytes before the measured
    // navigation so local cold-start timing does not benchmark an artificial
    // 37.7 MB uncompressed transfer path.
    serverGzipCache.set(relative, encodedWasm ? payload : gzipSync(payload, { level: 6 }));
  }
}
const server = createServer((request, response) => {
  const requested = decodeURIComponent((request.url || "/").split("?")[0]);
  const relative = requested === "/" ? "index.html" : requested.replace(/^\/+/, "");
  const path = resolve(exportDir, normalize(relative));
  if (!path.startsWith(exportDir) || !existsSync(path)) {
    response.writeHead(relative === "favicon.ico" ? 204 : 404);
    response.end();
    return;
  }
  const cached = serverFileCache.get(relative);
  const acceptsGzip = /(?:^|,|\s)gzip(?:\s|,|$)/i.test(String(request.headers["accept-encoding"] || ""));
  const compressed = acceptsGzip ? serverGzipCache.get(relative) : null;
  const body = compressed || cached;
  const contentLength = body ? body.byteLength : statSync(path).size;
  const headers = {
    "Content-Type": mime[extname(path)] || "application/octet-stream",
    "Content-Length": String(contentLength),
    "Vary": "Accept-Encoding",
    // Match production's content-addressed runtime-pack policy. Root files and
    // the manifest still revalidate; versioned /packs/* bytes are immutable so
    // the shell prefetch can be reused by Godot instead of downloaded twice.
    "Cache-Control": relative.startsWith("packs/")
      ? "public, max-age=31536000, immutable"
      : "no-cache, must-revalidate",
  };
  if (compressed) headers["Content-Encoding"] = "gzip";
  response.writeHead(200, headers);
  if (body) response.end(body);
  else createReadStream(path).pipe(response);
});
// This machine allocates some ephemeral ports in Firefox's denied service
// range (for example4190). Bind a normal high localhost port instead.
for (let attempt = 0; ; attempt += 1) {
  try {
    await new Promise((done, reject) => {
      const failed = error => reject(error);
      server.once("error", failed);
      server.listen(30000 + Math.floor(Math.random() * 30000), "127.0.0.1", () => {
        server.removeListener("error", failed);
        done();
      });
    });
    break;
  } catch (error) {
    if (error.code !== "EADDRINUSE" || attempt >= 9) throw error;
  }
}
const port = server.address().port;

const sleep = (ms) => new Promise((done) => setTimeout(done, ms));
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

async function fetchJson(url, timeout = 5000) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeout);
  try {
    const response = await fetch(url, { signal: controller.signal });
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    return response.json();
  } finally {
    clearTimeout(timer);
  }
}

async function waitFor(predicate, label, timeout = timeoutMs) {
  // Functional certification records slow rendering rather than claiming the
  // strict response targets. Keep a fixed finite watchdog, never an open wait.
  // Subsecond focus peeks are optional opportunities between waypoints, not
  // required outcomes; stretching them delays every still-distant approach.
  if (functionalCandidate && timeout >= 1000) timeout = Math.max(timeout, 30000);
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

async function withDeadline(taskFactory, label, limit = timeoutMs, onFinish = () => {}) {
  // Individual route helpers have their own movement budgets. Keep the CLI
  // timeout authoritative for the whole player route as well, otherwise a
  // sequence of valid inner waits can outlive the advertised browser deadline
  // and prevent the report/cleanup path from ever running.
  let timer;
  const deadline = new Promise((_, reject) => {
    timer = setTimeout(() => reject(fatal(`${label} timed out after ${limit} ms`)), limit);
  });
  const task = Promise.resolve().then(taskFactory);
  try {
    return await Promise.race([task, deadline]);
  } finally {
    onFinish();
    clearTimeout(timer);
  }
}

function routeTransport(cdp) {
  let active = true;
  const guarded = new Set(["send", "sendObservation", "_sendNow", "evaluate", "waitForObservation"]);
  const proxy = new Proxy(cdp, {
    get(target, key, receiver) {
      const value = Reflect.get(target, key, receiver);
      if (!guarded.has(key) || typeof value !== "function") return value;
      return (...args) => {
        if (!active) return Promise.reject(fatal("Player route transport expired"));
        return Reflect.apply(value, receiver, args);
      };
    },
  });
  return { cdp: proxy, revoke() { active = false; } };
}

class Cdp {
  constructor(url) {
    this.nextId = 1;
    this.pending = new Map();
    this.events = [];
    this.maxEvents = 24000;
    this.networkChunks = new Map();
    this.lastConsoleEvent = null;
    this.evidenceOverflow = false;
    this.inputTail = Promise.resolve();
    this.closed = false;
    this.observationQueue = [];
    this.observationWaiters = [];
    this.lastObservation = null;
    this.lastRouteResult = null;
    this.routeBindingEnabled = false;
    this.zonePerformance = new ZonePerformanceEvidence();
    this.transportMetrics = {};
    this.observationMetrics = { count: 0, first_at_ms: 0, last_at_ms: 0, max_gap_ms: 0 };
    this.socket = url ? new WebSocket(url) : null;
  }
  async open(timeoutMs = CDP_OPEN_TIMEOUT_MS) {
    await new Promise((done, reject) => {
      let timer;
      const finish = (error = null) => {
        clearTimeout(timer);
        this.socket.removeEventListener("open", onOpen);
        this.socket.removeEventListener("error", onError);
        this.socket.removeEventListener("close", onClose);
        if (error) reject(error);
        else done();
      };
      const onOpen = () => finish();
      const onError = () => finish(new Error("CDP socket failed"));
      const onClose = () => finish(new Error("CDP socket closed before open"));
      this.socket.addEventListener("open", onOpen, { once: true });
      this.socket.addEventListener("error", onError, { once: true });
      this.socket.addEventListener("close", onClose, { once: true });
      timer = setTimeout(() => {
        try { this.socket.close(); } catch { /* already closed */ }
        finish(new Error(`CDP socket open timed out after ${timeoutMs} ms`));
      }, timeoutMs);
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
        if (message.method === "Runtime.bindingCalled" && message.params?.name === ROUTE_BINDING) {
          try { this._publishRouteResult(JSON.parse(message.params.payload)); } catch { /* malformed response cannot pass */ }
          return;
        }
        if (message.method === "Runtime.bindingCalled"
          && message.params?.name === OBSERVATION_BINDING) {
          try {
            this._publishObservation(JSON.parse(message.params.payload));
          } catch {
            // Keep the event stream alive if a diagnostic payload is malformed.
          }
          return;
        }
        this.recordEvent(message);
      }
    });
    this.socket.addEventListener("close", () => {
      this.closed = true;
      const error = new Error("CDP socket closed");
      for (const [id, pending] of this.pending) {
        this.pending.delete(id);
        pending.reject(error);
      }
      for (const waiter of this.observationWaiters.splice(0)) waiter(null);
    }, { once: true });
  }
  send(method, params = {}, timeoutMs = 15000) {
    // Preserve input edge order without coupling key release to acknowledgements
    // from a stalled Runtime/Page command. CDP correlates replies by request ID.
    if (!method.startsWith("Input.")) return this._sendNow(method, params, timeoutMs);
    const run = () => this._sendNow(method, params, timeoutMs);
    const result = this.inputTail.then(run, run);
    this.inputTail = result.catch(() => {});
    return result;
  }
  recordEvent(message) {
    if (!["Runtime.consoleAPICalled", "Runtime.exceptionThrown", "Log.entryAdded",
      "Network.requestWillBeSent", "Network.responseReceived", "Network.dataReceived",
      "Network.loadingFinished", "Network.loadingFailed", "WebAudio.contextCreated",
      "WebAudio.contextChanged"].includes(message.method)) return;
    if (message.method === "Network.dataReceived") {
      const previousChunk = this.networkChunks.get(message.params.requestId);
      if (previousChunk) {
        previousChunk.params.dataLength += message.params.dataLength || 0;
        previousChunk.params.encodedDataLength += message.params.encodedDataLength || 0;
        return;
      }
      this.networkChunks.set(message.params.requestId, message);
    }
    const previous = this.lastConsoleEvent;
    if (message.method === "Runtime.consoleAPICalled" && previous
      && message.params.type === previous.params.type
      && JSON.stringify(message.params.args) === JSON.stringify(previous.params.args)) {
      previous.repeat_count = (previous.repeat_count || 1) + 1;
      return;
    }
    if (message.method === "Runtime.consoleAPICalled") this.lastConsoleEvent = message;
    if (this.events.length >= this.maxEvents) { this.evidenceOverflow = true; return; }
    this.events.push(message);
  }
  // Observation reads must not wait behind an earlier Runtime.evaluate. The
  // game and the browser share one Web main thread, so a slow snapshot can
  // otherwise serialize the next input event and make a state that is already
  // visible to the renderer look absent to the verifier.
  sendObservation(method, params = {}, timeoutMs = 15000) {
    return this._sendNow(method, params, timeoutMs);
  }
  _publishObservation(state) {
    if (!state || typeof state !== "object") return;
    const now = Date.now();
    const metrics = this.observationMetrics;
    if (metrics.count) metrics.max_gap_ms = Math.max(metrics.max_gap_ms, now - metrics.last_at_ms);
    else metrics.first_at_ms = now;
    metrics.last_at_ms = now;
    metrics.count += 1;
    this.lastObservation = state;
    this.zonePerformance.observe(state);
    const waiter = this.observationWaiters.shift();
    if (waiter) waiter(state);
    else {
      this.observationQueue.push(state);
      if (this.observationQueue.length > 8) this.observationQueue.shift();
    }
  }
  _publishRouteResult(result) {
    if (result?.read_only === true && Number.isInteger(result.request_id) && typeof result.target_id === "string") {
      this.lastRouteResult = result;
    }
  }
  takeObservation() {
    // Route decisions must use the newest published frame. Keeping older
    // samples after a pop lets a later combat step consume stale player,
    // camera, or enemy state and steer toward a position that no longer
    // exists. The queue is only a coalescing buffer, so discard superseded
    // samples whenever a caller takes one.
    const latest = this.observationQueue.pop() || null;
    this.observationQueue.length = 0;
    return latest;
  }
  waitForObservation(timeoutMs = OBSERVATION_WAIT_MS) {
    const queued = this.takeObservation();
    if (queued) return Promise.resolve(queued);
    if (this.closed) return Promise.resolve(null);
    return new Promise((done) => {
      const timer = setTimeout(() => {
        const index = this.observationWaiters.indexOf(resolveObservation);
        if (index >= 0) this.observationWaiters.splice(index, 1);
        done(null);
      }, timeoutMs);
      const resolveObservation = (state) => {
        clearTimeout(timer);
        done(state);
      };
      this.observationWaiters.push(resolveObservation);
    });
  }
  _sendNow(method, params, timeoutMs) {
    if (this.evidenceOverflow) return Promise.reject(fatal("Browser evidence event budget exceeded; run is incomplete"));
    const started = Date.now();
    const metrics = this.transportMetrics[method] ||= { sent: 0, completed: 0, failed: 0, total_ms: 0, max_ms: 0 };
    metrics.sent += 1;
    const finish = (failed) => {
      const elapsed = Date.now() - started;
      metrics.completed += 1;
      metrics.failed += Number(failed);
      metrics.total_ms += elapsed;
      metrics.max_ms = Math.max(metrics.max_ms, elapsed);
    };
    return this._sendPacket(method, params, timeoutMs).then(
      (result) => { finish(false); return result; },
      (error) => { finish(true); throw error; },
    );
  }
  transportSummary() {
    return {
      methods: structuredClone(this.transportMetrics),
      observations: { ...this.observationMetrics },
      pending_requests: this.pending.size,
    };
  }
  _sendPacket(method, params, timeoutMs) {
    const id = this.nextId++;
    return new Promise((done, reject) => {
      if (this.closed || this.socket.readyState !== WebSocket.OPEN) {
        reject(new Error(`CDP ${method} unavailable: socket is closed`));
        return;
      }
      const timer = setTimeout(() => {
        this.pending.delete(id);
        reject(new Error(`CDP ${method} timed out`));
      }, timeoutMs);
      this.pending.set(id, {
        resolve: (value) => { clearTimeout(timer); done(value); },
        reject: (error) => { clearTimeout(timer); reject(error); },
      });
      this.socket.send(JSON.stringify({ id, method, params }));
    });
  }
  async evaluate(expression, timeoutMs = CDP_EVALUATE_TIMEOUT_MS) {
    const response = await this.send("Runtime.evaluate", {
      expression,
      returnByValue: true,
      // All route expressions are synchronous reads or assignments. Waiting
      // for a promise here can stall the Runtime domain after Godot pauses its
      // scene tree for dialogue even though the canvas continues rendering.
      awaitPromise: false,
    }, timeoutMs);
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

class FirefoxTransport extends Cdp {
  constructor(page) {
    super(null);
    this.page = page;
    this.requestIds = new WeakMap();
    this.nextRequestId = 1;
  }
  async open() {
    const record = (method, params) => {
      this.recordEvent({ method, params });
    };
    this.page.on("console", (message) => {
      const text = message.text();
      if (text.startsWith("__ASHEN_FIREFOX_BINDING__")) {
        const payload = JSON.parse(text.slice("__ASHEN_FIREFOX_BINDING__".length));
        if (payload.name === ROUTE_BINDING) this._publishRouteResult(JSON.parse(payload.value));
        else if (payload.name === OBSERVATION_BINDING) this._publishObservation(JSON.parse(payload.value));
        return;
      }
      record("Runtime.consoleAPICalled", { type: message.type(), args: [{ value: text }] });
    });
    this.page.on("pageerror", (error) => record("Runtime.exceptionThrown", {
      exceptionDetails: { text: error.message, stack: error.stack },
    }));
    this.page.on("request", (request) => {
      const requestId = String(this.nextRequestId++);
      this.requestIds.set(request, requestId);
      record("Network.requestWillBeSent", { requestId, request: { url: request.url() }, timestamp: Date.now() / 1000 });
    });
    this.page.on("response", (response) => {
      const requestId = this.requestIds.get(response.request());
      if (requestId) record("Network.responseReceived", {
        requestId, response: { url: response.url(), status: response.status() }, timestamp: Date.now() / 1000,
      });
    });
    this.page.on("requestfinished", (request) => {
      const requestId = this.requestIds.get(request);
      if (requestId) record("Network.loadingFinished", { requestId, timestamp: Date.now() / 1000 });
    });
    this.page.on("requestfailed", (request) => {
      const requestId = this.requestIds.get(request);
      if (requestId) record("Network.loadingFailed", {
        requestId, canceled: false, errorText: request.failure()?.errorText || "request failed",
        timestamp: Date.now() / 1000,
      });
    });
    this.page.on("close", () => { this.closed = true; });
  }
  async _sendPacket(method, params, timeoutMs) {
    const action = async () => {
      switch (method) {
        case "Page.enable": case "Log.enable": case "Network.enable":
        case "Performance.enable": case "Runtime.enable":
        case "Emulation.setFocusEmulationEnabled": return {};
        case "Emulation.setDeviceMetricsOverride":
          // Puppeteer's convenience method also sends an unsupported Firefox
          // orientation override. Request only the desktop viewport we test.
          await this.page.mainFrame().browsingContext.setViewport({
            viewport: { width: params.width, height: params.height },
            devicePixelRatio: params.deviceScaleFactor,
          });
          return {};
        case "Runtime.addBinding":
          if (browserSmoke) return {};
          // Keep the observer callback in the content realm. Firefox can deny
          // cross-realm arguments in Puppeteer's exposed Promise callback.
          await this.page.evaluateOnNewDocument(`(() => {
            const name = ${JSON.stringify(params.name)};
            globalThis[name] = value => console.debug("__ASHEN_FIREFOX_BINDING__" + JSON.stringify({name, value}));
          })()`);
          return {};
        case "Page.addScriptToEvaluateOnNewDocument":
          await this.page.evaluateOnNewDocument(params.source);
          return {};
        case "Page.navigate":
          await this.page.goto(params.url, { waitUntil: "domcontentloaded", timeout: timeoutMs });
          return {};
        case "Page.bringToFront": await this.page.bringToFront(); return {};
        case "Page.captureScreenshot":
          return { data: (await this.page.screenshot({ encoding: "base64" })).toString() };
        case "Runtime.evaluate":
          try {
            if (browserSmoke) {
              const encoded = await this.page.evaluate(`Promise.resolve((0, eval)(${JSON.stringify(params.expression)})).then(value => JSON.stringify(value))`);
              return { result: { value: encoded === undefined ? undefined : JSON.parse(encoded) } };
            }
            return { result: { value: await this.page.evaluate(params.expression) } };
          } catch (error) {
            return { exceptionDetails: { text: error.message } };
          }
        case "Input.dispatchKeyEvent": {
          const key = params.key || params.code;
          if (params.type === "keyUp") await this.page.keyboard.up(key);
          else await this.page.keyboard.down(key);
          return {};
        }
        case "Input.dispatchMouseEvent":
          if (params.type === "mouseMoved") await this.page.mouse.move(params.x, params.y);
          else if (params.type === "mousePressed") {
            await this.page.mouse.move(params.x, params.y);
            await this.page.mouse.down({ button: params.button || "left", clickCount: params.clickCount || 1 });
          } else if (params.type === "mouseReleased") {
            await this.page.mouse.move(params.x, params.y);
            await this.page.mouse.up({ button: params.button || "left", clickCount: params.clickCount || 1 });
          }
          return {};
        case "Performance.getMetrics": return { metrics: [] };
        default: throw new Error(`Firefox BiDi transport does not support ${method}`);
      }
    };
    let timer;
    try {
      return await Promise.race([
        action(),
        new Promise((_, reject) => {
          timer = setTimeout(() => reject(new Error(`Firefox ${method} timed out`)), timeoutMs);
        }),
      ]);
    } finally {
      clearTimeout(timer);
    }
  }
  close() { this.closed = true; }
}

function loadingTimeline(cdp) {
  // Preserve the complete startup/transition chronology even when the general
  // console tail is capped. One timeline distinguishes network, mount, build,
  // first-render, and handoff stalls without one-field telemetry iterations.
  return cdp.events
    .filter((event) => event.method === "Runtime.consoleAPICalled")
    .map((event) => ({
      timestamp: Number(event.params.timestamp || 0),
      type: event.params.type,
      text: event.params.args.map((arg) => String(arg.value ?? arg.description ?? "")).join(" "),
    }))
    .filter((event) => event.text.startsWith("LOADING:") || event.text.startsWith("ZONE_COMPOSITION:"));
}

function audioContextTimeline(cdp) {
  return cdp.events
    .filter((event) => event.method === "WebAudio.contextCreated" || event.method === "WebAudio.contextChanged")
    .map((event) => ({
      context_id: String(event.params.context?.contextId || ""),
      type: String(event.params.context?.contextType || ""),
      state: String(event.params.context?.contextState || ""),
    }));
}

async function observedAudioContexts(cdp, name) {
  if (name !== "Firefox") return audioContextTimeline(cdp);
  const timeline = await cdp.evaluate("window.__ASHEN_QA_AUDIO_TIMELINE__ || []");
  if (!Array.isArray(timeline)) throw new Error("Firefox audio probe did not return a timeline");
  return timeline;
}

function consoleWarningLine(line) {
  // Godot's Web stdout bridge reports push_warning() as a Chromium
  // console.error event. Preserve those diagnostics in the report without
  // confusing a deliberate game warning with a JavaScript or runtime error.
  return line.includes("WARNING:") || line.includes("at: push_warning");
}

function consoleWarnings(cdp) {
  const runtime = cdp.events.filter((event) =>
    event.method === "Runtime.consoleAPICalled"
    || (event.method === "Log.entryAdded" && event.params.entry.level === "warning")
  ).map((event) => JSON.stringify(event.params).slice(0, 1200));
  return runtime.filter(consoleWarningLine);
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
    && !consoleWarningLine(line)
  );
}

async function dispatchKey(cdp, code, key, down, raw = false, autoRepeat = false) {
  const virtualKeyCode = code === "KeyW" ? 87
    : code === "KeyA" ? 65
    : code === "KeyS" ? 83
    : code === "KeyD" ? 68
    : code === "KeyE" ? 69
    : code === "KeyC" ? 67
    : code === "KeyR" ? 82
    : code === "KeyF" ? 70
    : code === "KeyQ" ? 81
    : code === "KeyT" ? 84
    : code === "Digit1" ? 49
    : code === "Digit2" ? 50
    : code === "Digit3" ? 51
    : code === "ShiftLeft" ? 16
    : code === "Space" ? 32
    : code === "ArrowLeft" ? 37
    : code === "ArrowUp" ? 38
    : code === "ArrowRight" ? 39
    : code === "ArrowDown" ? 40
    : code === "Tab" ? 9
    : code === "F9" ? 120
    : code === "Enter" ? 13 : 0;
  await cdp.send("Input.dispatchKeyEvent", {
    type: down ? (raw ? "rawKeyDown" : "keyDown") : "keyUp",
    key,
    code,
    windowsVirtualKeyCode: virtualKeyCode,
    nativeVirtualKeyCode: virtualKeyCode,
    ...(down && !raw && !autoRepeat && (key.length === 1 || code === "Enter")
      ? { text: code === "Enter" ? "\r" : key, unmodifiedText: code === "Enter" ? "\r" : key }
      : {}),
    ...(down && autoRepeat ? { autoRepeat: true } : {}),
    modifiers: code === "ShiftLeft" && down ? 8 : 0,
  }, INPUT_TIMEOUT_MS);
}

async function dispatchMovementKey(cdp, code, key, down) {
  // Chromium's rawKeyDown packet is not a durable held-key contract for the
  // Godot canvas: v67 received the first movement edge, then stopped while
  // the CharacterBody remained on a valid floor. Use the ordinary DOM key
  // edge, including the physical code and virtual key code, so Godot keeps a
  // normal key state until the matching keyUp. This remains a real input
  // gesture and does not use telemetry or gameplay state mutation.
  await dispatchKey(cdp, code, key, down, false);
}

async function turnCameraToward(cdp, desiredYaw, currentYaw, tolerance = 0.12, timeoutMs = 12000) {
  await cdp.send("Page.bringToFront");
  const deadline = Date.now() + timeoutMs;
  let yaw = Number(currentYaw);
  while (Date.now() < deadline) {
    if (!Number.isFinite(yaw)) {
      const initial = await cdp.waitForObservation();
      yaw = Number(initial?.camera?.yaw);
      if (!Number.isFinite(yaw)) continue;
    }
    const delta = angleDelta(yaw, desiredYaw);
    if (Math.abs(delta) <= tolerance) return yaw;
    const [code, key] = delta > 0 ? ["ArrowLeft", "ArrowLeft"] : ["ArrowRight", "ArrowRight"];
    const duration = clamp(Math.abs(delta) / 2.2 * 1000, 90, 340);
    try {
      await dispatchKey(cdp, code, key, true);
      await sleep(duration);
    } finally {
      await dispatchKey(cdp, code, key, false).catch(() => {});
    }
    cdp.observationQueue.length = 0;
    const observed = await cdp.waitForObservation();
    yaw = Number(observed?.camera?.yaw);
  }
  throw new Error(`Physical camera turn did not converge to ${desiredYaw.toFixed(3)} rad`);
}

const MOVEMENT_HEARTBEAT_MS = 180;

async function dispatchMovementHeartbeat(cdp, selected) {
  // A Compatibility Web frame can lose the browser-held state even though no
  // keyup was delivered. Reassert the same physical key as an ordinary
  // auto-repeat edge while the gesture is active. InputRouter treats this as a
  // keydown, so it refreshes the retained key state without changing the
  // player's transform or bypassing gameplay input.
  for (const [code, key] of selected) {
    await dispatchKey(cdp, code, key, true, false, true);
  }
}

function startMovementHeartbeat(cdp, selected, isActive) {
  if (noRearm) return async () => {};
  // Keep reassertion independent from route telemetry. A sparse observation
  // can wait longer than the heartbeat interval, so scheduling the heartbeat
  // only from the movement-read loop does not actually preserve the held key.
  let active = true;
  let inFlight = null;
  const timer = setInterval(() => {
    if (!active || !isActive() || inFlight) return;
    // Coalesce slow sends instead of building an unbounded command queue. A
    // stalled browser must not make movement cleanup wait behind every missed
    // heartbeat since the last observation.
    inFlight = dispatchMovementHeartbeat(cdp, selected)
      .catch(() => {})
      .finally(() => { inFlight = null; });
  }, MOVEMENT_HEARTBEAT_MS);
  return async () => {
    active = false;
    clearInterval(timer);
    if (inFlight) await Promise.race([inFlight, sleep(250)]);
  };
}

const MOVEMENT_KEYS = [["KeyW", "w"], ["KeyA", "a"], ["KeyS", "s"], ["KeyD", "d"]];

async function releaseMovementKeys(cdp) {
  for (const [code, key] of MOVEMENT_KEYS) {
    await dispatchMovementKey(cdp, code, key, false);
  }
}

async function focusGameCanvas(cdp) {
  await cdp.evaluate(`(() => {
    window.focus();
    const canvas = document.querySelector("canvas");
    if (canvas) {
      canvas.tabIndex = 0;
      canvas.focus({ preventScroll: true });
    }
  })()`);
}

async function refocusGameplay(cdp) {
  await cdp.send("Page.bringToFront");
  await focusGameCanvas(cdp);
  // A harmless pointer move reasserts the renderer surface after a menu
  // button consumed the preceding click. It does not activate gameplay.
  await cdp.send("Input.dispatchMouseEvent", {
    type: "mouseMoved", x: Math.round(viewport.width * 0.5),
    y: Math.round(viewport.height * 0.12), button: "none",
  }, INPUT_TIMEOUT_MS);
  await cdp.send("Input.dispatchMouseEvent", {
    type: "mousePressed", x: Math.round(viewport.width * 0.5),
    y: Math.round(viewport.height * 0.5), button: "left", clickCount: 1,
  }, INPUT_TIMEOUT_MS);
  await sleep(35);
  await cdp.send("Input.dispatchMouseEvent", {
    type: "mouseReleased", x: Math.round(viewport.width * 0.5),
    y: Math.round(viewport.height * 0.5), button: "left", clickCount: 1,
  }, INPUT_TIMEOUT_MS);
}

async function tapKey(cdp, code, key, duration = 70, raw = false) {
	await dispatchKey(cdp, code, key, true, raw);
	await sleep(duration);
	await dispatchKey(cdp, code, key, false, raw);
}

async function tapGameplayKey(cdp, code, key, duration = 80) {
  // Interaction edges follow the same focused raw-input contract as movement.
  // After a long route, the browser can keep the page visible while dropping
  // one logical keydown at the canvas boundary; reasserting page focus and
  // using one physical edge avoids changing gameplay state or duplicating it.
  await cdp.send("Page.bringToFront");
  if (code === "KeyE") await focusGameCanvas(cdp);
  await dispatchKey(cdp, code, key, false, true);
  await dispatchKey(cdp, code, key, true, true);
  await sleep(duration);
  try {
    await dispatchKey(cdp, code, key, false, true);
  } catch (error) {
    // A real interaction keydown can synchronously open Godot's paused
    // dialogue tree. Chromium occasionally withholds the keyup acknowledgement
    // while that frame changes ownership even though the event is delivered.
    // The subsequent dialogue-open assertion proves the action occurred, and
    // useInteraction sends a second release after the dialogue closes.
    if (!String(error?.message || error).includes("timed out")) throw error;
  }
}

async function acceptDialogue(cdp, raw = false) {
	// Godot keeps Button focus inside its paused UI tree. Keep this path free of
	// DOM Runtime evaluation: the active page already owns the canvas target and
	// a post-pause focus call can stall Compatibility's Runtime domain.
	await cdp.send("Page.bringToFront");
	await dispatchKey(cdp, "Enter", "Enter", true, raw);
	await sleep(260);
	await dispatchKey(cdp, "Enter", "Enter", false, raw);
}

async function holdKey(cdp, code, key, duration) {
  // Do not use Runtime.evaluate to focus the canvas during combat. The
  // Godot Web renderer owns the page's main thread and can leave the Runtime
  // domain pending while an encounter shader/material becomes visible. CDP's
  // physical key events are delivered to the active page without a DOM focus
  // mutation, which is also the path used by the dialogue input proof.
  await cdp.send("Page.bringToFront");
  // Clear every raw movement key before the pulse. The previous route helper
  // can finish after a sparse frame with a logical key-up while InputRouter's
  // raw held-key state still contains W/A/S/D. Leaving one of those keys alive
  // turns a precise facing pulse into an unintended normalized chord.
  const movementKeys = [["KeyW", "w"], ["KeyA", "a"], ["KeyS", "s"], ["KeyD", "d"]];
  for (const [movementCode, movementKey] of movementKeys) {
    await dispatchKey(cdp, movementCode, movementKey, false, true);
  }
  await sleep(55);
  try {
    // Use the raw physical-key path as the movement contract. After pointer
    // capture, Chromium can drop a logical keydown before the next sparse
    // Compatibility frame; the raw path reaches InputRouter's held-key state.
    await dispatchKey(cdp, code, key, true, true);
    const deadline = Date.now() + duration;
    let nextReassert = Date.now() + 480;
    while (Date.now() < deadline) {
      await sleep(Math.min(180, Math.max(1, deadline - Date.now())));
      if (Date.now() >= nextReassert && Date.now() < deadline) {
        await dispatchKey(cdp, code, key, true, true, true);
        nextReassert = Date.now() + 480;
      }
    }
  } finally {
    // Raw release is required here; a logical key-up alone does not clear the
    // raw keyboard merge used by InputRouter.movement_vector().
    for (const [movementCode, movementKey] of movementKeys) {
      await dispatchKey(cdp, movementCode, movementKey, false, true).catch(() => {});
    }
  }
}

async function holdAxisTowardPoint(cdp, selected, waypoint, tolerance, maxDuration, acceptPosition = null, readState = telemetry) {
  // Keep one physical key pair open for the entire route leg. Short
  // keydown/keyup pulses can be delivered out of order when a Compatibility
  // frame is sparse, leaving the game with a valid floor and no movement.
  // Re-arm only after observed no-progress; never send a periodic auto-repeat.
  await cdp.send("Page.bringToFront");
  await releaseMovementKeys(cdp);
  await sleep(60);
  const started = Date.now();
  let lastState = null;
  let lastProgressAt = started;
  let closestDistance = Number.POSITIVE_INFINITY;
  let pressed = false;
  let stopHeartbeat = async () => {};
  const pressSelected = async () => {
    if (pressed) return;
    for (const [code, key] of selected) await dispatchMovementKey(cdp, code, key, true);
    pressed = true;
  };
  const releaseSelected = async () => {
    if (!pressed) return;
    for (const [code, key] of selected.slice().reverse()) {
      await dispatchMovementKey(cdp, code, key, false).catch(() => {});
    }
    pressed = false;
  };
  try {
    await pressSelected();
    stopHeartbeat = startMovementHeartbeat(cdp, selected, () => pressed);
    while (Date.now() - started < maxDuration) {
      lastState = await readState(cdp).catch(() => null);
      const player = lastState?.player?.position;
      if (!player) {
        await sleep(120);
        continue;
      }
      if (acceptPosition && acceptPosition(player, lastState)) break;
      const distance = Math.hypot(
        Number(waypoint.x) - Number(player.x),
        Number(waypoint.z) - Number(player.z),
      );
      if (distance <= tolerance) break;
      if (distance < closestDistance - 0.035) {
        closestDistance = distance;
        lastProgressAt = Date.now();
      } else if (Number.isFinite(closestDistance) && distance > closestDistance + 0.035) {
        // A digital hold has passed its closest observed point. Release now
        // so the caller can replan instead of continuing away from the target.
        break;
      } else if (!noRearm && Date.now() - lastProgressAt >= 1200) {
        await releaseSelected();
        await sleep(80);
        await pressSelected();
        lastProgressAt = Date.now();
      }
      await sleep(90);
    }
  } finally {
    await stopHeartbeat();
    await releaseSelected();
    await releaseMovementKeys(cdp).catch(() => {});
  }
  await sleep(70);
  return lastState || await readState(cdp).catch(() => null);
}

async function holdTowardPoint(cdp, waypoint, timeout = 7000, expectedZone = "", acceptPosition = null, forcedYaw = null) {
  // Keep a single paired physical input open for this route leg. Releasing the
  // key every few hundred milliseconds was the source of the H64 partial
  // movement trace: Compatibility could see the first edge, miss a later pair,
  // and leave the player on a valid floor with no progress. A bounded re-arm
  // handles a genuinely lost browser edge without fabricating movement.
  await cdp.send("Page.bringToFront");
  await focusGameCanvas(cdp).catch(() => {});
  const initialState = await telemetry(cdp).catch(() => null);
  const player = initialState?.player?.position;
  // The route caller has just converged the camera to the current waypoint.
  // Prefer that authoritative bearing over a coalesced observation, which can
  // still contain the previous segment's yaw on a sparse Web frame.
  const yaw = forcedYaw != null && Number.isFinite(Number(forcedYaw))
    ? Number(forcedYaw)
    : Number(initialState?.camera?.yaw || 0);
  const dx = Number(waypoint.x) - Number(player?.x || 0);
  const dz = Number(waypoint.z) - Number(player?.z || 0);
  const segmentLength = Math.hypot(dx, dz);
  const segmentDirection = segmentLength > 0.001
    ? { x: dx / segmentLength, z: dz / segmentLength }
    : { x: 0, z: 0 };
  // Movement is camera-relative in the actual controller. The old diagnostic
  // always held W, which worked for the north/south road but could never reach
  // a side-offset interaction such as Anwen at the end of the route.
  const forward = dx * -Math.sin(yaw) + dz * -Math.cos(yaw);
  const right = dx * Math.cos(yaw) + dz * -Math.sin(yaw);
  // Convert the desired world-space direction into the actual camera-relative
  // movement vector. A dominant-axis approximation can turn a near-forward
  // route into a lateral walk when the camera has a small yaw offset, leaving
  // the player parked against a bridge approach or prop. Holding both axes
  // preserves the requested route without changing the player's transform.
  const inputX = right / Math.max(segmentLength, 0.001);
  const inputY = -forward / Math.max(segmentLength, 0.001);
  const selected = [];
  if (Math.abs(inputX) > 0.14) selected.push(inputX >= 0 ? ["KeyD", "d"] : ["KeyA", "a"]);
  if (Math.abs(inputY) > 0.14) selected.push(inputY >= 0 ? ["KeyS", "s"] : ["KeyW", "w"]);
  if (selected.length === 0) selected.push(["KeyW", "w"]);
  await releaseMovementKeys(cdp);
  await sleep(60);
  const started = Date.now();
  let lastState = null;
  const movementTrace = [];
  let lastTraceAt = 0;
  let lastProgressAt = started;
  let closestDistance = segmentLength;
  let pressed = false;
  let stopHeartbeat = async () => {};
  const pressSelected = async () => {
    if (pressed) return;
    for (const [code, key] of selected) await dispatchMovementKey(cdp, code, key, true);
    pressed = true;
  };
  const releaseSelected = async () => {
    if (!pressed) return;
    for (const [code, key] of selected.slice().reverse()) {
      await dispatchMovementKey(cdp, code, key, false).catch(() => {});
    }
    pressed = false;
  };
  try {
    await pressSelected();
    stopHeartbeat = startMovementHeartbeat(cdp, selected, () => pressed);
    while (Date.now() - started < timeout) {
      lastState = await telemetry(cdp).catch(() => null);
      if (expectedZone && lastState?.zone === expectedZone) break;
      const currentPlayer = lastState?.player?.position;
      if (!currentPlayer) {
        await sleep(120);
        continue;
      }
      if (acceptPosition && acceptPosition(currentPlayer, lastState)) break;
      const distance = Math.hypot(waypoint.x - currentPlayer.x, waypoint.z - currentPlayer.z);
      const projected = (currentPlayer.x - Number(initialState?.player?.position?.x || 0)) * segmentDirection.x
        + (currentPlayer.z - Number(initialState?.player?.position?.z || 0)) * segmentDirection.z;
      if (traceMovement && Date.now() - lastTraceAt >= 600) {
        movementTrace.push({
          x: Number(currentPlayer.x),
          z: Number(currentPlayer.z),
          distance: Number(distance.toFixed(3)),
          velocity: lastState?.player?.velocity || null,
          slide_collisions: Array.isArray(lastState?.player?.slide_collisions)
            ? lastState.player.slide_collisions.map((collision) => ({
                collider: collision.collider || null,
                normal: collision.normal || null,
              }))
            : [],
          focus: lastState?.focus?.id || "",
          selected: selected.map((entry) => entry[0]),
        });
        lastTraceAt = Date.now();
      }
      if (distance <= 0.58 || (segmentLength > 0.001 && projected >= segmentLength + 0.25)) break;
      if (distance < closestDistance - 0.04) {
        closestDistance = distance;
        lastProgressAt = Date.now();
      } else if (!noRearm && Date.now() - lastProgressAt >= 1200) {
        await releaseSelected();
        await sleep(80);
        await pressSelected();
        lastProgressAt = Date.now();
      }
      await sleep(90);
    }
  } finally {
    await stopHeartbeat();
    await releaseSelected();
    await releaseMovementKeys(cdp).catch(() => {});
  }
  await sleep(70);
  // Return a settled sample after all pulse releases. This observes ordinary
  // gameplay state and cannot leave a browser-held key behind on failure.
  const settledState = await telemetry(cdp).catch(() => null);
  const result = settledState || lastState || await telemetry(cdp).catch(() => null);
  if (result && traceMovement) result._movement_trace = movementTrace;
  return result;
}

async function approachPointWithReplan(cdp, waypoint, timeout = 15000, tolerance = 1.15, acceptPosition = null) {
  // Browser input is digital even though the controller resolves a continuous
  // camera-relative vector. Holding two axes at equal strength can rotate the
  // resulting world vector into a nearby enemy or prop. Use one sustained real
  // axis at a time, stop at the closest observed point, and re-plan so sparse
  // Compatibility frames cannot drop the hold or make it oscillate.
  const started = Date.now();
  let lastState = null;
  let stalledSteps = 0;
  while (Date.now() - started < timeout) {
    const state = await telemetry(cdp).catch(() => null);
    const player = state?.player?.position;
    if (!player) {
      await sleep(120);
      continue;
    }
    if (acceptPosition && acceptPosition(player, state)) return state;
    const dx = Number(waypoint.x) - Number(player.x);
    const dz = Number(waypoint.z) - Number(player.z);
    const distance = Math.hypot(dx, dz);
    if (distance <= tolerance) return state;
    // Interaction routes must use the same camera-to-waypoint contract as
    // gate routes and the native player-route verifier. Keeping the menu's
    // arbitrary gameplay yaw here makes a due-north/south leg select a lateral
    // digital axis, so the re-plan can drift sideways without ever reaching
    // the speaker even though the floor and collision corridor are clear.
    const desiredYaw = Math.atan2(-dx, -dz);
    const yaw = await turnCameraToward(cdp, desiredYaw, state.camera?.yaw);
    const forward = dx * -Math.sin(yaw) + dz * -Math.cos(yaw);
    const right = dx * Math.cos(yaw) + dz * -Math.sin(yaw);
    const inputX = right / Math.max(distance, 0.001);
    const inputY = -forward / Math.max(distance, 0.001);
    const selected = Math.abs(inputX) >= Math.abs(inputY)
      ? (inputX >= 0 ? ["KeyD", "d"] : ["KeyA", "a"])
      : (inputY >= 0 ? ["KeyS", "s"] : ["KeyW", "w"]);
    const beforeDistance = distance;
    // Polling inside the hold gives sparse browser frames time to apply the
    // real key while releasing on the first distance increase prevents the
    // long-hold overshoot reproduced by the native route probe.
    const stepDuration = clamp(beforeDistance / 3.8 * 1000, 40, 820);
    await holdAxisTowardPoint(cdp, [selected], waypoint, tolerance, stepDuration, acceptPosition);
    lastState = await telemetry(cdp).catch(() => null);
    const afterPlayer = lastState?.player?.position;
    if (!afterPlayer) continue;
    if (acceptPosition && acceptPosition(afterPlayer, lastState)) return lastState;
    const afterDistance = Math.hypot(
      Number(waypoint.x) - Number(afterPlayer.x),
      Number(waypoint.z) - Number(afterPlayer.z),
    );
    if (afterDistance >= beforeDistance - 0.035) stalledSteps += 1;
    else stalledSteps = 0;
    if (stalledSteps >= 2) {
      // A nearby combat body can occupy the greedy axis. Give the other
      // camera-relative axis one sustained real-input attempt before
      // re-planning.
      const alternate = Math.abs(inputX) >= Math.abs(inputY)
        ? (inputY >= 0 ? ["KeyS", "s"] : ["KeyW", "w"])
        : (inputX >= 0 ? ["KeyD", "d"] : ["KeyA", "a"]);
      await holdAxisTowardPoint(cdp, [alternate], waypoint, tolerance, 520);
      stalledSteps = 0;
    }
  }
  return lastState || await telemetry(cdp).catch(() => null);
}

function authoredCemeteryDeparture(points, state) {
  const start = state?.player?.position;
  const destination = points?.at(-1);
  if (state?.zone !== "greyfen" || !start || !destination
    || start.x <= 10 || start.x > 19 || start.z < 4.6 || start.z > 11.8
    || destination.x >= 10) return points;
  // Match the already-proven native west-doorway/gate exit. A straight
  // segment at the actor's current z can run into the cap or grave rows.
  return [points[0], { x: start.x, y: start.y, z: 8.29 },
    { x: 9, y: start.y, z: 8.29 }, { x: 9, y: start.y, z: 10.45 },
    { x: 0, y: start.y, z: 10.45 }, ...points.slice(1)];
}

function authoredGreyfenGateDeparture(points, state) {
  const start = state?.player?.position;
  const destination = points?.at(-1);
  if (state?.zone !== "greyfen" || !start || !destination
    || start.x < -7 || start.x > 12 || start.z < -6 || start.z >= 1.3
    || destination.x > -15 || destination.z > -8) return authoredCemeteryDeparture(points, state);
  // Use the native register/forge departure's central road and west-road turn.
  // A diagonal from Mira's shop cuts through her occupied work area/the well.
  const approach = start.x >= 6
    ? [{ x: start.x, y: start.y, z: -4.3 }, { x: 0, y: start.y, z: -4.3 }]
    : [{ x: 0, y: start.y, z: start.z }];
  return [points[0], ...approach, { x: 0, y: start.y, z: -10 }, destination];
}

function authoredGreyfenInteractionDeparture(points, state) {
  const start = state?.player?.position;
  const destination = points?.at(-1);
  if (state?.zone !== "greyfen" || !start || !destination
    || start.x < 6 || start.x > 14 || start.z <= -4.3 || start.z >= 1.3
    || destination.x >= 6) return authoredCemeteryDeparture(points, state);
  // Match the native forge frontage. The direct westbound segment intersects
  // GreyfenForgeRack's occupied workshop, not the central pedestrian road.
  return [points[0], { x: start.x, y: start.y, z: -4.3 },
    { x: 0, y: start.y, z: -4.3 }, ...points.slice(1)];
}

function collapseCollinearRoute(points) {
  if (!Array.isArray(points) || points.length < 3) return points || [];
  const collapsed = [points[0]];
  for (let index = 1; index < points.length - 1; index += 1) {
    const current = points[index];
    const previous = collapsed[collapsed.length - 1];
    const next = points[index + 1];
    const ax = Number(current.x) - Number(previous.x);
    const az = Number(current.z) - Number(previous.z);
    const bx = Number(next.x) - Number(current.x);
    const bz = Number(next.z) - Number(current.z);
    const cross = ax * bz - az * bx;
    const dot = ax * bx + az * bz;
    if (Math.abs(cross) <= 0.02 && dot >= 0) continue;
    collapsed.push(current);
  }
  collapsed.push(points[points.length - 1]);
  return collapsed;
}

async function moveCameraRelative(cdp, yaw, dx, dz, duration = 180) {
  const forward = dx * -Math.sin(yaw) + dz * -Math.cos(yaw);
  const right = dx * Math.cos(yaw) + dz * -Math.sin(yaw);
  const movementKeys = [["KeyW", "w"], ["KeyA", "a"], ["KeyS", "s"], ["KeyD", "d"]];
  for (const [code, key] of movementKeys) await dispatchMovementKey(cdp, code, key, false);
  const selected = Math.abs(forward) >= Math.abs(right)
    ? (forward > 0 ? ["KeyW", "w"] : ["KeyS", "s"])
    : (right > 0 ? ["KeyD", "d"] : ["KeyA", "a"]);
  await dispatchMovementKey(cdp, selected[0], selected[1], true);
  await sleep(duration);
  await dispatchMovementKey(cdp, selected[0], selected[1], false);
  for (const [code, key] of movementKeys) await dispatchMovementKey(cdp, code, key, false);
}

async function clickAttack(cdp, heavy = false) {
  const button = heavy ? "right" : "left";
  const buttons = heavy ? 2 : 1;
  // Keep combat clicks on the actual Godot canvas. After a dialogue or a
  // long movement hold, Chromium can retain the page target while the
  // renderer surface no longer owns the pointer position; in that state a
  // synthetic button event can be delivered without producing a Godot
  // InputEventMouseButton. This is a real pointer gesture, not a telemetry
  // or gameplay bypass.
  await cdp.send("Page.bringToFront");
  // Startup and UI handoffs already restore canvas focus. Do not enqueue a
  // DOM Runtime call for every combat click while the renderer is submitting.
  // The QA target is always launched with the 1280x720 device-metrics
  // override and the Godot canvas fills that viewport. Do not synthesize a
  // mouse move here: while pointer capture is active Chromium reports that
  // move as camera input, rotating away from the target between the final
  // orientation command and the real attack edge.
  const x = viewport.width * 0.5;
  const y = viewport.height * 0.5;
  let inputError;
  try {
    await cdp.send("Input.dispatchMouseEvent", {
      type: "mousePressed", x, y, button, buttons, clickCount: 1,
    }, INPUT_TIMEOUT_MS);
    // Preserve the attack edge across the game's physics sampling window.
    await sleep(180);
  } catch (error) {
    inputError = error;
  }
  try {
    await cdp.send("Input.dispatchMouseEvent", {
      type: "mouseReleased", x, y, button, buttons: 0, clickCount: 1,
    }, INPUT_TIMEOUT_MS);
  } catch (error) {
    if (!inputError || !String(error?.message || error).includes("timed out")) inputError = error;
  }
  if (inputError) throw inputError;
}

function selectActiveEnemy(state, targetId = "") {
  return (state?.enemies || []).find((enemy) => enemy?.active
    && !enemy.dead
    && Number(enemy.health) > 0.01
    && (!targetId || enemy.id === targetId)
    && enemy.position
    && Number.isFinite(Number(enemy.position.x))
    && Number.isFinite(Number(enemy.position.z)));
}

async function approachMovingEnemy(cdp, meleeDistance, timeout = 5000, targetId = "") {
  // Enemy navigation is allowed to flank and retreat. Re-plan from a fresh
  // observation after every short real-input segment instead of holding toward
  // a position that may already be behind the actor.
  const started = Date.now();
  let lastState = null;
  let stalledSteps = 0;
  let detours = 0;
  while (Date.now() - started < timeout) {
    const state = await combatTelemetry(cdp);
    lastState = state || lastState;
    const player = state?.player?.position;
    const target = selectActiveEnemy(state, targetId);
    if (!player || !target?.position) {
      await sleep(120);
      continue;
    }
    const dx = Number(target.position.x) - Number(player.x);
    const dz = Number(target.position.z) - Number(player.z);
    const distance = Math.hypot(dx, dz);
    if (distance <= meleeDistance) return state;
    // Keep active combat independent of Runtime camera commands. The camera
    // may be aimed anywhere after a real route; movementKeyForCombat converts
    // the observed camera frame into a physical forward/lateral input and the
    // authoritative player controller turns toward that movement.
    const yaw = Number(state.camera?.yaw || 0);
    const selected = movementKeyForCombat(state.player, target, yaw);
    const acceptsMelee = (position, observed) => {
      const current = selectActiveEnemy(observed, targetId);
      return Boolean(current && Math.hypot(
        Number(current.position.x) - Number(position.x),
        Number(current.position.z) - Number(position.z),
      ) <= meleeDistance);
    };
    const progress = await holdAxisTowardPoint(
      cdp,
      [[selected.code, selected.key]],
      {
        x: Number(target.position.x),
        y: Number(target.position.y || 0),
        z: Number(target.position.z),
      },
      meleeDistance,
      clamp((distance / 2.6) * 180 + 440, 440, 780),
      acceptsMelee,
      combatTelemetry,
    );
    lastState = progress || lastState;
    const moved = progress?.player?.position;
    const liveTarget = selectActiveEnemy(progress, targetId);
    if (!moved || !liveTarget?.position) continue;
    const remaining = Math.hypot(liveTarget.position.x - moved.x, liveTarget.position.z - moved.z);
    if (remaining <= meleeDistance) return progress;
    stalledSteps = remaining >= distance - 0.04 ? stalledSteps + 1 : 0;
    if (stalledSteps >= 2) {
      // A headstone/prop can block the direct contact leg. Walk one bounded
      // camera-relative side leg, then re-read the living target and approach.
      const side = detours++ % 2 === 0 ? -1 : 1;
      const currentYaw = Number(progress.camera?.yaw || 0);
      const alongForward = selected.code === "KeyW" || selected.code === "KeyS";
      const key = alongForward ? (side < 0 ? ["KeyA", "a"] : ["KeyD", "d"]) : ["KeyW", "w"];
      const waypoint = alongForward
        ? { x: moved.x + side * Math.cos(currentYaw), z: moved.z - side * Math.sin(currentYaw) }
        : { x: moved.x - Math.sin(currentYaw), z: moved.z - Math.cos(currentYaw) };
      await holdAxisTowardPoint(cdp, [key], waypoint, 0.2, 600, null, combatTelemetry);
      stalledSteps = 0;
    }
  }
  return lastState;
}

async function clickDialogueAction(cdp, actionLabel = "", pageIndex) {
	// Use the existing read-only UI binding, not DOM evaluation or a fixed row.
	// Choices and subtitle scaling change the actual lower-third geometry.
	const selected = await waitFor(() => {
	  const state = cdp.lastObservation;
	  if (!state?.dialogue?.visible || state.dialogue.page !== pageIndex) return null;
	  const label = actionLabel || state.dialogue.actions?.[0];
	  const matches = (state.ui?.buttons || []).filter(button => button.enabled
	    && button.text?.toLowerCase().startsWith(String(label).toLowerCase()));
	  if (matches.length !== 1) return null;
	  return { button: matches[0], viewport: state.ui.viewport,
	    timestamp: Number(state.timestamp_ms), pages: Number(state.dialogue.pages) };
	}, `rendered dialogue button ${actionLabel || "Continue"}`, 5000);
	const button = selected.button;
	const logical = selected.viewport;
	if (!logical?.x || !logical?.y || !button.size?.x || !button.size?.y
	  || button.position.x < 0 || button.position.y < 0
	  || button.position.x + button.size.x > logical.x
	  || button.position.y + button.size.y > logical.y) {
	  throw new Error(`Dialogue button is outside the viewport: ${button.text}`);
	}
	await cdp.send("Page.bringToFront");
	const x = (button.position.x + button.size.x * 0.5) * viewport.width / logical.x;
	const y = (button.position.y + button.size.y * 0.5) * viewport.height / logical.y;
	// Press/release already carry the target coordinates. A stationary hover
	// event adds a separate renderer acknowledgement to every paused UI page.
	let inputError;
	try {
	  await cdp.send("Input.dispatchMouseEvent", {
	    type: "mousePressed", x, y, button: "left", buttons: 1, clickCount: 1,
	  }, INPUT_TIMEOUT_MS);
	  await sleep(70);
	} catch (error) {
	  inputError = error;
	}
	try {
	  await cdp.send("Input.dispatchMouseEvent", {
	    type: "mouseReleased", x, y, button: "left", buttons: 0, clickCount: 1,
	  }, INPUT_TIMEOUT_MS);
	} catch (error) {
	  if (!inputError || !String(error?.message || error).includes("timed out")) inputError = error;
	}
	if (inputError) {
	  if (inputError?.fatal || !String(inputError?.message || inputError).includes("timed out")) throw inputError;
	  // Do not replay an activation whose acknowledgement was lost. Only a
	  // newer game-published frame proving this page's outcome can accept it.
	  await waitFor(() => {
	    const state = cdp.lastObservation;
	    const dialogue = state?.dialogue;
	    return Number(state?.timestamp_ms) > selected.timestamp
	      && Number(dialogue?.pages) === selected.pages
	      && ((dialogue.visible && Number(dialogue.page) > pageIndex)
	        || (!dialogue.visible && pageIndex === selected.pages - 1
	          && Number(dialogue.page) === pageIndex));
	  }, `delivered dialogue click ${button.text}`, 5000);
	}
	return button.text;
}

async function advanceDialogueInput(cdp, pageIndex) {
  if (dialogueInput === "keyboard") return acceptDialogue(cdp);
  return clickDialogueAction(cdp, "", pageIndex);
}

async function chooseDialogueAction(cdp, actionLabel, pageIndex) {
  if (dialogueInput === "mouse") return clickDialogueAction(cdp, actionLabel, pageIndex);
  const initial = await freshDialogueState(cdp);
  if (initial?.visible && initial.page === pageIndex && initial.focused_action < 0) {
    await tapKey(cdp, "ArrowDown", "ArrowDown", 70);
  }
  const selected = await waitFor(async () => {
    const dialogue = await freshDialogueState(cdp).catch(() => null);
    if (!dialogue?.visible || dialogue.page !== pageIndex || dialogue.focused_action < 0) return null;
    const matches = dialogue.actions.map((label, index) =>
      label.toLowerCase().startsWith(actionLabel.toLowerCase()) ? index : -1
    ).filter((index) => index >= 0);
    if (matches.length !== 1) throw new Error(`Dialogue action ${actionLabel} is absent or ambiguous: ${dialogue.actions.join(" | ")}`);
    return { dialogue, target: matches[0] };
  }, `dialogue action ${actionLabel}`, 5000);
  let current = selected.dialogue.focused_action;
  const target = selected.target;
  const count = selected.dialogue.actions.length;
  for (let step = 0; current !== target && step < count; step += 1) {
    const down = (target - current + count) % count <= (current - target + count) % count;
    await tapKey(cdp, down ? "ArrowDown" : "ArrowUp", down ? "ArrowDown" : "ArrowUp", 70);
    const focused = await waitFor(async () => {
      const dialogue = await freshDialogueState(cdp).catch(() => null);
      return dialogue?.visible && dialogue.page === pageIndex && dialogue.focused_action !== current ? dialogue : null;
    }, `dialogue focus ${actionLabel}`, 3000);
    current = focused.focused_action;
  }
  if (current !== target) throw new Error(`Dialogue focus did not reach ${actionLabel}`);
  await acceptDialogue(cdp);
  return selected.dialogue.actions[target];
}

async function telemetry(cdp) {
  const observed = await cdp.waitForObservation();
  if (observed) return observed;
  try {
    const response = await cdp.sendObservation("Runtime.evaluate", {
      expression: productionObserver ? "window.__ashenOathReadOnlyObservation || null" : "window.__ASHEN_OATH_QA__ || null",
      returnByValue: true,
      awaitPromise: false,
    }, TELEMETRY_TIMEOUT_MS);
    if (response.exceptionDetails) throw new Error(response.exceptionDetails.text);
    const current = response.result.value;
    // A successful direct read is newer than the coalesced binding sample.
    // Promote it so a later binding gap cannot fall back to an older waypoint
    // and make the route steer from stale player coordinates.
    if (current && typeof current === "object") {
      cdp.lastObservation = current;
      cdp.zonePerformance.observe(current);
    }
    return current;
  } catch (error) {
    // Retained state is diagnostic evidence, not a new movement observation.
    // Callers may retry a missing sample, but must not steer from stale state.
    throw error;
  }
}

async function freshTelemetry(cdp) {
  // Discard pre-input samples and await a new game-published observation.
  // Repeated Runtime evaluation can starve during first-visible rendering,
  // even while this existing binding is publishing genuine control state.
  cdp.observationQueue.length = 0;
  if (productionObserver) {
    const publicationTimeout = functionalCandidate ? CDP_EVALUATE_TIMEOUT_MS : TELEMETRY_TIMEOUT_MS;
    const published = await cdp.waitForObservation(publicationTimeout);
    if (published) return published;
  }
  let response;
  try {
    response = await cdp.sendObservation("Runtime.evaluate", {
      expression: productionObserver ? "window.__ashenOathReadOnlyObservation || null" : "window.__ASHEN_OATH_QA__ || null",
      returnByValue: true,
      awaitPromise: false,
    }, TELEMETRY_TIMEOUT_MS);
  } catch (error) {
    // A binding received during the bounded fallback is still a new real
    // observation. Never substitute lastObservation when both channels fail.
    const published = productionObserver ? cdp.takeObservation() : null;
    if (published) return published;
    throw error;
  }
  if (response.exceptionDetails) throw new Error(response.exceptionDetails.text);
  const current = response.result.value;
  if (current && typeof current === "object") {
    cdp.lastObservation = current;
    cdp.zonePerformance.observe(current);
  }
  return current;
}

async function freshCombatState(cdp) {
  // Active combat can make a complete snapshot compete with the renderer for
  // the Runtime domain. The combat driver only needs the already-published
  // player, camera, and enemy fields, so keep this convergence read bounded.
  const response = await cdp.sendObservation("Runtime.evaluate", {
    expression: `(() => {
      const state = ${productionObserver ? "window.__ashenOathReadOnlyObservation" : "window.__ASHEN_OATH_QA__"} || null;
      return state ? {
        player: state.player || null,
        camera: state.camera || null,
        enemies: Array.isArray(state.enemies) ? state.enemies : [],
        quests: state.quests ? {
          fight_complete: Boolean(state.quests.fight_complete),
          objectives_done: state.quests.objectives_done || {},
        } : null,
        story: state.story ? { flags: state.story.flags || {} } : null,
        inventory: state.inventory ? { items: state.inventory.items || {} } : null,
      } : null;
    })()`,
    returnByValue: true,
    awaitPromise: false,
  }, TELEMETRY_TIMEOUT_MS);
  if (response.exceptionDetails) throw new Error(response.exceptionDetails.text);
  return response.result.value;
}

async function combatTelemetry(cdp) {
  // Active combat only needs the compact player/camera/enemy state. Prefer the
  // existing observation binding and fall back to the bounded compact read;
  // never fall back to the full world snapshot while an enemy is live.
  const observed = await cdp.waitForObservation().catch(() => null);
  if (observed) return observed;
  return freshCombatState(cdp).catch(() => null);
}

async function freshDialogueState(cdp) {
  // Dialogue pauses the scene tree. Read only the small UI state needed for
  // the open/close edge so a full world snapshot cannot delay a valid button
  // transition on the Compatibility renderer. Prefer an already-published
  // paused snapshot when the direct Runtime domain is briefly unavailable;
  // the observation is read-only and uses the same dialogue fields.
  const compactDialogue = (snapshot) => {
    const dialogue = snapshot?.dialogue || null;
    return dialogue ? {
      visible: Boolean(dialogue.visible),
      page: Number(dialogue.page ?? -1),
      pages: Number(dialogue.pages ?? 0),
      actions: Array.isArray(dialogue.actions) ? dialogue.actions.map(String) : [],
      focused_action: Number(dialogue.focused_action ?? -1),
    } : null;
  };
  const queuedBefore = compactDialogue(cdp.takeObservation());
  if (queuedBefore?.visible) return queuedBefore;
  // The paused dialogue surface can publish its next binding snapshot on a
  // different schedule from the compact Runtime read. Observe both paths in
  // one bounded window, then prefer a visible result over a stale hidden one.
  const observedPromise = cdp.waitForObservation(OBSERVATION_WAIT_MS).catch(() => null);
  const directPromise = (async () => {
    try {
      const response = await cdp.sendObservation("Runtime.evaluate", {
        expression: `(() => {
          const state = ${productionObserver ? "window.__ashenOathReadOnlyObservation" : "window.__ASHEN_OATH_QA__"} || null;
          const dialogue = state?.dialogue || null;
          return dialogue ? {
            dialogue: {
              visible: Boolean(dialogue.visible),
              page: Number(dialogue.page ?? -1),
              pages: Number(dialogue.pages ?? 0),
              actions: Array.isArray(dialogue.actions) ? dialogue.actions.map(String) : [],
              focused_action: Number(dialogue.focused_action ?? -1),
            },
          } : null;
        })()`,
        returnByValue: true,
        awaitPromise: false,
      }, Math.min(OBSERVATION_WAIT_MS, TELEMETRY_TIMEOUT_MS));
      if (response.exceptionDetails) throw new Error(response.exceptionDetails.text);
      return response.result.value;
    } catch {
      // The next published paused snapshot is still a valid read-only answer.
      return null;
    }
  })();
  const [observed, direct] = await Promise.all([observedPromise, directPromise]);
  const observedDialogue = compactDialogue(observed);
  const directDialogue = compactDialogue(direct);
  if (directDialogue?.visible) return directDialogue;
  if (observedDialogue?.visible) return observedDialogue;
  const queuedAfter = compactDialogue(cdp.takeObservation());
  if (queuedAfter?.visible) return queuedAfter;
  return directDialogue || observedDialogue || queuedAfter || null;
}

async function qaCommand(cdp, action, values = {}) {
  if (productionObserver) throw fatal(`QA mutation command ${action} is forbidden in production observation mode`);
  const request_id = ++commandSequence;
  // Command writes must not wait behind a prior queued Runtime.evaluate.
  // Observation reads already use the immediate CDP path; keeping the
  // assignment there prevents a renderer-side stall from hiding a command
  // while direct telemetry remains available.
  try {
    const response = await cdp.sendObservation("Runtime.evaluate", {
      expression: `window.__ASHEN_OATH_QA_COMMAND__ = ${JSON.stringify({ action, request_id, ...values })}`,
      returnByValue: true,
      awaitPromise: false,
    }, CDP_EVALUATE_TIMEOUT_MS);
    if (response.exceptionDetails) throw new Error(response.exceptionDetails.text);
  } catch (error) {
    // The assignment is sent before CDP's reply timer starts. Compatibility
    // can therefore acknowledge the command in the existing game snapshot
    // even when the Runtime.evaluate reply is late during a renderer handoff.
    // Keep waiting for this exact request id instead of resending an action or
    // turning a successfully applied command into a false route failure.
    if (!String(error?.message || error).includes("CDP Runtime.evaluate timed out")) {
      throw error;
    }
  }
  return waitFor(async () => {
    // Command acknowledgements must use an authoritative current read. The
    // periodic binding is intentionally coalesced for route polling, so it
    // can leave an older sample in front of a command result that the game has
    // already written to window.__ASHEN_OATH_QA__. Waiting on that queue made
    // a completed route_to appear to time out in v150.
    // During a Compatibility renderer handoff the direct Runtime read can
    // arrive after the command has already published its acknowledgement.
    // Check all three existing read-only snapshots without widening the
    // request-id predicate or resending the command.
    const direct = await freshTelemetry(cdp).catch(() => null);
    const queued = cdp.takeObservation();
    for (const state of [direct, queued, cdp.lastObservation]) {
      const result = state?.command_result;
      if (result?.action === action && result?.request_id === request_id
        && (values.target === undefined || result.target === values.target)) {
        return result;
      }
    }
    return null;
  }, `QA command ${action}${values.target ? `:${values.target}` : ""}`, 10000);
}

async function routeToCatalogEntry(cdp, entry) {
  if (!productionObserver) return qaCommand(cdp, "route_to", entry.position);
  const requestId = ++commandSequence;
  const targetId = String(entry.id || "");
  if (!targetId) throw new Error("Read-only route target has no catalog ID");
  try {
    const response = await cdp.sendObservation("Runtime.evaluate", {
      expression: `window.__ashenOathReadOnlyRouteResult = null; window.__ashenOathReadOnlyRouteQuery = ${JSON.stringify({ request_id: requestId, target_id: targetId })}`,
      returnByValue: true,
      awaitPromise: false,
    }, TELEMETRY_TIMEOUT_MS);
    if (response.exceptionDetails) throw new Error(response.exceptionDetails.text);
  } catch (error) {
    // A delayed CDP acknowledgment does not prove the query was lost. Never
    // resend it: require the exact read-only result within the existing budget.
    if (!String(error?.message || error).includes("CDP Runtime.evaluate timed out")) throw error;
  }
  return waitFor(async () => {
    if (cdp.routeBindingEnabled) {
      const result = cdp.lastRouteResult;
      return result?.read_only && result.request_id === requestId && result.target_id === targetId ? result : null;
    }
    const read = await cdp.sendObservation("Runtime.evaluate", {
      expression: "window.__ashenOathReadOnlyRouteResult || null",
      returnByValue: true,
      awaitPromise: false,
    }, TELEMETRY_TIMEOUT_MS);
    if (read.exceptionDetails) throw new Error(read.exceptionDetails.text);
    const result = read.result.value;
    return result?.read_only && result.request_id === requestId && result.target_id === targetId ? result : null;
  }, `read-only route to ${targetId}`, 5000);
}

function fatal(message) {
  const error = new Error(message);
  error.fatal = true;
  return error;
}

function findGate(state, target) {
  return state?.gates?.find((gate) => gate.target === target);
}

const SEAMLESS_EXTERIOR_ROUTES = new Set([
  "greyfen>wychwood", "wychwood>greyfen",
  "greyfen>deep_wood", "deep_wood>wychwood", "wychwood>deep_wood",
  "deep_wood>old_mill", "old_mill>deep_wood",
  "old_mill>burned_farmstead", "burned_farmstead>old_mill",
  "burned_farmstead>marsh_crossing", "marsh_crossing>burned_farmstead",
  "marsh_crossing>bandit_road", "bandit_road>marsh_crossing",
  "bandit_road>vargan_approach", "vargan_approach>bandit_road",
  "vargan_approach>greyfen",
]);

function isSeamlessExteriorRoute(source, target) {
  return SEAMLESS_EXTERIOR_ROUTES.has(`${source}>${target}`);
}

function findInteraction(state, id) {
  return state?.interactions?.find((interaction) => interaction.id === id);
}

async function capture(cdp, path) {
  const screenshot = await cdp.send("Page.captureScreenshot", { format: "png", fromSurface: true });
  if (!screenshot.data || screenshot.data.length < 4096) return "";
  mkdirSync(resolve(path, ".."), { recursive: true });
  writeFileSync(path, Buffer.from(screenshot.data, "base64"));
  return path;
}

function networkTimeline(cdp) {
  const requests = new Map();
  for (const event of cdp.events) {
    const p = event.params || {};
    if (!event.method.startsWith("Network.") || !p.requestId) continue;
    let row = requests.get(p.requestId);
    if (!row) {
      row = { request_id: p.requestId, received_bytes: 0 };
      requests.set(p.requestId, row);
    }
    if (event.method === "Network.requestWillBeSent") {
      row.url = p.request?.url;
      row.started = p.timestamp;
    } else if (event.method === "Network.responseReceived") {
      row.url = p.response?.url || row.url;
      row.status = p.response?.status;
      row.response_at = p.timestamp;
      row.from_cache = Boolean(p.response?.fromDiskCache || p.response?.fromServiceWorker);
    } else if (event.method === "Network.dataReceived") {
      row.received_bytes += p.dataLength || 0;
    } else if (event.method === "Network.loadingFinished") {
      row.finished = p.timestamp;
      row.encoded_bytes = p.encodedDataLength;
    } else if (event.method === "Network.loadingFailed") {
      row.failed_at = p.timestamp;
      row.error = p.errorText;
    }
  }
  return [...requests.values()].filter(row => row.url).slice(-100);
}

async function clickPoint(cdp, point) {
  await cdp.send("Input.dispatchMouseEvent", {
    type: "mouseMoved", x: point.x, y: point.y, button: "none",
  }, INPUT_TIMEOUT_MS);
  await cdp.send("Input.dispatchMouseEvent", {
    type: "mousePressed", x: point.x, y: point.y, button: "left", clickCount: 1,
  }, INPUT_TIMEOUT_MS);
  await sleep(70);
  await cdp.send("Input.dispatchMouseEvent", {
    type: "mouseReleased", x: point.x, y: point.y, button: "left", clickCount: 1,
  }, INPUT_TIMEOUT_MS);
}

async function waitForNewGameReady(cdp, timeout = functionalCandidate ? 45000 : startupObservationMs) {
  return waitFor(async () => {
    const state = await telemetry(cdp);
    return state?.ready && state.zone === "greyfen" && !state.transition_pending ? state : null;
  }, "New Game Greyfen telemetry", timeout);
}

async function waitForLoadingLine(cdp, text, timeout = 45000) {
  return waitFor(
    () => loadingTimeline(cdp).some((entry) => entry.text.includes(text)),
    text,
    timeout,
  );
}

async function activateNewGame(cdp, point) {
  // Mouse startup acceptance must never be rescued by a keyboard activation.
  // Preserve the original readiness/transport error for root-cause analysis.
  await clickPoint(cdp, point);
  return waitForNewGameReady(cdp);
}

async function activateBootShell(cdp) {
  if (await cdp.evaluate("Boolean(window.__ashenOathBoot?.engine_start_ms)")) return;
  const point = await waitFor(async () => cdp.evaluate(`(() => {
    const button = document.getElementById("start");
    if (!button || button.disabled) return null;
    const rect = button.getBoundingClientRect();
    return rect.width > 0 && rect.height > 0
      ? { x: Math.round(rect.left + rect.width / 2), y: Math.round(rect.top + rect.height / 2) }
      : null;
  })()`), "boot shell start button", 10000);
  await clickPoint(cdp, point);
}

async function startNewGame(cdp, expectedUrl, onStartupReady = async () => {}) {
  cdp.startupTimings = { navigation_started_ms: Date.now(), diagnostic_only: startupDiagnostic };
  await cdp.send("Page.bringToFront");
  await cdp.send("Page.navigate", { url: expectedUrl });
  await waitFor(async () => cdp.evaluate(
    `location.href.startsWith(${JSON.stringify(expectedUrl.split("?")[0])}) && document.readyState === "complete"`
  ), "QA page load");
  // Current shells start the engine automatically; their start button flaps
  // the optional crow game. Only legacy manual-launch shells need this click.
  const hasBootStart = await cdp.evaluate(`Boolean(document.getElementById("start"))
    && !window.__ashenOathBoot?.engine_start_ms`);
  if (hasBootStart) await activateBootShell(cdp);
  await waitFor(async () => cdp.evaluate(`(() => {
    const canvas = document.querySelector("canvas");
    if (!canvas) return false;
    const gl = canvas.getContext("webgl2") || canvas.getContext("webgl");
    return Boolean(gl) && canvas.width >= 1280 && canvas.height >= 720;
  })()`), "QA WebGL canvas");
  await cdp.send("Page.bringToFront");
    // Focus emulation is optional in headless Chromium; pointer and keyboard
    // dispatch remain the strict gameplay-input assertions.
    await cdp.send("Emulation.setFocusEmulationEnabled", { enabled: true }).catch(() => {});
  await cdp.evaluate(`(() => {
    window.focus();
    const canvas = document.querySelector("canvas");
    if (canvas) { canvas.tabIndex = 0; canvas.focus(); }
  })()`);
  // The Web build prewarms Greyfen behind the visible menu automatically.
  // Waiting for the ready marker before activating the control prevents the
  // first click from landing on the disabled Preparing Greyfen button.
  const newGamePoint = { x: Math.round(viewport.width * 0.736), y: Math.round(viewport.height * 0.177) };
  // Cold QA exports may spend several seconds compiling the Compatibility
  // renderer while the prewarm signal is already progressing. Keep this a
  // bounded readiness gate, but do not turn normal first-run compilation into
  // a false browser failure.
	await waitForLoadingLine(cdp, "LOADING: shell opening_ready", 45000);
	// The periodic observation binding is intentionally coalesced and may still
	// contain the final pre-ready sample. Read the current state directly after
	// the shell marker so readiness ordering is tested without queue latency.
	await waitFor(async () => {
		const preparedState = await freshTelemetry(cdp);
		return Boolean(preparedState?.new_game_ready);
	}, "New Game state after shell readiness", 5000);
  await sleep(420);
  cdp.startupTimings.click_started_ms = Date.now();
  await activateNewGame(cdp, newGamePoint);
  cdp.startupTimings.control_observed_ms = Date.now();
  cdp.startupTimings.click_to_control_ms = cdp.startupTimings.control_observed_ms - cdp.startupTimings.click_started_ms;
  cdp.startupTimings.navigation_to_control_ms = cdp.startupTimings.control_observed_ms - cdp.startupTimings.navigation_started_ms;
  cdp.startupRuns ||= [];
  cdp.startupRuns.push({ ...cdp.startupTimings });
  await refocusGameplay(cdp);
  const state = await waitForNewGameReady(cdp, 10000);
  const errors = consoleErrors(cdp);
  if (errors.length) throw fatal(`startup console error: ${errors[0]}`);
  await onStartupReady();
  // Arrival is timed at first control above. Complete campaign interaction
  // starts after the existing opening assembly finishes; its cold stalls are
  // retained in the frame/startup evidence, not mistaken for a lost E edge.
  if (productionObserver) {
    await waitForLoadingLine(cdp, "LOADING: Greyfen deferred_detail complete", functionalCandidate ? 120000 : 45000);
    cdp.startupTimings.opening_detail_ready_ms = Date.now();
  }
  return state;
}

async function driveToGate(cdp, target, checkpoints, timeout = 45000) {
  const started = Date.now();
  let routeTimeout = timeout;
  let lastState;
  let route = [];
  let routeIndex = 0;
  let lastWaypoint = null;
  let lastProgressAt = Date.now();
  let lastDistance = Number.POSITIVE_INFINITY;
  let seamless = false;
  let sourceZone = "";
  while (Date.now() - started < routeTimeout) {
    const state = await telemetry(cdp);
    lastState = state;
    const failedPack = Object.entries(state?.runtime_packs || {}).find(([, pack]) => pack.state === "failed");
    if (failedPack) throw fatal(`Runtime pack ${failedPack[0]} failed: ${failedPack[1].error}`);
    if (!state?.ready || state.transition_pending || state.paused) {
      await sleep(150);
      continue;
    }
    if (!sourceZone) sourceZone = state.zone;
    if (state.zone === target && seamless) {
      checkpoints.push({
        event: "seamless_boundary_crossed",
        from: sourceZone,
        zone: target,
        elapsed_ms: Date.now() - started,
        player: state.player.position,
      });
      return state;
    }
    if (!seamless && state.zone !== target && state.zone) {
      seamless = isSeamlessExteriorRoute(state.zone, target);
      if (seamless) {
        // SwiftShader/Compatibility browser runs can deliver a physical key
        // heartbeat far slower than wall-clock time. Keep the player-driven
        // route alive long enough to finish a genuine exterior crossing while
        // retaining the normal timeout for ordinary interactable gates.
        routeTimeout = Math.max(routeTimeout, 180000);
      }
    }
    const gate = findGate(state, target);
    if (!gate) throw new Error(`No ${target} gate exposed in ${state.zone}`);
    if (!seamless && state.focus?.target === target && gate.distance <= 3.2) {
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
    }
    if (!route.length) {
      const routeResult = await routeToCatalogEntry(cdp, gate);
      const fullRoute = routeResult.points || [];
      if (!fullRoute.length) throw new Error(`No navigation route to ${target} in ${state.zone}`);
      route = collapseCollinearRoute(authoredGreyfenGateDeparture(fullRoute, state));
      routeIndex = route.length > 1 ? 1 : 0;
      checkpoints.push({
        event: "gate_route",
        zone: state.zone,
        target,
        points: fullRoute,
        movement_points: route,
      });
    }
    const player = state.player.position;
    let waypoint = route[Math.min(routeIndex, route.length - 1)] || gate.position;
    lastWaypoint = { index: routeIndex, point: waypoint };
    const previous = route[Math.max(0, routeIndex - 1)] || player;
    const passedWaypoint = routeIndex > 0
      && ((player.x - waypoint.x) * (waypoint.x - previous.x) + (player.z - waypoint.z) * (waypoint.z - previous.z)) >= 0;
    if ((Math.hypot(waypoint.x - player.x, waypoint.z - player.z) < 0.75 || passedWaypoint) && routeIndex < route.length - 1) {
      routeIndex += 1;
      waypoint = route[routeIndex];
    }
    const dx = waypoint.x - player.x;
    const dz = waypoint.z - player.z;
    const distance = Math.hypot(dx, dz);
    if (distance > 0.42) {
      // Keyboard diagonals are normalized to equal strength by InputRouter.
      // Align the camera to the route segment first so a straight waypoint
      // resolves to one forward key instead of an unequal world-space drift
      // into a bank slab or scenery collider.
      const desiredYaw = Math.atan2(-dx, -dz);
      await turnCameraToward(cdp, desiredYaw, state.camera?.yaw);
    }
    // Keep route traversal player-driven. holdTowardPoint converts the desired
    // world direction to the observed camera frame, so a QA-only camera
    // mutation is unnecessary and can stall a Web/WASM command queue after a
    // dialogue or pointer-lock handoff.
    if (seamless && routeIndex >= route.length - 1 && distance <= 1.0) {
      // Exterior links are boundary transitions, not interactable doors. Stay
      // on the validated bridge/road route until its final threshold point;
      // only then continue outward through the authored boundary. Steering at
      // the first near-waypoint used to cut diagonally across Greyfen's river.
       // Derive the outward direction from the authored route's final segment,
       // not from the player. A slow frame can place the player just beyond the
       // gate, which would otherwise reverse the target back into the source
       // zone and make a valid boundary crossing impossible.
       const routePrevious = route[Math.max(route.length - 2, 0)] || player;
       const gateDx = Number(gate.position.x) - Number(routePrevious.x);
       const gateDz = Number(gate.position.z) - Number(routePrevious.z);
      const outwardLength = Math.hypot(gateDx, gateDz);
      const outward = outwardLength > 0.001
        ? { x: gateDx / outwardLength, z: gateDz / outwardLength }
        : { x: 0, z: -1 };
      const boundaryPoint = {
        x: Number(gate.position.x) + outward.x * 3.0,
        y: Number(gate.position.y || 0),
        z: Number(gate.position.z) + outward.z * 3.0,
      };
      const progress = await holdTowardPoint(cdp, boundaryPoint, 12000, target);
      lastState = progress || lastState;
      if (progress?.zone === target) {
        checkpoints.push({
          event: "seamless_boundary_crossed",
          from: sourceZone,
          zone: target,
          elapsed_ms: Date.now() - started,
          player: progress.player?.position || null,
        });
        return progress;
      }
    } else if (distance > 0.42) {
      // Compatibility WebGL can defer input delivery while a frame is being
      // presented. Release from an observed waypoint arrival so the route
      // cannot crawl from short fixed pulses or overshoot into scenery.
      const movementTimeout = seamless
        ? clamp((distance / 2.6) * 1000 + 28000, 30000, 60000)
        : clamp((distance / 2.6) * 1000 + 9000, 14000, 30000);
      const progress = await holdTowardPoint(cdp, waypoint, movementTimeout, seamless ? target : "");
      lastState = progress || lastState;
      if (!progress?.player?.position) throw new Error(`No player telemetry while approaching ${target}`);
      // A seamless hold can return the first valid target-zone sample while a
      // subsequent queue read still contains an older source-zone frame. Keep
      // that observed crossing instead of steering again from stale telemetry.
      if (seamless
        && progress.zone === target
        && progress.ready
        && !progress.transition_pending
        && progress.player?.can_control) {
        checkpoints.push({
          event: "seamless_boundary_crossed",
          from: sourceZone,
          zone: target,
          elapsed_ms: Date.now() - started,
          player: progress.player.position,
        });
        return progress;
      }
      const settledProgress = await telemetry(cdp).catch(() => null);
      const gateState = settledProgress?.player?.position ? settledProgress : progress;
      lastState = gateState;
      // The movement helper can consume the remaining route budget while its
      // final sample already contains a valid gate focus. Accept that sample
      // immediately instead of waiting for a loop iteration that can no
      // longer run after the outer timeout expires.
      if (!seamless
        && gateState.focus?.type === "zone"
        && gateState.focus?.target === target
        && Number(gateState.focus?.distance) <= 3.2) {
          checkpoints.push({
            event: "gate_focus",
            zone: gateState.zone,
            target,
            elapsed_ms: Date.now() - started,
            player: gateState.player.position,
            distance: Number(gateState.focus.distance),
          });
          return gateState;
      }
      if (traceMovement && progress._movement_trace?.length) {
        checkpoints.push({
          event: "gate_movement_trace",
          zone: state.zone,
          target,
          route_index: routeIndex,
          waypoint,
          samples: progress._movement_trace,
        });
      }
    } else {
      await sleep(180);
    }
  }
  throw new Error(`Could not focus ${target} gate; waypoint=${JSON.stringify(lastWaypoint)} route=${JSON.stringify(route)} last telemetry=${JSON.stringify(lastState)}`);
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
  await clickAttack(cdp, false);
  await sleep(180);
  return arrival;
}

async function traverse(cdp, target, checkpoints) {
  const state = await driveToGate(cdp, target, checkpoints);
  if (state?.zone === target) return state;
  return useGate(cdp, target, checkpoints);
}

async function driveToInteraction(cdp, id, checkpoints, timeout = 240000) {
  const started = Date.now();
  let route = [];
  let routeIndex = 0;
  let interactionMissingSince = 0;
  let repositionedGroundProp = false;
  while (Date.now() - started < timeout) {
    const state = await telemetry(cdp);
    if (!state?.ready || state.transition_pending || state.paused) {
      await sleep(120);
      continue;
    }
    if (state.player && !state.player.can_control) throw new Error(`Player lost control while routing to ${id}`);
    let interaction = findInteraction(state, id);
    if (!interaction) {
      // Deferred opening detail can rebuild the small telemetry catalog between
      // two otherwise valid snapshots. Keep the player-driven route alive for
      // one direct read before treating that transient catalog gap as a
      // missing gameplay interaction. The periodic binding is coalesced and
      // can omit a catalog frame even though the authoritative window state
      // already contains the actor, as v152 showed for sister_anwen.
      const refreshed = await freshTelemetry(cdp).catch(() => null);
      const refreshedInteraction = findInteraction(refreshed, id);
      if (refreshedInteraction) {
        interaction = refreshedInteraction;
      } else {
        if (interactionMissingSince === 0) interactionMissingSince = Date.now();
        if (Date.now() - interactionMissingSince >= INTERACTION_CATALOG_GRACE_MS) {
          throw new Error(`No ${id} interaction exposed in ${state.zone}`);
        }
        await sleep(160);
        continue;
      }
    }
    interactionMissingSince = 0;
    // The game focus resolver has already applied interaction range, line of
    // sight, and quest priority. Do not duplicate a stale distance threshold
    // here; doing so rejected a valid speaker focus at natural camera distance.
    const approach = route[route.length - 1];
    const requiresSpeakerApproach = interaction.type === "dialogue" && id !== "crow_shrine_choice";
    const atConversationApproach = !requiresSpeakerApproach || Boolean(approach
      && Math.hypot(approach.x - state.player.position.x, approach.z - state.player.position.z) <= 0.72);
    if (state.focus?.id === id && atConversationApproach) {
      checkpoints.push({ event: "interaction_focus", id, zone: state.zone, distance: interaction.distance });
      return state;
    }
    if (!route.length) {
      const routeResult = await routeToCatalogEntry(cdp, interaction);
      route = authoredGreyfenInteractionDeparture(routeResult.points || [], state);
      if (!route.length) throw new Error(`No navigation route to ${id} in ${state.zone}`);
      routeIndex = route.length > 1 ? 1 : 0;
      checkpoints.push({ event: "interaction_route", id, zone: state.zone, points: route });
    }
    const player = state.player.position;
    let waypoint = route[Math.min(routeIndex, route.length - 1)] || interaction.position;
    // Sparse observations can span multiple waypoints. Consume all reached
    // points before steering, otherwise a completed leg causes backtracking.
    while (routeIndex < route.length - 1) {
      const previous = route[Math.max(0, routeIndex - 1)] || player;
      const passedWaypoint = routeIndex > 0
        && ((player.x - waypoint.x) * (waypoint.x - previous.x) + (player.z - waypoint.z) * (waypoint.z - previous.z)) >= 0;
      if (Math.hypot(waypoint.x - player.x, waypoint.z - player.z) >= 0.72 && !passedWaypoint) break;
      routeIndex += 1;
      waypoint = route[routeIndex];
    }
    const dx = waypoint.x - player.x;
    const dz = waypoint.z - player.z;
    const distance = Math.hypot(dx, dz);
    if (!repositionedGroundProp && routeIndex === route.length - 1 && distance <= 0.38
      && ["clue", "herb"].includes(interaction.type) && state.focus?.position
      && state.focus.id !== id) {
      // Standing on a ground prop can leave a nearby herb in the stronger
      // view cone. Walk to its other side rather than overriding game focus.
      const awayX = interaction.position.x - state.focus.position.x;
      const awayZ = interaction.position.z - state.focus.position.z;
      const separation = Math.hypot(awayX, awayZ);
      if (separation > 0.1) {
        repositionedGroundProp = true;
        const standingPoint = { x: interaction.position.x + awayX / separation * 2.2,
          y: player.y, z: interaction.position.z + awayZ / separation * 2.2 };
        route[route.length - 1] = standingPoint;
        const moved = await approachPointWithReplan(cdp, standingPoint, 5000, 0.20);
        if (!moved?.player?.position || moved.player.dead || !moved.player.can_control) {
          throw new Error(`Ground-prop approach failed for ${id}`);
        }
        await turnCameraToward(cdp, Math.atan2(moved.player.position.x - interaction.position.x,
          moved.player.position.z - interaction.position.z), moved.camera?.yaw);
        checkpoints.push({ event: "interaction_physical_standing_adjustment", id,
          competing_focus: state.focus.id, player: moved.player.position });
        continue;
      }
    }
    const lookPoint = routeIndex === route.length - 1 && distance <= 0.38
      ? interaction.position : waypoint;
    const desiredYaw = Math.atan2(player.x - lookPoint.x, player.z - lookPoint.z);
    const cameraYaw = await turnCameraToward(cdp, desiredYaw, state.camera?.yaw);
    if (distance > 0.38) {
      // Keep interaction legs on the continuous held-input contract that has
      // already crossed the bridge in native and browser evidence. The route
      // yaw is passed explicitly so a stale coalesced camera sample cannot
      // choose the opposite digital axis after a waypoint turn.
      const progress = await holdTowardPoint(
        cdp,
        waypoint,
        clamp((distance / 2.6) * 1000 + 4000, 5000, 12000),
        "",
        null,
        cameraYaw,
      );
      if (!progress?.player?.position) throw new Error(`No player telemetry while approaching ${id}`);
      // Releasing a held key can invalidate the cached focus until the next
      // sparse Compatibility frame. Give the game one bounded refresh window
      // before the outer route deadline is evaluated; this observes ordinary
      // focus state and never bypasses the interaction path.
      const settledFocus = await waitFor(async () => {
        const settled = await telemetry(cdp).catch(() => null);
        const finalApproach = route[route.length - 1];
        const conversationSettled = !requiresSpeakerApproach || Boolean(finalApproach
          && settled?.player?.position && Math.hypot(finalApproach.x - settled.player.position.x,
            finalApproach.z - settled.player.position.z) <= 0.72);
        return settled?.focus?.id === id && conversationSettled ? settled : null;
      }, `${id} focus settle`, 420).catch(() => null);
      if (settledFocus != null) {
        checkpoints.push({
          event: "interaction_focus",
          id,
          zone: settledFocus.zone,
          distance: Number(settledFocus.focus?.distance ?? 0),
          settled_after_movement: true,
        });
        return settledFocus;
      }
      if (traceMovement && progress?._movement_trace?.length) {
        checkpoints.push({
          event: "movement_trace",
          id,
          waypoint,
          samples: progress._movement_trace,
        });
      }
    }
    else await sleep(120);
  }
  throw new Error(`Could not focus interaction ${id}`);
}

async function useInteraction(cdp, id, checkpoints, expectsDialogue = false, actionLabel = "", restoreGameplayPointer = true, interactionKey = ["KeyE", "e"]) {
  const focused = await driveToInteraction(cdp, id, checkpoints);
  const target = findInteraction(focused, id);
  const player = focused?.player?.position;
  if (target?.position && player) {
    await turnCameraToward(cdp, Math.atan2(player.x - target.position.x,
      player.z - target.position.z), focused.camera?.yaw);
  }
  if (interactionKey[0] !== "KeyE") await focusGameCanvas(cdp);
  await tapGameplayKey(cdp, interactionKey[0], interactionKey[1], 80);
  await sleep(220);
    if (expectsDialogue) {
      // On sparse Compatibility frames the real E action can be applied after
      // the fixed post-key delay. Wait for the ordinary dialogue surface to
      // appear before deciding that activation did not happen; otherwise the
      // route can mark the interaction complete and start travelling while
      // the newly opened dialogue is still paused on screen.
      const openedDialogue = await waitFor(async () => {
        // Dialogue pauses the scene tree and can leave a pre-click observation
        // at the head of the coalesced queue. Read the authoritative window
        // snapshot so the real E edge is judged against the current UI state.
        const opened = await freshDialogueState(cdp).catch(() => null);
        return opened?.visible ? { dialogue: opened } : null;
      }, `${id} dialogue open`, 5000);
      const dialoguePages = Math.max(1, Number(openedDialogue?.dialogue?.pages || 1));
      const firstDialoguePage = Math.max(0, Number(openedDialogue?.dialogue?.page || 0));
      checkpoints.push({ event: "dialogue_input_mode", id, mode: dialogueInput });
      // The page count is captured before the paused UI starts receiving
      // clicks. Advance the exact remaining number of authored pages without
      // asking the paused Runtime domain for state between clicks.
      for (let page = firstDialoguePage; page < dialoguePages; page += 1) {
        await sleep(260);
        if (actionLabel && page === dialoguePages - 1) {
          const chosen = await chooseDialogueAction(cdp, actionLabel, page);
          checkpoints.push({ event: "dialogue_action_selected", id, label: chosen });
        } else {
          await advanceDialogueInput(cdp, page);
        }
        await sleep(400);
      }
    // A Compatibility frame can deliver the final button press shortly after
    // the last keyup reaches the browser bridge. Wait for the ordinary closed
    // state instead of sampling during that handoff window.
    await waitFor(async () => {
      const dialogue = await freshDialogueState(cdp).catch(() => null);
      // A delayed Compatibility click can close the surface just after the
      // final page is rendered. Require the terminal page as well as the
      // hidden/unpaused state so an old pre-dialogue snapshot cannot satisfy
      // this assertion, then allow the bounded UI handoff to settle.
      return dialogue?.visible === false
        && Number(dialogue?.page ?? -1) >= dialoguePages - 1
        ? { dialogue }
        : null;
    }, `${id} dialogue close`, 8000);
    // Clear a release whose acknowledgement may have been lost when the
    // interaction keydown moved the game into paused-dialogue mode.
    await dispatchKey(cdp, interactionKey[0], interactionKey[1], false, true).catch(() => {});
    // Reacquire pointer lock with a direct gameplay gesture. Browsers reject
    // deferred lock requests made by the dialogue callback itself.
    if (restoreGameplayPointer) {
      // InputRouter blocks Web capture for 350 ms after restoring gameplay.
      // The next gesture must occur outside that guard, not inside it.
      await sleep(400);
      const beforePointer = Number(cdp.lastObservation?.timestamp_ms);
      try {
        await clickAttack(cdp, false);
      } catch (error) {
        if (error?.fatal || !String(error?.message || error).includes("timed out")) throw error;
        await waitFor(() => {
          const state = cdp.lastObservation;
          return Number(state?.timestamp_ms) > beforePointer
            && state.dialogue?.visible === false && !state.paused
            && state.player?.can_control === true && state.mouse_mode === 2;
        }, `${id} delivered gameplay pointer gesture`, 5000);
      }
      await sleep(180);
    }
  }
  // A real clue interaction queues an Area3D for deletion. Compatibility Web
  // can spend the following render frame retiring that body/material while a
  // CDP Runtime.evaluate is already waiting on the same browser thread. Let
  // the deferred deletion settle before the next route observation; this is
  // a bounded handoff delay, not a second state probe or route shortcut.
  const usedState = await telemetry(cdp);
  checkpoints.push({ event: "interaction_used", id, zone: usedState?.zone });
  if (!expectsDialogue) await sleep(POST_INTERACTION_SETTLE_MS);
}

function movementKeyToward(player, target, cameraYaw) {
  const dx = Number(target.position.x) - Number(player.position.x);
  const dz = Number(target.position.z) - Number(player.position.z);
  const distance = Math.max(0.001, Math.hypot(dx, dz));
  const cameraForwardX = -Math.sin(cameraYaw);
  const cameraForwardZ = -Math.cos(cameraYaw);
  const cameraRightX = Math.cos(cameraYaw);
  const cameraRightZ = -Math.sin(cameraYaw);
  const forwardAmount = (dx * cameraForwardX + dz * cameraForwardZ) / distance;
  const rightAmount = (dx * cameraRightX + dz * cameraRightZ) / distance;

  if (Math.abs(rightAmount) >= Math.abs(forwardAmount)) {
    return rightAmount >= 0
      ? { code: "KeyD", key: "d" }
      : { code: "KeyA", key: "a" };
  }
  return forwardAmount >= 0
    ? { code: "KeyW", key: "w" }
    : { code: "KeyS", key: "s" };
}

function movementKeyForCombat(player, target, cameraYaw) {
  const movement = movementKeyToward(player, target, cameraYaw);
  // Backpedaling intentionally preserves facing in the game controller. For
  // a live enemy approach that would leave Kael looking away while the attack
  // edge is armed, so use the nearer lateral axis to turn without asking the
  // browser Runtime domain to rotate the camera.
  if (movement.code !== "KeyS") return movement;
  const dx = Number(target.position.x) - Number(player.position.x);
  const dz = Number(target.position.z) - Number(player.position.z);
  const cameraRightX = Math.cos(cameraYaw);
  const cameraRightZ = -Math.sin(cameraYaw);
  const rightAmount = dx * cameraRightX + dz * cameraRightZ;
  return rightAmount >= 0
    ? { code: "KeyD", key: "d" }
    : { code: "KeyA", key: "a" };
}

async function attackLiveTarget(cdp, meleeInputDistance = 2.84, targetId = "") {
  // The enemy is a live navigation actor, not a fixed target dummy. Combat
  // uses the game's optional target-lock camera, acquired by a real T input in
  // fightWychwoodPack(), rather than writing camera yaw through QA telemetry.
  // Wait for that authored camera frame to converge while re-reading the live
  // target; this keeps the player-facing pose and blade contact on one current
  // target without combining an old bearing with a newer enemy position.
  let state = await freshCombatState(cdp);
  let target = selectActiveEnemy(state, targetId);
  let player = state?.player;
  if (!player || !target?.position) return null;
  const contactDistance = ["ghoulkin", "wychwood_stalker", "bandit", "bog_wretch"].includes(target.id)
    ? Math.min(meleeInputDistance, 1.1) : meleeInputDistance;
  if (Math.hypot(target.position.x - player.position.x, target.position.z - player.position.z) > contactDistance) {
    await approachMovingEnemy(cdp, contactDistance, 5000, target.id);
    state = await freshCombatState(cdp);
    target = selectActiveEnemy(state, targetId);
    player = state?.player;
    if (!player || !target?.position) return null;
  }
  if (!state.camera?.locked_target_id) {
    const targetYaw = Math.atan2(player.position.x - target.position.x,
      player.position.z - target.position.z);
    await turnCameraToward(cdp, targetYaw, state.camera?.yaw);
    state = await freshCombatState(cdp);
    if (!state?.player) return null;
  }
  let aligned = false;
  for (let attempt = 0; attempt < 9; attempt += 1) {
    const currentTarget = selectActiveEnemy(state, targetId);
    const currentPlayer = state?.player;
    if (!currentPlayer?.position || !currentTarget?.position) return null;
    const dx = Number(currentTarget.position.x) - Number(currentPlayer.position.x);
    const dz = Number(currentTarget.position.z) - Number(currentPlayer.position.z);
    if (Math.hypot(dx, dz) > contactDistance) return null;
    const targetYaw = Math.atan2(-dx, -dz);
    if (Math.abs(angleDelta(Number(state.camera?.yaw ?? targetYaw), targetYaw)) <= 0.78) {
      target = currentTarget;
      player = currentPlayer;
      aligned = true;
      break;
    }
    await sleep(105);
    state = await combatTelemetry(cdp).catch(() => null);
    if (!state) return null;
  }
  if (!aligned) return null;
  // With a lock, neutral movement lets the actual attack edge face the live
  // target. A forward pulse would override that with the camera's lagging yaw.
  // Free-camera attacks retain the ordinary movement-facing pulse.
  const movement = ["KeyW", "w"];
  const movementKeys = [["KeyW", "w"], ["KeyA", "a"], ["KeyS", "s"], ["KeyD", "d"]];
  await cdp.send("Page.bringToFront");
  for (const [code, key] of movementKeys) {
    await dispatchMovementKey(cdp, code, key, false);
  }
  await sleep(40);
  const lockedAttack = Boolean(state.camera?.locked_target_id);
  if (!lockedAttack) await dispatchMovementKey(cdp, movement[0], movement[1], true);
  try {
    if (!lockedAttack) await sleep(110);
    await clickAttack(cdp, false);
  } finally {
    for (const [code, key] of movementKeys) {
      await dispatchMovementKey(cdp, code, key, false).catch(() => {});
    }
  }
  await sleep(65);
  // Wave activation can briefly occupy the Web Runtime domain while the
  // defeated actor is retired and the next enemy is made visible. The attack
  // itself has already been delivered through the real input edge; a missed
  // post-attack snapshot is not evidence that combat failed. Let the next
  // loop consume the coalesced observation (or re-read the compact state)
  // instead of turning that renderer handoff into a false browser failure.
  return freshCombatState(cdp).catch(() => null);
}

async function fightWychwoodPack(cdp, checkpoints, timeout = 150000) {
  const started = Date.now();
  let lastPotion = Date.now();
  let bombUsed = false;
  let lockedTargetKey = "";
  // Match the native blade-contact route, not the broad candidate envelope.
  const meleeInputDistance = 1.1;
  let enteredClearing = false;
  const clearing = { x: 0.0, y: 0.0, z: -6.5 };
  // Match WychwoodClearingFrame.safe_half_extents from the authored builder.
  // Entry is valid anywhere inside the player-clearance-adjusted arena, not
  // only within a small radius of the clearing's presentation center.
  const clearingSafeHalfExtents = { x: 5.2, z: 4.2 };
  const clearingPlayerClearance = 0.65;
  const isInsideClearing = (player) => Boolean(player)
    && Math.abs(Number(player.x) - clearing.x) <= clearingSafeHalfExtents.x - clearingPlayerClearance
    && Math.abs(Number(player.z) - clearing.z) <= clearingSafeHalfExtents.z - clearingPlayerClearance;
  while (Date.now() - started < timeout) {
    const state = await combatTelemetry(cdp);
    if (state?.quests?.fight_complete) {
      checkpoints.push({ event: "wychwood_pack_defeated", elapsed_ms: Date.now() - started });
      return;
    }
    // Wychwood stages its first wave when the player enters the authored
    // clearing. The route must prove that physical approach before combat;
    // selecting a staged enemy from the entry road would otherwise make the
    // harness attack an intentionally dormant target forever.
    if (!enteredClearing) {
      const player = state?.player?.position;
      if (!player) {
        await sleep(120);
        continue;
      }
      const distanceToClearing = Math.hypot(clearing.x - Number(player.x), clearing.z - Number(player.z));
      const insideClearing = isInsideClearing(player);
      if (distanceToClearing > 1.15 && !insideClearing) {
        // Combat entry is a single authored clearing, but the approach can
        // cross a bridge. Use the observed-position hold contract here rather
        // than a guessed-duration W pulse: sparse Compatibility frames can
        // drop a fixed key heartbeat while Kael is still on a valid bridge
        // surface, making a physical route look obstructed.
        // This is one straight, bridge-to-clearing leg. The continuous raw
        // physical hold is the route contract already proven by the native
        // CharacterBody test and the earlier browser run; the replan helper's
        // Euclidean early-release heuristic can stop this unobstructed leg on
        // a valid bridge sample when Compatibility observations are sparse.
        const progress = await holdTowardPoint(
          cdp,
          { x: clearing.x, y: Number(player.y || 0), z: clearing.z },
          clamp((distanceToClearing / 2.6) * 1000 + 12000, 20000, 60000),
        );
        if (!progress?.player?.position) throw new Error("No player telemetry while entering Wychwood clearing");
        if (isInsideClearing(progress.player.position)) {
          enteredClearing = true;
          checkpoints.push({
            event: "wychwood_clearing_entered",
            zone: progress.zone,
            player: progress.player.position,
            distance: Math.hypot(clearing.x - Number(progress.player.position.x), clearing.z - Number(progress.player.position.z)),
            entry_mode: "arena_footprint",
          });
        }
        continue;
      }
      enteredClearing = true;
      checkpoints.push({
        event: "wychwood_clearing_entered",
        zone: state.zone,
        player: player,
        distance: distanceToClearing,
        entry_mode: insideClearing ? "arena_footprint" : "center_tolerance",
      });
      continue;
    }
    // A freshly staged enemy can appear in one coalesced observation before
    // the complete position record is published. Treat that frame as
    // transient instead of dereferencing a partial combat snapshot.
    const living = (state?.enemies || []).filter((enemy) => enemy?.active
      && Number(enemy.health) > 0.01
      && enemy.position
      && Number.isFinite(Number(enemy.position.x))
      && Number.isFinite(Number(enemy.position.z)));
    const target = living[0];
    if (!target) {
      // Activation is owned by the game’s distance trigger. Keep the player in
      // the clearing through ordinary movement until the first wave is live;
      // never treat a dormant enemy as a combat target.
      const player = state?.player?.position;
      if (player) {
        await holdTowardPoint(cdp, { x: clearing.x, y: Number(player.y || 0), z: clearing.z }, 1800);
      }
      await sleep(150);
      continue;
    }
    const player = state?.player?.position;
    if (!player
      || !Number.isFinite(Number(player.x))
      || !Number.isFinite(Number(player.z))
      || !target?.position) {
      await sleep(120);
      continue;
    }
    if (state.player.dead || Number(state.player.health) <= 0) throw new Error("Kael died during the Wychwood pack");
    const dx = target.position.x - player.x;
    const dz = target.position.z - player.z;
    const distance = Math.hypot(dx, dz);
    const targetIndex = Array.isArray(state.enemies) ? state.enemies.indexOf(target) : -1;
    const targetKey = `${targetIndex}:${target.id || ""}`;
    if (targetKey !== lockedTargetKey) {
      // Acquire the game's real optional lock-on once per staged wave. The
      // camera then follows the live enemy through its navigation movement,
      // avoiding a stale command-written yaw in the low-FPS browser path.
      await tapGameplayKey(cdp, "KeyT", "t", 80);
      lockedTargetKey = targetKey;
      await sleep(440);
      continue;
    }
    if (!bombUsed && distance <= 6.0) {
      await tapKey(cdp, "KeyF", "f", 70);
      bombUsed = true;
      await sleep(300);
      continue;
    }
    // A live enemy can cross the melee envelope while the previous compact
    // observation is still being consumed. Give the attack helper one fresh,
    // bounded chance whenever the sampled distance is near the envelope before
    // committing to another movement segment. This keeps a circling target
    // from leaving Kael grounded in range while the driver continues to steer
    // toward an already-stale point.
    if (distance <= meleeInputDistance + 0.60) {
      const nearAttackState = await attackLiveTarget(cdp, meleeInputDistance).catch(() => null);
      if (nearAttackState) {
        await sleep(380);
        if (Number(nearAttackState.player?.health) < 75
          && Number(nearAttackState.inventory?.items?.redroot_potion || 0) > 0
          && Date.now() - lastPotion > 5000) {
          await tapKey(cdp, "KeyR", "r", 60);
          lastPotion = Date.now();
        }
        continue;
      }
    }
    // Oathfire has its own player-driven gate. Do not interleave a charged
    // cast into this opening melee loop: the cast locks the player's current
    // facing and suppresses sword input, while this driver is deliberately
    // using camera rotation to line up the next physical attack. Firing it
    // before melee range made the route depend on an incidental facing and
    // could leave the browser Runtime domain stalled during first-use VFX.
    if (distance > meleeInputDistance) {
      // The enemy is a live navigation actor, so its preferred-distance
      // correction can move while this loop is between observations. A fixed
      // W hold then becomes stale as soon as the target crosses the camera
      // forward vector (v105 ended with a -0.993 target-facing dot product).
      // Reuse the real observed-position route helper so each short segment
      // recomputes the camera-relative input from the target's current point;
      // this changes only QA movement input and never writes a game transform.
      const approach = await approachMovingEnemy(
        cdp,
        meleeInputDistance,
        clamp((distance / 2.6) * 1000 + 1200, 1800, 5000),
      );
      if (!approach?.player?.position) throw new Error("No player telemetry while approaching active Wychwood enemy");
      continue;
    }
    // Keep a current movement bearing alive through the physical attack edge.
    // The helper returns null when the target moved out of the melee envelope;
    // the outer loop then re-plans from a fresh observation instead of firing
    // at a stale position.
    const attackState = await attackLiveTarget(cdp, meleeInputDistance);
    if (!attackState) {
      // A lost lock is retried through the real T action on the next loop. Do
      // not write a camera transform or infer a combat hit from stale state.
      lockedTargetKey = "";
      continue;
    }
    await sleep(380);
    if (Number(attackState.player?.health) < 75
      && Number(attackState.inventory?.items?.redroot_potion || 0) > 0
      && Date.now() - lastPotion > 5000) {
      await tapKey(cdp, "KeyR", "r", 60);
      lastPotion = Date.now();
    }
  }
  throw new Error(`Wychwood pack did not resolve through real combat input`);
}

async function runOpeningCampaign(cdp, url, checkpoints, onStartupReady, reportInteraction = "sister_anwen") {
  let state = await startNewGame(cdp, `${url}&scenario=opening-campaign-${Date.now()}`, onStartupReady);
  checkpoints.push({ event: "scenario_start", scenario: "opening-campaign", zone: state.zone });
  if (stopAfter === "startup") {
    if (repeatStartup) {
      // A repeat visit is warm only after the first visit's verified opening
      // pack has finished copying/mounting. A fixed delay can reload while that
      // transaction still owns the main thread and would measure contention,
      // not browser HTTP/WASM cache behavior.
      await waitFor(async () => {
        const settled = await freshTelemetry(cdp).catch(() => null);
        return settled?.runtime_packs?.opening?.state === "ready" ? settled : null;
      }, "opening pack cache settlement", 30000);
      await sleep(1000);
      state = await startNewGame(cdp, `${url}&scenario=opening-repeat-${Date.now()}`, async () => {});
      checkpoints.push({ event: "repeat_startup", scenario: "opening-repeat", zone: state.zone });
    }
    return state;
  }
  await useInteraction(cdp, "sister_anwen", checkpoints, true);
  if (stopAfter === "anwen") return telemetry(cdp);
  await traverse(cdp, "wychwood", checkpoints);
  for (const clue of ["corpse", "black_feathers", "claw_marks"]) {
    await useInteraction(cdp, clue, checkpoints, false);
  }
  await waitFor(
    async () => {
      const evidenceState = await freshTelemetry(cdp);
      return evidenceState?.quests?.evidence_ready ? evidenceState : null;
    },
    "Three real clue interactions evidence threshold",
    10000
  );
  await fightWychwoodPack(cdp, checkpoints);
  await traverse(cdp, "greyfen", checkpoints);
  if (!reportInteraction) {
    const unresolved = await freshTelemetry(cdp);
    if (unresolved?.story?.flags?.evidence_report
      || !unresolved?.quests?.objectives_done?.main_road_of_crows?.includes("fight_ghoulkin")) {
      throw new Error("Player-driven pre-report checkpoint is not unresolved after the Wychwood return");
    }
    return unresolved;
  }
  await useInteraction(cdp, reportInteraction, checkpoints, true);
  const finalState = await telemetry(cdp);
  if (!finalState?.quests?.road_complete || !finalState?.quests?.bell_active) {
    throw new Error(`Real report did not complete Road of Crows and open Bell Beneath Greyfen`);
  }
  checkpoints.push({ event: "opening_complete", zone: finalState.zone, quests: finalState.quests });
  return finalState;
}

async function runScenario(cdp, url, name, route, checkpoints, onStartupReady) {
  const state = await startNewGame(cdp, `${url}&scenario=${encodeURIComponent(name)}-${Date.now()}`, onStartupReady);
  checkpoints.push({ event: "scenario_start", scenario: name, zone: state.zone, player: state.player.position });
  for (const target of route) {
    await traverse(cdp, target, checkpoints);
  }
}

async function runFullCampaign(cdp, url, checkpoints, onStartupReady) {
  return runOpeningThroughFinale(cdp, url, checkpoints, onStartupReady);
}

async function fightCemeteryAmbush(cdp, checkpoints, timeout = 60000) {
  const started = Date.now();
  let lockedTarget = "";
  let lastDamage = Date.now();
  let previousHealth = Infinity;
  let lastPotion = 0;
  while (Date.now() - started < timeout) {
    const state = await combatTelemetry(cdp);
    if (state?.quests?.objectives_done?.main_bell_beneath_greyfen?.includes("cemetery_ambush")) {
      checkpoints.push({ event: "cemetery_ambush_defeated", elapsed_ms: Date.now() - started });
      return state;
    }
    if (state?.player?.dead || Number(state?.player?.health) <= 0) throw new Error("Kael died in the cemetery ambush");
    const living = (state?.enemies || []).filter((enemy) => enemy?.active && !enemy.dead && Number(enemy.health) > 0);
    if (living.length !== 1 || !living[0]?.position || !state?.player?.position) {
      await sleep(150);
      continue;
    }
    const target = living[0];
    if (Number(target.health) < previousHealth) {
      previousHealth = Number(target.health);
      lastDamage = Date.now();
    }
    if (Date.now() - lastDamage > 20000) throw new Error(`Cemetery ambush stalled at ${target.health} health`);
    if (lockedTarget !== target.id) {
      await tapGameplayKey(cdp, "KeyT", "t", 80);
      lockedTarget = target.id;
      await sleep(300);
      continue;
    }
    const distance = Math.hypot(
      target.position.x - state.player.position.x,
      target.position.z - state.player.position.z,
    );
    if (Number(state.player.health) < 65 && Date.now() - lastPotion > 6000) {
      await tapGameplayKey(cdp, "KeyR", "r", 70);
      lastPotion = Date.now();
    }
    if (distance > 2.84) {
      await approachMovingEnemy(cdp, 2.84, clamp((distance / 2.6) * 1000 + 1200, 1800, 5000));
    } else {
      await attackLiveTarget(cdp, 2.84);
      await sleep(380);
    }
  }
  throw new Error("Cemetery ambush did not resolve through real combat input");
}

async function runOpeningToShrine(cdp, url, checkpoints, onStartupReady, resumeAt = "new_game") {
  if (resumeAt === "greyfen_measure") {
    const saved = await freshTelemetry(cdp);
    if (saved?.zone !== "greyfen" || !saved?.player?.can_control
      || !saved?.quests?.completed?.includes("main_road_of_crows")
      || !saved?.quests?.active?.includes("main_bell_beneath_greyfen")
      || !saved?.quests?.active?.includes("side_millers_measure")
      || !saved?.quests?.objectives_done?.side_millers_measure?.includes("weigh_ash")
      || saved?.story?.flags?.ash_measure_fate) {
      throw new Error("Earned Greyfen measure checkpoint cannot continue the main route");
    }
  } else if (resumeAt === "new_game") {
    await runOpeningCampaign(cdp, url, checkpoints, onStartupReady);
  } else {
    throw new Error(`Unsupported shrine route checkpoint: ${resumeAt}`);
  }
  await useInteraction(cdp, "sister_anwen", checkpoints, true);
  let state = await freshTelemetry(cdp);
  if (!state?.quests?.objectives_done?.main_bell_beneath_greyfen?.includes("meet_anwen_gate")) {
    throw new Error("Cemetery Anwen conversation did not complete meet_anwen_gate");
  }
  for (const grave of ["grave_harl", "grave_soldier"]) {
    await useInteraction(cdp, grave, checkpoints);
  }
  state = await freshTelemetry(cdp);
  if (!state?.quests?.objectives_done?.main_bell_beneath_greyfen?.includes("grave_truth")) {
    throw new Error("Two real grave inspections did not complete grave_truth");
  }
  await fightCemeteryAmbush(cdp, checkpoints);
  await useInteraction(cdp, "chapel_door", checkpoints);
  state = await freshTelemetry(cdp);
  if (!state?.quests?.objectives_done?.main_bell_beneath_greyfen?.includes("open_chapel")) {
    throw new Error("Real chapel interaction did not open the chapel");
  }
  if (state?.story?.flags?.crow_shrine_state
    || state?.quests?.objectives_done?.main_bell_beneath_greyfen?.includes("crow_shrine_choice")) {
    throw new Error("Crow Shrine checkpoint was already resolved before player choice");
  }
  return state;
}

async function runOpeningAndCemetery(cdp, url, checkpoints, onStartupReady, resumeAt = "new_game") {
  await runOpeningToShrine(cdp, url, checkpoints, onStartupReady, resumeAt);
  await useInteraction(cdp, "crow_shrine_choice", checkpoints, true, "Cleanse the shrine");
  const state = await freshTelemetry(cdp);
  if (state?.story?.flags?.crow_shrine_state !== "cleansed"
    || !state?.quests?.completed?.includes("main_bell_beneath_greyfen")) {
    throw new Error("Real shrine choice did not persist the cleansed state");
  }
  checkpoints.push({ event: "cemetery_choice_complete", zone: state.zone, outcome: "cleansed" });
  return state;
}

async function continueSavedShrine(cdp, url, checkpoints) {
  const resumeUrl = `${url}&shrine_resume=${Date.now()}`;
  await cdp.send("Page.navigate", { url: resumeUrl });
  await waitFor(async () => cdp.evaluate(
    `location.href.startsWith(${JSON.stringify(resumeUrl)}) && Boolean(document.getElementById("start") && document.querySelector("canvas"))`
  ), "Shrine checkpoint page reload", 10000);
  await activateBootShell(cdp);
  await waitFor(async () => {
    const current = await freshTelemetry(cdp).catch(() => null);
    return current?.new_game_ready && current?.ui?.active_menu === "main"
      && current?.ui?.buttons?.some((button) => button.text === "Continue" && button.enabled)
      ? current : null;
  }, "enabled Continue after Shrine checkpoint reload", 45000);
  await chooseMenuButton(cdp, "Continue");
  const resumed = await waitFor(async () => {
    const current = await freshTelemetry(cdp).catch(() => null);
    return current?.zone === "greyfen" && current?.player?.can_control && !current?.transition_pending
      ? current : null;
  }, "Shrine checkpoint gameplay control", 20000);
  if (!resumed?.quests?.active?.includes("main_bell_beneath_greyfen")
    || !resumed?.quests?.objectives_done?.main_bell_beneath_greyfen?.includes("open_chapel")
    || resumed?.quests?.objectives_done?.main_bell_beneath_greyfen?.includes("crow_shrine_choice")
    || resumed?.story?.flags?.crow_shrine_state) {
    throw new Error("Real Continue did not restore the unresolved Crow Shrine checkpoint");
  }
  checkpoints.push({ event: "shrine_checkpoint_restored", zone: resumed.zone });
  return resumed;
}

async function runOpeningShrineMatrix(cdp, url, checkpoints, onStartupReady) {
  await runOpeningToShrine(cdp, url, checkpoints, onStartupReady);
  await saveThroughPauseMenu(cdp, checkpoints);
  const choices = [
    { label: "Cleanse the shrine", state: "cleansed" },
    { label: "Disturb it for memory", state: "disturbed" },
    { label: "Bind it and leave", state: "bound" },
  ];
  let lastState = null;
  for (const [index, choice] of choices.entries()) {
    if (index > 0) await continueSavedShrine(cdp, url, checkpoints);
    await useInteraction(cdp, "crow_shrine_choice", checkpoints, true, choice.label);
    lastState = await freshTelemetry(cdp);
    if (lastState?.story?.flags?.crow_shrine_state !== choice.state
      || !lastState?.quests?.completed?.includes("main_bell_beneath_greyfen")) {
      throw new Error(`Real Crow Shrine choice did not persist ${choice.state}`);
    }
    checkpoints.push({ event: "shrine_choice_completed", outcome: choice.state });
  }
  return lastState;
}

async function fightBellEater(cdp, checkpoints, timeout = 90000) {
  const started = Date.now();
  // Native contact approach: player0.32 + Bell-Eater0.82 + clearance0.06.
  const meleeDistance = 1.2;
  let previousHealth = Infinity;
  let lastProgress = started;
  let lastPotion = 0;
  let castOathfire = false;
  let lockAttempts = 0;
  let guarding = false;
  const setGuard = async (enabled) => {
    if (guarding === enabled) return;
    await dispatchKey(cdp, "KeyQ", "q", enabled, true);
    guarding = enabled;
  };
  try {
  while (Date.now() - started < timeout) {
    const state = await combatTelemetry(cdp);
    if (state?.story?.flags?.bell_eater_defeated) {
      const flags = state.story.flags;
      for (const flag of ["cemetery_bell_silent", "boss_reward_granted_bell_eater", "boss_reward_bell_iron", "boss_reward_chapel_key"]) {
        if (!flags[flag]) throw new Error(`Bell-Eater death omitted ${flag}`);
      }
      checkpoints.push({ event: "bell_eater_defeated", elapsed_ms: Date.now() - started, rewards: true });
      return;
    }
    if (state?.player?.dead || Number(state?.player?.health) <= 0) throw new Error("Kael died fighting Bell-Eater");
    const boss = selectActiveEnemy(state, "bell_eater");
    if (!boss || !state?.player?.position) {
      await sleep(150);
      continue;
    }
    if (boss.health < previousHealth) {
      previousHealth = boss.health;
      lastProgress = Date.now();
    }
    if (Date.now() - lastProgress > 25000) throw new Error(`Bell-Eater combat stalled at ${boss.health} health`);
    if (Number(state.player.health) < 75 && Date.now() - lastPotion > 6000
      && Number(state.inventory?.items?.redroot_potion || 0) > 0) {
      await tapGameplayKey(cdp, "KeyR", "r", 80);
      lastPotion = Date.now();
      continue;
    }
    if (state.camera?.locked_target_id !== "bell_eater") {
      if (++lockAttempts > 6) throw new Error(`Could not lock Bell-Eater through real input: ${state.camera?.locked_target_id}`);
      await tapGameplayKey(cdp, "KeyT", "t", 80);
      await sleep(300);
      continue;
    }
    lockAttempts = 0;
    const distance = Math.hypot(
      boss.position.x - state.player.position.x,
      boss.position.z - state.player.position.z,
    );
    // Q is block; right mouse would start another heavy attack during windup.
    const defending = Number(boss.pending_attack_time || 0) > 0 && distance < 4;
    await setGuard(defending);
    if (defending) {
      await releaseMovementKeys(cdp);
      await sleep(70);
      continue;
    }
    if (!castOathfire && distance <= 7) {
      await tapGameplayKey(cdp, "KeyC", "c", 1700);
      castOathfire = true;
      checkpoints.push({ event: "bell_eater_oathfire_input" });
      await sleep(350);
      continue;
    }
    if (state.player.weapon_mode !== "sword") {
      await tapGameplayKey(cdp, "Digit1", "1", 80);
      continue;
    }
    if (distance > meleeDistance) await approachMovingEnemy(cdp, meleeDistance, 5000, "bell_eater");
    else await attackLiveTarget(cdp, meleeDistance, "bell_eater");
    await sleep(70);
  }
  throw new Error("Bell-Eater did not resolve through real combat input");
  } finally {
    await setGuard(false);
    await releaseMovementKeys(cdp);
  }
}

async function runOpeningThroughBellEater(cdp, url, checkpoints, onStartupReady, resumeAt = "new_game") {
  await runOpeningAndCemetery(cdp, url, checkpoints, onStartupReady, resumeAt);
  const shrine = await freshTelemetry(cdp);
  const player = shrine?.player?.position;
  if (!player || shrine?.zone !== "greyfen") throw new Error("Shrine route did not leave Kael in Greyfen");
  // The native route aligns this axis before walking west. Combining both
  // axes cuts across the facade/bell post when shrine focus ends south of it.
  const entrance = await approachPointWithReplan(cdp,
    { x: player.x, y: Number(player.y || 0), z: 8.29 }, 4000, 0.12);
  if (!entrance?.player?.position || Math.abs(entrance.player.position.z - 8.29) > 0.18) {
    throw new Error("Physical chapel entrance alignment did not reach the clear aisle");
  }
  // Prove the doorway with the actual capsule crossing, not a centimetre-
  // precise staging coordinate that digital input can overshoot between frames.
  await turnCameraToward(cdp, 0, entrance.camera?.yaw);
  const doorway = await holdTowardPoint(cdp, { x: 13.2, y: Number(player.y || 0), z: 8.29 }, 8000,
    "", (position, state) => {
      const boss = selectActiveEnemy(state, "bell_eater");
      return position.x < 13.7 || (position.x < 14.9 && boss?.position
        && Math.hypot(boss.position.x - position.x, boss.position.z - position.z) <= 1.7);
    }, 0);
  if (!doorway?.player?.position || doorway.player.position.x >= 14.9
    || doorway.player.dead || !doorway.player.can_control) {
    throw new Error("Physical chapel doorway crossing did not reach the combat approach");
  }
  checkpoints.push({ event: "chapel_doorway_crossed", x: doorway.player.position.x, z: doorway.player.position.z });
  await fightBellEater(cdp, checkpoints);
  await tapGameplayKey(cdp, "Digit1", "1", 80);
  await waitFor(async () => {
    const current = await freshCombatState(cdp).catch(() => null);
    return current?.player?.weapon_mode === "sword" ? current : null;
  }, "cemetery aftermath sword equip", 5000);
  const aftermath = await freshTelemetry(cdp);
  const summons = (aftermath?.enemies || []).filter((enemy) => enemy.id === "ghoulkin" && enemy.active && !enemy.dead && enemy.health > 0);
  if (summons.length > 1) throw new Error("Bell-Eater aftermath spawned more than one living Ghoulkin");
  if (summons.length === 1) {
    const started = Date.now();
    let lastHealth = Infinity;
    let lastProgress = started;
    let lockRequested = false;
    while (Date.now() - started < 45000) {
      const state = await combatTelemetry(cdp);
      const enemy = selectActiveEnemy(state, "ghoulkin");
      if (!enemy) break;
      if (state?.player?.dead || Number(state?.player?.health) <= 0) throw new Error("Kael died fighting Bell-Eater's summon");
      if (enemy.health < lastHealth) {
        lastHealth = enemy.health;
        lastProgress = Date.now();
      }
      if (Date.now() - lastProgress > 20000) throw new Error(`Bell-Eater summon stalled at ${enemy.health} health`);
      if (state.camera?.locked_target_id !== "ghoulkin" && !lockRequested) {
        await tapGameplayKey(cdp, "KeyT", "t", 80);
        lockRequested = true;
        await sleep(300);
        continue;
      }
      const distance = Math.hypot(enemy.position.x - state.player.position.x, enemy.position.z - state.player.position.z);
      if (distance > 1.1) {
        await approachMovingEnemy(cdp, 1.1, 5000, "ghoulkin");
      } else {
        await attackLiveTarget(cdp, 1.1, "ghoulkin");
        await sleep(380);
      }
    }
  }
  const finalState = await freshTelemetry(cdp);
  if ((finalState?.enemies || []).some((enemy) => enemy.id === "ghoulkin" && enemy.active && !enemy.dead && enemy.health > 0)) {
    throw new Error("Bell-Eater summon remains alive after real combat input");
  }
  checkpoints.push({ event: "bell_eater_aftermath_complete", zone: finalState.zone });
  return finalState;
}

async function fightBogWretch(cdp, checkpoints, timeout = 90000) {
  const started = Date.now();
  let previousHealth = Infinity;
  let lastProgress = started;
  let lastPotion = 0;
  let bombUsed = false;
  let lockAttempts = 0;
  while (Date.now() - started < timeout) {
    const state = await combatTelemetry(cdp);
    if (state?.quests?.objectives_done?.main_teeth_in_rain?.includes("fight_bog_wretch")) {
      checkpoints.push({ event: "bog_wretch_defeated", elapsed_ms: Date.now() - started });
      return;
    }
    if (state?.player?.dead || Number(state?.player?.health) <= 0) throw new Error("Kael died fighting Bog Wretch");
    const enemy = selectActiveEnemy(state, "bog_wretch");
    if (!enemy || !state?.player?.position) {
      await sleep(150);
      continue;
    }
    if (enemy.health < previousHealth) {
      previousHealth = enemy.health;
      lastProgress = Date.now();
    }
    if (Date.now() - lastProgress > 25000) throw new Error(`Bog Wretch combat stalled at ${enemy.health} health`);
    const distance = Math.hypot(enemy.position.x - state.player.position.x, enemy.position.z - state.player.position.z);
    if (!bombUsed && Number(state.inventory?.items?.ash_bomb || 0) > 0 && distance <= 6) {
      const healthBefore = enemy.health;
      const bombsBefore = Number(state.inventory.items.ash_bomb);
      await tapGameplayKey(cdp, "KeyF", "f", 80);
      const exposed = await waitFor(async () => {
        const current = await freshTelemetry(cdp).catch(() => null);
        const currentEnemy = selectActiveEnemy(current, "bog_wretch");
        return current?.story?.flags?.bog_core_exposed
          && Number(current?.inventory?.items?.ash_bomb ?? bombsBefore) < bombsBefore
          && currentEnemy && currentEnemy.health < healthBefore ? current : null;
      }, "Bog Wretch ash weakness", 5000);
      bombUsed = true;
      checkpoints.push({ event: "bog_ash_weakness", enemy_health: selectActiveEnemy(exposed, "bog_wretch")?.health });
      continue;
    }
    if (state.camera?.locked_target_id !== "bog_wretch") {
      if (++lockAttempts > 6) throw new Error(`Could not lock Bog Wretch through real input: ${state.camera?.locked_target_id}`);
      await tapGameplayKey(cdp, "KeyT", "t", 80);
      await sleep(300);
      continue;
    }
    lockAttempts = 0;
    if (Number(state.player.health) < 75 && Date.now() - lastPotion > 6000
      && Number(state.inventory?.items?.redroot_potion || 0) > 0) {
      await tapGameplayKey(cdp, "KeyR", "r", 80);
      lastPotion = Date.now();
      continue;
    }
    if (distance > 2.84) {
      await approachMovingEnemy(cdp, 2.84, clamp((distance / 2.6) * 1000 + 1200, 1800, 5000), "bog_wretch");
    } else {
      await attackLiveTarget(cdp, 2.84, "bog_wretch");
      await sleep(380);
    }
  }
  throw new Error("Bog Wretch did not resolve through real combat input");
}

async function runOpeningThroughTeeth(cdp, url, checkpoints, onStartupReady, resumeAt = "new_game") {
  await runOpeningThroughBellEater(cdp, url, checkpoints, onStartupReady, resumeAt);
  let state = await freshTelemetry(cdp);
  if (!state?.quests?.active?.includes("main_teeth_in_rain")) throw new Error("Bell aftermath did not activate Teeth in the Rain");
  await useInteraction(cdp, "mira", checkpoints, true, "I will read the chapel register");
  state = await freshTelemetry(cdp);
  if (!state?.quests?.objectives_done?.main_teeth_in_rain?.includes("speak_mira")) throw new Error("Mira briefing did not complete through dialogue input");
  await useInteraction(cdp, "chapel_names", checkpoints);
  state = await freshTelemetry(cdp);
  if (!state?.quests?.objectives_done?.main_teeth_in_rain?.includes("read_chapel_names")) throw new Error("Chapel names did not advance Teeth in the Rain");
  await traverse(cdp, "wychwood", checkpoints);
  await useInteraction(cdp, "ritual_stones", checkpoints);
  state = await freshTelemetry(cdp);
  if (!state?.quests?.objectives_done?.main_teeth_in_rain?.includes("name_the_dead")) throw new Error("Ritual stones did not name the dead");
  await traverse(cdp, "deep_wood", checkpoints);
  state = await freshTelemetry(cdp);
  if (state?.zone !== "deep_wood" || !state?.enemies?.some((enemy) => enemy.id === "bog_wretch" && !enemy.dead)) {
    throw new Error("Deep Wood arrival omitted the quest-gated Bog Wretch");
  }
  const player = state.player?.position;
  await holdTowardPoint(cdp, { x: 0, y: Number(player?.y || 0), z: -3.7 }, 12000);
  await fightBogWretch(cdp, checkpoints);
  await useInteraction(cdp, "bog_core_choice", checkpoints, true, "Destroy the memory core");
  state = await freshTelemetry(cdp);
  if (state?.story?.flags?.bog_core_fate !== "destroyed"
    || !state?.quests?.completed?.includes("main_teeth_in_rain")
    || !state?.quests?.active?.includes("main_names_they_burned")) {
    throw new Error("Bog core input did not persist the choice and unlock Names They Burned");
  }
  checkpoints.push({ event: "teeth_complete", zone: state.zone, bog_core_fate: "destroyed" });
  return state;
}

async function requireObjective(cdp, questId, objectiveId, label) {
  const state = await freshTelemetry(cdp);
  if (!state?.quests?.objectives_done?.[questId]?.includes(objectiveId)) {
    throw new Error(`${label} did not complete ${questId}/${objectiveId} through real input`);
  }
  return state;
}

async function runOpeningThroughRegister(cdp, url, checkpoints, onStartupReady, resumeAt = "new_game") {
  await runOpeningThroughTeeth(cdp, url, checkpoints, onStartupReady, resumeAt);
  await traverse(cdp, "wychwood", checkpoints);
  await traverse(cdp, "greyfen", checkpoints);
  let state = await freshTelemetry(cdp);
  if (!state?.quests?.active?.includes("main_names_they_burned")) {
    throw new Error("Deep Wood return lost the active Names chapter");
  }
  for (const [id, objective] of [
    ["register_anwen", "fragment_anwen"],
    ["register_tor", "fragment_tor"],
  ]) {
    await useInteraction(cdp, id, checkpoints);
    await requireObjective(cdp, "main_names_they_burned", objective, id);
  }
  await prepareCampaignHealing(cdp, checkpoints);
  for (const zone of ["deep_wood", "old_mill", "burned_farmstead"]) {
    await traverse(cdp, zone, checkpoints);
  }
  await useInteraction(cdp, "register_rook", checkpoints);
  state = await requireObjective(cdp, "main_names_they_burned", "fragment_rook", "Rook's register page");
  if (!state.quests.objectives_done.main_names_they_burned.includes("reconstruct_register")) {
    throw new Error("Three physically collected pages did not reconstruct the register");
  }
  await traverse(cdp, "old_mill", checkpoints);
  state = await freshTelemetry(cdp);
  if (state?.zone !== "old_mill" || !state.quests.objectives_done.main_names_they_burned.includes("reconstruct_register")) {
    throw new Error("Old Mill return lost the reconstructed register");
  }
  checkpoints.push({ event: "register_reconstructed", zone: state.zone, pages: ["anwen", "tor", "rook"] });
  return state;
}

async function prepareCampaignHealing(cdp, checkpoints) {
  let state = await freshTelemetry(cdp);
  if (state?.zone !== "greyfen") throw new Error("Campaign supply preparation requires a real Greyfen return");
  const before = Number(state.inventory?.items?.redroot_potion || 0);
  if (before >= 3) return state;
  if (Number(state.inventory?.ingredients?.redroot || 0) >= 2
    && Number(state.inventory?.ingredients?.bitterleaf || 0) >= 1) {
    await tapGameplayKey(cdp, "Tab", "Tab", 80);
    await waitFor(async () => {
      const current = await freshTelemetry(cdp);
      return current?.ui?.inventory_visible ? current : null;
    }, "preparation menu for carried healing", 5000);
    await chooseMenuButton(cdp, "Craft Redroot Potion");
    state = await waitFor(async () => {
      const current = await freshTelemetry(cdp);
      return Number(current?.inventory?.items?.redroot_potion) === before + 1 ? current : null;
    }, "actual Redroot crafting", 5000);
    await chooseMenuButton(cdp, "Close");
    await waitFor(async () => {
      const current = await freshTelemetry(cdp);
      return !current?.ui?.inventory_visible && current?.player?.can_control ? current : null;
    }, "preparation menu close", 5000);
  }
  if (Number(state.inventory?.items?.redroot_potion || 0) < 3) {
    await driveToInteraction(cdp, "mira_apothecary", checkpoints);
    await tapGameplayKey(cdp, "KeyE", "e", 80);
    state = await waitFor(async () => {
      const current = await freshTelemetry(cdp);
      return current?.ui?.inventory_visible ? current : null;
    }, "Mira's apothecary open", 5000);
    while (Number(state.inventory?.items?.redroot_potion || 0) < 3) {
      const potions = Number(state.inventory.items.redroot_potion || 0);
      const coin = Number(state.inventory.coin || 0);
      if (coin < 6) throw new Error("Earned coin cannot fund the remaining campaign healing");
      await chooseMenuButton(cdp, "Buy Redroot Potion");
      state = await waitFor(async () => {
        const current = await freshTelemetry(cdp);
        return Number(current?.inventory?.items?.redroot_potion) === potions + 1
          && Number(current?.inventory?.coin) === coin - 6 ? current : null;
      }, "Mira's paid potion purchase", 5000);
    }
    await chooseMenuButton(cdp, "Close");
    state = await waitFor(async () => {
      const current = await freshTelemetry(cdp);
      return !current?.ui?.inventory_visible && current?.player?.can_control ? current : null;
    }, "Mira's apothecary close", 5000);
  }
  checkpoints.push({ event: "campaign_healing_prepared", zone: state.zone,
    potions: Number(state.inventory.items.redroot_potion), coin: Number(state.inventory.coin) });
  return state;
}

async function fireAimedArrow(cdp, drawMs = 1100, aimHeld = false) {
  const x = viewport.width * 0.5;
  const y = viewport.height * 0.5;
  try {
    if (!aimHeld) {
      await cdp.send("Page.bringToFront");
      await focusGameCanvas(cdp);
      await cdp.send("Input.dispatchMouseEvent", {
        type: "mousePressed", x, y, button: "right", buttons: 2, clickCount: 1,
      }, INPUT_TIMEOUT_MS);
    }
    await sleep(drawMs);
    try {
      await cdp.send("Input.dispatchMouseEvent", {
        type: "mousePressed", x, y, button: "left", buttons: 3, clickCount: 1,
      }, INPUT_TIMEOUT_MS);
      await sleep(180);
    } finally {
      await cdp.send("Input.dispatchMouseEvent", {
        type: "mouseReleased", x, y, button: "left", buttons: 2, clickCount: 1,
      }, INPUT_TIMEOUT_MS);
    }
  } finally {
    if (!aimHeld) {
      await cdp.send("Input.dispatchMouseEvent", {
        type: "mouseReleased", x, y, button: "right", buttons: 0, clickCount: 1,
      }, INPUT_TIMEOUT_MS).catch(() => {});
    }
  }
}

async function fightRootbound(cdp, checkpoints, timeout = 90000) {
  const started = Date.now();
  let previousHealth = Infinity;
  let lastProgress = started;
  let lastPotion = 0;
  await tapGameplayKey(cdp, "Digit2", "2", 80);
  let state = await waitFor(async () => {
    const current = await freshCombatState(cdp).catch(() => null);
    return current?.player?.weapon_mode === "bow" ? current : null;
  }, "Rootbound bow equip", 5000);
  await cdp.send("Page.bringToFront");
  await focusGameCanvas(cdp);
  try {
  await cdp.send("Input.dispatchMouseEvent", {
    type: "mousePressed", x: viewport.width * 0.5, y: viewport.height * 0.5,
    button: "right", buttons: 2, clickCount: 1,
  }, INPUT_TIMEOUT_MS);
  while (Date.now() - started < timeout) {
    state = await combatTelemetry(cdp);
    if (state?.story?.flags?.rootbound_colossus_defeated) {
      checkpoints.push({ event: "rootbound_defeated", elapsed_ms: Date.now() - started });
      return state;
    }
    if (state?.player?.dead || Number(state?.player?.health) <= 0) throw new Error("Kael died fighting Rootbound");
    const boss = selectActiveEnemy(state, "rootbound_colossus");
    if (!boss) {
      const resolved = await waitFor(async () => {
        const current = await freshCombatState(cdp).catch(() => null);
        return current?.story?.flags?.rootbound_colossus_defeated ? current : null;
      }, "Rootbound defeat publication", 2000).catch(() => null);
      if (resolved) return resolved;
      throw new Error("Rootbound was absent before its defeat flag appeared");
    }
    if (boss.health < previousHealth) {
      previousHealth = boss.health;
      lastProgress = Date.now();
    }
    if (Date.now() - lastProgress > 25000) throw new Error(`Rootbound bow combat stalled at ${boss.health} health`);
    if (state.camera?.locked_target_id !== "rootbound_colossus") {
      await tapGameplayKey(cdp, "KeyT", "t", 80);
      await sleep(300);
      continue;
    }
    if (Number(state.player.health) < 70 && Date.now() - lastPotion > 2000
      && Number(state.inventory?.items?.redroot_potion || 0) > 0) {
      await tapGameplayKey(cdp, "KeyR", "r", 80);
      lastPotion = Date.now();
      continue;
    }
    if (Number(state.inventory?.items?.standard_arrow || 0) <= 0) {
      throw new Error(`Rootbound survived all carried standard arrows at ${boss.health} health`);
    }
    const arrowsBefore = Number(state.inventory.items.standard_arrow);
    // Native holds aim across shots.1.35s includes0.24s recovery plus full draw;
    // do not put DOM focus reads or aim teardown between every physical shot.
    await fireAimedArrow(cdp, 1350, true);
    await waitFor(async () => {
      const after = await freshCombatState(cdp).catch(() => null);
      if (after?.player?.dead || Number(after?.player?.health) <= 0) throw new Error("Kael died fighting Rootbound");
      return after?.story?.flags?.rootbound_colossus_defeated
        || Number(after?.inventory?.items?.standard_arrow ?? arrowsBefore) < arrowsBefore ? after : null;
    }, "Rootbound arrow consumption", 3000);
  }
  throw new Error("Rootbound did not resolve through real bow input");
  } finally {
    await cdp.send("Input.dispatchMouseEvent", {
      type: "mouseReleased", x: viewport.width * 0.5, y: viewport.height * 0.5,
      button: "right", buttons: 0, clickCount: 1,
    }, INPUT_TIMEOUT_MS).catch(() => {});
  }
}

async function runOpeningThroughRootbound(cdp, url, checkpoints, onStartupReady, resumeAt = "new_game") {
  await runOpeningThroughRegister(cdp, url, checkpoints, onStartupReady, resumeAt);
  await traverse(cdp, "deep_wood", checkpoints);
  const arrival = await freshTelemetry(cdp);
  if (arrival?.zone !== "deep_wood" || !arrival?.enemies?.some((enemy) => enemy.id === "rootbound_colossus" && !enemy.dead)) {
    throw new Error("Reconstructed register did not stage Rootbound on Deep Wood return");
  }
  const finalState = await fightRootbound(cdp, checkpoints);
  if (!finalState?.story?.flags?.rootbound_colossus_defeated) {
    throw new Error("Real bow combat did not persist Rootbound defeat");
  }
  return finalState;
}

async function runOpeningThroughNames(cdp, url, checkpoints, onStartupReady, resumeAt = "new_game") {
  await runOpeningThroughRootbound(cdp, url, checkpoints, onStartupReady, resumeAt);
  await traverse(cdp, "wychwood", checkpoints);
  await traverse(cdp, "greyfen", checkpoints);
  const before = await freshTelemetry(cdp);
  if (!before?.quests?.active?.includes("main_names_they_burned")
    || !before?.quests?.objectives_done?.main_names_they_burned?.includes("reconstruct_register")
    || before?.story?.flags?.names_policy) {
    throw new Error("Names decision does not have a genuine unresolved register state");
  }
  await useInteraction(cdp, "names_decision", checkpoints, true, "Publish every recovered name");
  const after = await freshTelemetry(cdp);
  if (after?.story?.flags?.names_policy !== "published"
    || !after?.quests?.completed?.includes("main_names_they_burned")
    || !after?.quests?.active?.includes("main_ash_at_the_mill")) {
    throw new Error("Real Names decision did not persist publication and open Ash at the Mill");
  }
  checkpoints.push({ event: "names_published", zone: after.zone, next_chapter: "main_ash_at_the_mill" });
  return after;
}

async function chooseMenuButton(cdp, labelPrefix) {
  const selected = await waitFor(async () => {
    const current = await freshTelemetry(cdp).catch(() => null);
    const buttons = current?.ui?.buttons || [];
    const matches = buttons.map((button, index) => button.text?.startsWith(labelPrefix) ? index : -1)
      .filter((index) => index >= 0);
    if (matches.length !== 1) return null;
    const focused = buttons.findIndex((button) => button.focused);
    return focused >= 0 ? { buttons, focused, target: matches[0] } : null;
  }, `menu button ${labelPrefix}`, 5000);
  if (!selected.buttons[selected.target].enabled) throw new Error(`Menu button is disabled: ${labelPrefix}`);
  let focused = selected.focused;
  const count = selected.buttons.length;
  for (let step = 0; focused !== selected.target && step < count; step += 1) {
    const down = selected.target > focused;
    await tapKey(cdp, down ? "ArrowDown" : "ArrowUp", down ? "ArrowDown" : "ArrowUp", 70);
    const changed = await waitFor(async () => {
      const current = await freshTelemetry(cdp).catch(() => null);
      const index = (current?.ui?.buttons || []).findIndex((button) => button.focused);
      return index >= 0 && index !== focused ? { index } : null;
    }, `menu focus ${labelPrefix}`, 3000);
    focused = changed.index;
  }
  if (focused !== selected.target) throw new Error(`Menu focus did not reach ${labelPrefix}`);
  const activationStartedMs = Date.now();
  await tapKey(cdp, "Enter", "Enter", 80, true);
  return activationStartedMs;
}

async function readBrowserPersistence(cdp) {
  const response = await cdp.send("Runtime.evaluate", {
    expression: `new Promise((resolve, reject) => {
      const request = indexedDB.open("/userfs");
      request.onupgradeneeded = () => request.transaction.abort();
      request.onerror = () => reject(new Error("Persistent filesystem unavailable"));
      request.onsuccess = () => {
        const db = request.result;
        const files = {};
        const transaction = db.transaction("FILE_DATA", "readonly");
        transaction.oncomplete = () => { db.close(); resolve(files); };
        transaction.onerror = () => { db.close(); reject(transaction.error); };
        const store = transaction.objectStore("FILE_DATA");
        store.getAllKeys().onsuccess = event => {
          for (const name of ["ashen_oath_save.json", "ashen_oath_settings.json"]) {
            const path = event.target.result.find(key => String(key).endsWith("/" + name));
            if (!path) continue;
            store.get(path).onsuccess = entry => {
              try { files[name] = JSON.parse(new TextDecoder().decode(entry.target.result.contents)); }
              catch { files[name] = { invalid_json: true }; }
            };
          }
        };
      };
    })`, returnByValue: true, awaitPromise: true,
  }, 8000);
  if (response.exceptionDetails) throw new Error(response.exceptionDetails.text);
  return response.result.value;
}

function persistedSaveMatches(files, state, savedAfterMs) {
  const saved = files?.["ashen_oath_save.json"];
  const preferences = files?.["ashen_oath_settings.json"];
  const equal = (actual, expected) => {
    if (expected && typeof expected === "object") {
      return actual && Object.keys(expected).every(key => equal(actual[key], expected[key]))
        && Object.keys(actual).length === Object.keys(expected).length;
    }
    return actual === expected;
  };
  return Boolean(saved && preferences
    && typeof saved.saved_at_utc === "string"
    && Date.parse(saved.saved_at_utc.endsWith("Z") ? saved.saved_at_utc : saved.saved_at_utc + "Z") >= savedAfterMs - 1000
    && saved.zone === state.zone
    && Object.entries(state.settings).every(([key, value]) => equal(saved.settings?.[key], value) && equal(preferences[key], value))
    && equal(saved.story_state?.flags, state.story?.flags)
    && equal(saved.inventory?.items, state.inventory?.items)
    && saved.inventory?.coin === state.inventory?.coin
    && equal(Object.keys(saved.quests?.active || {}).sort(), [...state.quests.active].sort())
    && equal(Object.keys(saved.quests?.completed || {}).sort(), [...state.quests.completed].sort()));
}

async function saveThroughPauseMenu(cdp, checkpoints, allowExisting = false) {
  const before = await freshTelemetry(cdp);
  if (before?.saves?.manual && !allowExisting) {
    throw new Error("Manual save already existed before the isolated persistence route");
  }
  await tapGameplayKey(cdp, "Escape", "Escape", 80);
  await waitFor(async () => {
    const current = await freshTelemetry(cdp).catch(() => null);
    return current?.ui?.active_menu === "pause" ? current : null;
  }, "real pause menu", 5000);
  const savedAfterMs = await chooseMenuButton(cdp, "Save");
  const saved = await waitFor(async () => {
    const current = await freshTelemetry(cdp).catch(() => null);
    return current?.saves?.manual ? current : null;
  }, "real pause-menu manual save", 5000);
  // FileAccess closes schedule an asynchronous IndexedDB commit. In-memory
  // existence alone is not proof that a refresh can restore the earned save.
  await waitFor(async () => persistedSaveMatches(await readBrowserPersistence(cdp), saved, savedAfterMs),
    "durable earned manual save and settings", 20000);
  checkpoints.push({ event: allowExisting ? "manual_save_overwritten" : "manual_save_created", zone: saved.zone });
  await tapKey(cdp, "Escape", "Escape", 80, true);
  await waitFor(async () => {
    const current = await freshTelemetry(cdp).catch(() => null);
    return current?.player?.can_control && !current?.paused ? current : null;
  }, "post-save gameplay control", 5000);
}

async function continueSavedOpening(cdp, url, checkpoints, expectedStage = "reported") {
  const resumeUrl = `${url}&resume=${Date.now()}`;
  const navigationStartedMs = Date.now();
  await cdp.send("Page.navigate", { url: resumeUrl });
  await waitFor(async () => cdp.evaluate(
    `location.href.startsWith(${JSON.stringify(resumeUrl)}) && Boolean(document.getElementById("start") && document.querySelector("canvas"))`
  ), "saved page reload", 10000);
  await activateBootShell(cdp);
  await waitFor(async () => cdp.evaluate(`(() => {
    const canvas = document.querySelector("canvas");
    return Boolean(canvas && canvas.width >= 1280 && canvas.height >= 720 && canvas.getContext("webgl2"));
  })()`), "saved WebGL canvas", 20000);
  await waitFor(async () => {
    const current = await freshTelemetry(cdp).catch(() => null);
    return current?.new_game_ready && current?.ui?.active_menu === "main"
      && current?.ui?.buttons?.some((button) => button.text === "Continue" && button.enabled)
      ? current : null;
  }, "enabled Continue after browser reload", 45000);
  const clickStartedMs = await chooseMenuButton(cdp, "Continue");
  const resumed = await waitFor(async () => {
    const current = await freshTelemetry(cdp).catch(() => null);
    return current?.zone === "greyfen" && current?.player?.can_control && !current?.transition_pending
      ? current : null;
  }, "real Continue gameplay control", 15000);
  const controlObservedMs = Date.now();
  cdp.startupRuns ||= [];
  cdp.startupRuns.push({
    kind: "warm_continue",
    navigation_started_ms: navigationStartedMs,
    click_started_ms: clickStartedMs,
    control_observed_ms: controlObservedMs,
    navigation_to_control_ms: controlObservedMs - navigationStartedMs,
    click_to_control_ms: controlObservedMs - clickStartedMs,
    diagnostic_only: false,
  });
  if (expectedStage === "unresolved") {
    if (resumed?.story?.flags?.evidence_report
      || !resumed?.quests?.objectives_done?.main_road_of_crows?.includes("fight_ghoulkin")) {
      throw new Error("Continue lost the unresolved player-earned Road report checkpoint");
    }
  } else if (["widow_active", "iron_active", "returned_soldier_active"].includes(expectedStage)) {
    const side = {
      widow_active: { quest: "side_widows_bell", clue: "find_bell", flag: "widow_truth" },
      iron_active: { quest: "side_iron_remembers", clue: "recover_iron", flag: "iron_fate" },
      returned_soldier_active: { quest: "side_empty_grave", clue: "follow_empty_grave", flag: "returned_soldier_fate" },
    }[expectedStage];
    if (!resumed?.quests?.active?.includes(side.quest)
      || resumed?.quests?.completed?.includes(side.quest)
      || resumed?.quests?.objectives_done?.[side.quest]?.includes(side.clue)
      || resumed?.story?.flags?.[side.flag]) {
      throw new Error(`Continue lost the active pre-clue ${side.quest} checkpoint`);
    }
  } else if (expectedStage === "bitter_roots_collected") {
    if (!resumed?.quests?.active?.includes("side_bitter_roots")
      || resumed?.quests?.completed?.includes("side_bitter_roots")
      || !resumed?.quests?.objectives_done?.side_bitter_roots?.includes("collect_roots")
      || resumed?.story?.flags?.mira_truth) {
      throw new Error("Continue lost the collected, unresolved Bitter Roots checkpoint");
    }
  } else if (expectedStage === "black_dog_investigated") {
    if (!resumed?.quests?.active?.includes("side_black_dog")
      || resumed?.quests?.completed?.includes("side_black_dog")
      || !resumed?.quests?.objectives_done?.side_black_dog?.includes("find_dog")
      || resumed?.story?.flags?.black_dog_fate) {
      throw new Error("Continue lost the investigated, unresolved Black Dog checkpoint");
    }
  } else if (expectedStage === "named_dead_complete") {
    if (!resumed?.quests?.completed?.includes("side_childs_charm")
      || !resumed?.quests?.completed?.includes("side_three_candles")
      || !resumed?.story?.flags?.oren_charm_returned
      || !resumed?.story?.flags?.three_candles_lit) {
      throw new Error("Continue lost the two player-earned named-dead side quests");
    }
  } else if (expectedStage === "rooks_map_compared") {
    if (!resumed?.quests?.active?.includes("side_rooks_map")
      || resumed?.quests?.completed?.includes("side_rooks_map")
      || !resumed?.quests?.objectives_done?.side_rooks_map?.includes("walk_false_road")
      || resumed?.story?.flags?.rook_map_fate) {
      throw new Error("Continue lost the compared, unresolved Rook map checkpoint");
    }
  } else if (expectedStage === "millers_measure_recovered") {
    if (!resumed?.quests?.active?.includes("side_millers_measure")
      || resumed?.quests?.completed?.includes("side_millers_measure")
      || !resumed?.quests?.objectives_done?.side_millers_measure?.includes("weigh_ash")
      || !resumed?.story?.flags?.ash_measure_recovered
      || resumed?.story?.flags?.ash_measure_fate) {
      throw new Error("Continue lost the recovered, unresolved miller's measure checkpoint");
    }
  } else if (expectedStage === "startup") {
    if (!resumed.saves?.manual) throw new Error("Continue lost the earned startup manual save");
  } else if (!resumed?.quests?.completed?.includes("main_road_of_crows")
    || !resumed?.quests?.active?.includes("main_bell_beneath_greyfen")) {
    throw new Error("Continue lost the completed Road of Crows or active Bell chapter");
  }
  checkpoints.push({ event: "opening_continue_restored", zone: resumed.zone, stage: expectedStage });
  return resumed;
}

async function runOpeningReportMatrix(cdp, url, checkpoints, onStartupReady) {
  await runOpeningCampaign(cdp, url, checkpoints, onStartupReady, "");
  await saveThroughPauseMenu(cdp, checkpoints);
  const reports = [
    { interaction: "sister_anwen", outcome: "private" },
    { interaction: "notice_board", outcome: "public" },
    { interaction: "retain_evidence", outcome: "retained" },
  ];
  let finalState = null;
  for (const [index, report] of reports.entries()) {
    if (index > 0) await continueSavedOpening(cdp, url, checkpoints, "unresolved");
    await useInteraction(cdp, report.interaction, checkpoints, true);
    finalState = await freshTelemetry(cdp);
    if (finalState?.story?.flags?.evidence_report !== report.outcome
      || !finalState?.quests?.completed?.includes("main_road_of_crows")
      || !finalState?.quests?.active?.includes("main_bell_beneath_greyfen")) {
      throw new Error(`Real ${report.outcome} report did not advance Road of Crows and Bell Beneath Greyfen`);
    }
    checkpoints.push({ event: "road_report_choice_completed", outcome: report.outcome, zone: finalState.zone });
  }
  return finalState;
}

async function runOpeningWidowMatrix(cdp, url, checkpoints, onStartupReady) {
  await runOpeningCampaign(cdp, url, checkpoints, onStartupReady);
  await useInteraction(cdp, "widow_elna", checkpoints, true, "Accept A Widow's Bell");
  const active = await freshTelemetry(cdp);
  if (!active?.quests?.active?.includes("side_widows_bell")
    || active?.quests?.objectives_done?.side_widows_bell?.includes("find_bell")
    || active?.story?.flags?.widow_truth) {
    throw new Error("Elna's real dialogue did not establish the pre-clue Widow's Bell state");
  }
  await saveThroughPauseMenu(cdp, checkpoints);
  const choices = [
    { label: "He was calling for a witness.", outcome: "told" },
    { label: "The wind caught an old cord.", outcome: "comforted" },
  ];
  let finalState = null;
  for (const [index, choice] of choices.entries()) {
    if (index > 0) await continueSavedOpening(cdp, url, checkpoints, "widow_active");
    await useInteraction(cdp, "grave_bell", checkpoints);
    const clueState = await freshTelemetry(cdp);
    if (!clueState?.quests?.objectives_done?.side_widows_bell?.includes("find_bell")) {
      throw new Error("Real grave bell interaction did not reveal Harl's clue");
    }
    await useInteraction(cdp, "widow_elna", checkpoints, true, choice.label);
    finalState = await freshTelemetry(cdp);
    if (!finalState?.quests?.completed?.includes("side_widows_bell")
      || finalState?.story?.flags?.widow_truth !== choice.outcome) {
      throw new Error(`Real Widow's Bell ${choice.outcome} choice did not persist in the current state`);
    }
    checkpoints.push({ event: "widow_choice_completed", outcome: choice.outcome, zone: finalState.zone });
  }
  return finalState;
}

async function runGreyfenSideMatrix(cdp, url, checkpoints, onStartupReady, spec) {
  await runOpeningCampaign(cdp, url, checkpoints, onStartupReady);
  await useInteraction(cdp, spec.contractInteraction, checkpoints, true, spec.contractLabel);
  const active = await freshTelemetry(cdp);
  if (!active?.quests?.active?.includes(spec.quest)
    || active?.quests?.objectives_done?.[spec.quest]?.includes(spec.clueObjective)
    || active?.story?.flags?.[spec.outcomeFlag]) {
    throw new Error(`Real contract did not establish the pre-clue ${spec.quest} state`);
  }
  await saveThroughPauseMenu(cdp, checkpoints);
  let finalState = null;
  for (const [index, choice] of spec.choices.entries()) {
    if (index > 0) await continueSavedOpening(cdp, url, checkpoints, spec.checkpointStage);
    await useInteraction(cdp, spec.clueInteraction, checkpoints);
    const clueState = await freshTelemetry(cdp);
    if (!clueState?.quests?.objectives_done?.[spec.quest]?.includes(spec.clueObjective)) {
      throw new Error(`Real ${spec.clueInteraction} interaction did not complete ${spec.clueObjective}`);
    }
    await useInteraction(cdp, spec.resolutionInteraction, checkpoints, true, choice.label);
    finalState = await freshTelemetry(cdp);
    if (!finalState?.quests?.completed?.includes(spec.quest)
      || finalState?.story?.flags?.[spec.outcomeFlag] !== choice.outcome) {
      throw new Error(`Real ${spec.quest} ${choice.outcome} choice did not persist in the current state`);
    }
    checkpoints.push({ event: "greyfen_side_choice_completed", quest: spec.quest, outcome: choice.outcome, zone: finalState.zone });
  }
  return finalState;
}

async function runBitterRootsMatrix(cdp, url, checkpoints, onStartupReady) {
  await runOpeningCampaign(cdp, url, checkpoints, onStartupReady);
  await useInteraction(cdp, "side_contracts", checkpoints, true, "Bitter Roots");
  const active = await freshTelemetry(cdp);
  if (!active?.quests?.active?.includes("side_bitter_roots")) {
    throw new Error("The real village request board did not start Bitter Roots");
  }
  await traverse(cdp, "wychwood", checkpoints);
  await useInteraction(cdp, "bitter_roots", checkpoints);
  const collected = await freshTelemetry(cdp);
  if (!collected?.quests?.objectives_done?.side_bitter_roots?.includes("collect_roots")) {
    throw new Error("Real Wychwood root interaction did not complete collection");
  }
  await traverse(cdp, "greyfen", checkpoints);
  await saveThroughPauseMenu(cdp, checkpoints);
  const choices = [
    { label: "Greyfen deserves the truth", outcome: "confessed" },
    { label: "Keep the truth between us", outcome: "kept" },
  ];
  let finalState = null;
  for (const [index, choice] of choices.entries()) {
    if (index > 0) await continueSavedOpening(cdp, url, checkpoints, "bitter_roots_collected");
    await useInteraction(cdp, "mira", checkpoints, true, choice.label);
    finalState = await freshTelemetry(cdp);
    if (!finalState?.quests?.completed?.includes("side_bitter_roots")
      || finalState?.story?.flags?.mira_truth !== choice.outcome) {
      throw new Error(`Real Bitter Roots ${choice.outcome} choice did not persist in the current state`);
    }
    checkpoints.push({ event: "bitter_roots_choice_completed", outcome: choice.outcome, zone: finalState.zone });
  }
  return finalState;
}

async function fightBlackDogBandits(cdp, checkpoints, timeout = 90000) {
  const started = Date.now();
  let lockedTargetIndex = -1;
  let lastPotion = 0;
  let observedBandits = 0;
  while (Date.now() - started < timeout) {
    const state = await combatTelemetry(cdp);
    if (state?.player?.dead || Number(state?.player?.health) <= 0) {
      throw new Error("Kael died during the Black Dog bandit encounter");
    }
    const living = (state?.enemies || []).filter((enemy) => enemy?.id === "bandit"
      && enemy.active && Number(enemy.health) > 0 && enemy.position);
    observedBandits = Math.max(observedBandits, living.length);
    if (state?.quests?.objectives_done?.side_black_dog?.includes("find_dog")) {
      if (observedBandits !== 2 || living.length) {
        throw new Error("Black Dog investigation completed without two staged bandits being defeated");
      }
      checkpoints.push({ event: "black_dog_bandits_defeated", count: observedBandits });
      return;
    }
    if (!living.length) {
      await sleep(150);
      continue;
    }
    const target = living[0];
    const targetIndex = state.enemies.indexOf(target);
    if (targetIndex !== lockedTargetIndex) {
      await tapGameplayKey(cdp, "KeyT", "t", 80);
      lockedTargetIndex = targetIndex;
      await sleep(400);
      continue;
    }
    const player = state.player?.position;
    if (!player) throw new Error("No player position during Black Dog combat");
    const distance = Math.hypot(target.position.x - player.x, target.position.z - player.z);
    if (distance > 2.84) {
      await approachMovingEnemy(cdp, 2.84, 5000, "bandit");
    } else if (!await attackLiveTarget(cdp, 2.84, "bandit")) {
      lockedTargetIndex = -1;
    }
    if (Number(state.player.health) < 65 && Date.now() - lastPotion > 6000) {
      await tapGameplayKey(cdp, "KeyR", "r", 80);
      lastPotion = Date.now();
    }
  }
  throw new Error("Black Dog bandits did not fall through real combat input");
}

async function runBlackDogMatrix(cdp, url, checkpoints, onStartupReady) {
  await runOpeningCampaign(cdp, url, checkpoints, onStartupReady);
  await useInteraction(cdp, "side_contracts", checkpoints, true, "The Black Dog Contract");
  const active = await freshTelemetry(cdp);
  if (!active?.quests?.active?.includes("side_black_dog")) {
    throw new Error("Real village request board did not start The Black Dog Contract");
  }
  await useInteraction(cdp, "sheepfold", checkpoints);
  const sheepfold = await freshTelemetry(cdp);
  if (!sheepfold?.story?.flags?.black_dog_sheepfold_inspected
    || sheepfold?.quests?.objectives_done?.side_black_dog?.includes("find_dog")) {
    throw new Error("Real sheepfold clue did not establish incomplete Black Dog evidence");
  }
  await traverse(cdp, "wychwood", checkpoints);
  await useInteraction(cdp, "bandit_camp", checkpoints);
  const camp = await freshTelemetry(cdp);
  if (!camp?.story?.flags?.black_dog_bandit_camp_inspected
    || camp?.quests?.objectives_done?.side_black_dog?.includes("find_dog")) {
    throw new Error("Real bandit camp clue did not leave the fight unresolved");
  }
  await fightBlackDogBandits(cdp, checkpoints);
  await traverse(cdp, "greyfen", checkpoints);
  const investigated = await freshTelemetry(cdp);
  if (!investigated?.quests?.objectives_done?.side_black_dog?.includes("find_dog")
    || investigated?.story?.flags?.black_dog_fate) {
    throw new Error("Real Black Dog evidence was not ready for Toma's report");
  }
  await saveThroughPauseMenu(cdp, checkpoints);
  const choices = [
    { label: "The guardian protected the children", outcome: "spared" },
    { label: "Tell them it fled", outcome: "hidden" },
  ];
  let finalState = null;
  for (const [index, choice] of choices.entries()) {
    if (index > 0) await continueSavedOpening(cdp, url, checkpoints, "black_dog_investigated");
    await useInteraction(cdp, "farmer_toma", checkpoints, true, choice.label);
    finalState = await freshTelemetry(cdp);
    if (!finalState?.quests?.completed?.includes("side_black_dog")
      || finalState?.story?.flags?.black_dog_fate !== choice.outcome) {
      throw new Error(`Real Black Dog ${choice.outcome} choice did not persist in the current state`);
    }
    checkpoints.push({ event: "black_dog_choice_completed", outcome: choice.outcome, zone: finalState.zone });
  }
  return finalState;
}

async function runNamedDeadSideRoute(cdp, url, checkpoints, onStartupReady) {
  await runOpeningThroughBellEater(cdp, url, checkpoints, onStartupReady);
  await useInteraction(cdp, "mira", checkpoints, true, "I will read the chapel register");
  await useInteraction(cdp, "chapel_names", checkpoints);
  const chapel = await freshTelemetry(cdp);
  if (!chapel?.story?.flags?.chapel_names_read
    || !chapel?.story?.flags?.road_evidence_bram
    || !chapel?.story?.flags?.road_evidence_sella) {
    throw new Error("Named-dead route lacks the player-earned chapel and victim evidence");
  }
  await traverse(cdp, "wychwood", checkpoints);
  await useInteraction(cdp, "ritual_stones", checkpoints);
  const named = await freshTelemetry(cdp);
  if (!named?.story?.flags?.oren_name_spoken) {
    throw new Error("Real ritual-stone interaction did not speak Oren's name");
  }
  await traverse(cdp, "greyfen", checkpoints);
  await useInteraction(cdp, "side_contracts", checkpoints, true, "Oren's Red Thread");
  const thread = await freshTelemetry(cdp);
  if (!thread?.quests?.active?.includes("side_childs_charm")
    || !thread?.quests?.objectives_done?.side_childs_charm?.includes("trace_thread")) {
    throw new Error("Real Red Thread request did not recognize the earned evidence");
  }
  await useInteraction(cdp, "oren_charm_shrine", checkpoints);
  const returned = await freshTelemetry(cdp);
  if (!returned?.quests?.completed?.includes("side_childs_charm")
    || !returned?.story?.flags?.oren_charm_returned) {
    throw new Error("Real charm placement did not complete Oren's Red Thread");
  }
  await useInteraction(cdp, "side_contracts", checkpoints, true, "Three Candles Unlit");
  const candles = await freshTelemetry(cdp);
  if (!candles?.quests?.active?.includes("side_three_candles")) {
    throw new Error("Real request board did not start Three Candles Unlit");
  }
  for (const victim of ["bram", "sella", "oren"]) {
    await useInteraction(cdp, `memorial_candle_${victim}`, checkpoints);
    const lit = await freshTelemetry(cdp);
    if (!lit?.story?.flags?.[`candle_${victim}_lit`]
      || (!lit?.quests?.objectives_done?.side_three_candles?.includes(`light_${victim}`)
        && !lit?.quests?.completed?.includes("side_three_candles"))) {
      throw new Error(`Real memorial interaction did not light ${victim}'s candle`);
    }
    checkpoints.push({ event: "named_candle_lit", victim, zone: lit.zone });
  }
  const finalState = await freshTelemetry(cdp);
  if (!finalState?.quests?.completed?.includes("side_three_candles")
    || !finalState?.story?.flags?.three_candles_lit) {
    throw new Error("Three real memorial interactions did not complete the named-dead quest");
  }
  await saveThroughPauseMenu(cdp, checkpoints);
  const restored = await continueSavedOpening(cdp, url, checkpoints, "named_dead_complete");
  checkpoints.push({ event: "named_dead_side_quests_restored", zone: restored.zone });
  return restored;
}

async function runRooksMapMatrix(cdp, url, checkpoints, onStartupReady) {
  await runOpeningCampaign(cdp, url, checkpoints, onStartupReady);
  await useInteraction(cdp, "side_contracts", checkpoints, true, "The Road That Bends");
  const active = await freshTelemetry(cdp);
  if (!active?.quests?.active?.includes("side_rooks_map")
    || active?.quests?.objectives_done?.side_rooks_map?.includes("walk_false_road")) {
    throw new Error("Rook's board contract did not establish an unresolved map quest");
  }
  for (const zone of ["wychwood", "deep_wood"]) await traverse(cdp, zone, checkpoints);
  await useInteraction(cdp, "rooks_false_road", checkpoints);
  const compared = await freshTelemetry(cdp);
  if (compared?.zone !== "deep_wood"
    || !compared?.quests?.objectives_done?.side_rooks_map?.includes("walk_false_road")) {
    throw new Error("The focused false-road waystone did not advance Rook's quest");
  }
  for (const zone of ["wychwood", "greyfen"]) await traverse(cdp, zone, checkpoints);
  await saveThroughPauseMenu(cdp, checkpoints);
  const choices = [
    { label: "Keep the older road on the map", outcome: "preserved" },
    { label: "Destroy the map before Vargan can use it", outcome: "destroyed" },
  ];
  let finalState = null;
  for (const [index, choice] of choices.entries()) {
    if (index > 0) await continueSavedOpening(cdp, url, checkpoints, "rooks_map_compared");
    await useInteraction(cdp, "rook", checkpoints, true, choice.label);
    finalState = await freshTelemetry(cdp);
    if (!finalState?.quests?.completed?.includes("side_rooks_map")
      || finalState?.story?.flags?.rook_map_fate !== choice.outcome) {
      throw new Error(`Real Rook map ${choice.outcome} choice did not persist`);
    }
    checkpoints.push({ event: "rooks_map_choice_completed", outcome: choice.outcome, zone: finalState.zone });
  }
  return finalState;
}

async function runMillersMeasureMatrix(cdp, url, checkpoints, onStartupReady) {
  await runOpeningCampaign(cdp, url, checkpoints, onStartupReady);
  await useInteraction(cdp, "side_contracts", checkpoints, true, "A Measure of Ash");
  const active = await freshTelemetry(cdp);
  if (!active?.quests?.active?.includes("side_millers_measure")
    || active?.quests?.objectives_done?.side_millers_measure?.includes("weigh_ash")) {
    throw new Error("The miller's board contract did not establish unresolved evidence");
  }
  for (const zone of ["wychwood", "deep_wood", "old_mill"]) await traverse(cdp, zone, checkpoints);
  await useInteraction(cdp, "hidden_ash_measure", checkpoints);
  const recovered = await freshTelemetry(cdp);
  if (recovered?.zone !== "old_mill"
    || !recovered?.quests?.objectives_done?.side_millers_measure?.includes("weigh_ash")
    || !recovered?.story?.flags?.ash_measure_recovered) {
    throw new Error("The focused Old Mill measure did not persist its evidence");
  }
  for (const zone of ["deep_wood", "wychwood", "greyfen"]) await traverse(cdp, zone, checkpoints);
  await saveThroughPauseMenu(cdp, checkpoints);
  const choices = [
    { actor: "farmer_toma", label: "Show the farmer what the mill weighed", outcome: "farmer" },
    { actor: "mira", label: "Use the miller's measure to treat the sick", outcome: "healer" },
  ];
  let finalState = null;
  for (const [index, choice] of choices.entries()) {
    if (index > 0) await continueSavedOpening(cdp, url, checkpoints, "millers_measure_recovered");
    await useInteraction(cdp, choice.actor, checkpoints, true, choice.label);
    finalState = await freshTelemetry(cdp);
    if (!finalState?.quests?.completed?.includes("side_millers_measure")
      || finalState?.story?.flags?.ash_measure_fate !== choice.outcome) {
      throw new Error(`Real miller's measure ${choice.outcome} choice did not persist`);
    }
    checkpoints.push({ event: "millers_measure_choice_completed", outcome: choice.outcome, zone: finalState.zone });
  }
  await continueSavedOpening(cdp, url, checkpoints, "millers_measure_recovered");
  return recordAssemblySideOutcome(cdp, url, checkpoints, onStartupReady, {
    resumeAt: "greyfen_measure", quest: "side_millers_measure", clue: "weigh_ash",
    flag: "ash_measure_fate", label: "Place the miller's measure before the assembly",
  });
}

const GREYFEN_SIDE_MATRIX = {
  iron: {
    quest: "side_iron_remembers", checkpointStage: "iron_active",
    contractInteraction: "side_contracts", contractLabel: "Iron Remembers",
    clueInteraction: "massacre_iron", clueObjective: "recover_iron",
    resolutionInteraction: "blacksmith_tor", outcomeFlag: "iron_fate",
    choices: [
      { label: "Forge the victims' names", outcome: "memorial" },
      { label: "Forge it into a weapon", outcome: "weapon" },
    ],
  },
  returned_soldier: {
    quest: "side_empty_grave", checkpointStage: "returned_soldier_active",
    contractInteraction: "side_contracts", contractLabel: "The Man Who Walked Home",
    clueInteraction: "empty_grave_tracks", clueObjective: "follow_empty_grave",
    resolutionInteraction: "returned_soldier", outcomeFlag: "returned_soldier_fate",
    choices: [
      { label: "Your name belongs among the witnesses", outcome: "named" },
      { label: "Keep the name. Leave the grave empty", outcome: "anonymous" },
    ],
  },
};

async function runOpeningSaveContinue(cdp, url, checkpoints, onStartupReady) {
  const original = await runOpeningCampaign(cdp, url, checkpoints, onStartupReady);
  if (!original?.quests?.completed?.includes("main_road_of_crows")) {
    throw new Error("Opening route did not earn its save checkpoint");
  }
  const changed = await exerciseBrowserSettings(cdp, checkpoints);
  await saveThroughPauseMenu(cdp, checkpoints);
  const resumed = await continueSavedOpening(cdp, url, checkpoints);
  for (const key of ["master_volume", "subtitle_scale", "reduced_motion"]) {
    if (resumed.settings?.[key] !== changed.settings[key]) throw new Error(`Browser ${key} did not persist after Continue`);
  }
  if (JSON.stringify(resumed.settings?.custom_bindings?.interact) !== changed.interactBinding
    || resumed.audio?.muted || !resumed.audio?.music_playing
    || Math.abs(Number(resumed.audio?.master_db) - 20 * Math.log10(changed.settings.master_volume)) > 0.15) {
    throw new Error("Browser remapping/audio settings did not persist after Continue");
  }
  checkpoints.push({ event: "browser_settings_persisted", settings: changed.settings });
  await useInteraction(cdp, "sister_anwen", checkpoints, true, "", true, ["F9", "F9"]);
  checkpoints.push({ event: "browser_remapped_interaction", id: "sister_anwen", key: "F9" });
  await exerciseBrowserSettings(cdp, checkpoints, changed.original);
  return freshTelemetry(cdp);
}

async function runBrowserSmoke(cdp, url, checkpoints, onStartupReady) {
  const initial = await startNewGame(cdp, `${url}&scenario=compatibility-smoke-${Date.now()}`, onStartupReady);
  checkpoints.push({ event: "scenario_start", scenario: "compatibility-smoke", zone: initial.zone });
  await tapGameplayKey(cdp, "KeyW", "w", 250);
  const moved = await freshTelemetry(cdp);
  const distance = Math.hypot(moved.player.position.x - initial.player.position.x,
    moved.player.position.z - initial.player.position.z);
  if (distance < 0.10) throw new Error("Ordinary keyboard movement did not move Kael");
  checkpoints.push({ event: "browser_keyboard_movement", distance });
  await saveThroughPauseMenu(cdp, checkpoints);
  const earned = await freshTelemetry(cdp);
  const resumed = await continueSavedOpening(cdp, url, checkpoints, "startup");
  for (const key of ["settings", "inventory"]) {
    if (JSON.stringify(resumed[key]) !== JSON.stringify(earned[key])) {
      throw new Error(`Continue changed earned ${key}`);
    }
  }
  if (JSON.stringify(resumed.story?.flags) !== JSON.stringify(earned.story?.flags)
    || JSON.stringify(resumed.quests?.active) !== JSON.stringify(earned.quests?.active)
    || JSON.stringify(resumed.quests?.completed) !== JSON.stringify(earned.quests?.completed)
    || Math.hypot(resumed.player.position.x - earned.player.position.x,
      resumed.player.position.z - earned.player.position.z) > 0.15) {
    throw new Error("Continue changed the earned story or location");
  }
  checkpoints.push({ event: "browser_save_durable", zone: resumed.zone });
  await tapGameplayKey(cdp, "KeyS", "s", 250);
  const final = await freshTelemetry(cdp);
  if (Math.hypot(final.player.position.x - resumed.player.position.x,
    final.player.position.z - resumed.player.position.z) < 0.10) {
    throw new Error("Continue did not restore keyboard control");
  }
  checkpoints.push({ event: "browser_continue_input", zone: final.zone });
  return final;
}

async function exerciseBrowserSettings(cdp, checkpoints, restore = null) {
  const before = await freshTelemetry(cdp);
  await tapGameplayKey(cdp, "Escape", "Escape", 80);
  const paused = await waitFor(async () => {
    const state = await freshTelemetry(cdp).catch(() => null);
    return state?.paused && state.ui?.active_menu === "pause" ? state : null;
  }, "browser settings pause", 5000);
  await tapKey(cdp, "KeyW", "w", 250);
  const stopped = await freshTelemetry(cdp);
  if (Math.hypot(stopped.player.position.x - paused.player.position.x,
    stopped.player.position.z - paused.player.position.z) > 0.10) throw new Error("Pause allowed gameplay movement");
  if (!restore) checkpoints.push({ event: "browser_pause_input_blocked" });
  await chooseMenuButton(cdp, "Settings");
  await waitFor(async () => {
    const state = await freshTelemetry(cdp).catch(() => null);
    const buttons = state?.ui?.buttons || [];
    return state?.ui?.active_menu === "settings"
      && buttons.some(button => button.text === "Next Page")
      && buttons.some(button => button.text === "Previous Page")
      && buttons.some(button => button.focused && button.text !== "Settings") ? state : null;
  }, "settings controls published after pause", 5000);
  const cycleSetting = async (label, key, maximum) => {
    for (let count = 0; count < maximum; count += 1) {
      const previous = (await freshTelemetry(cdp)).settings[key];
      if (restore && previous === restore[key]) return;
      await chooseMenuButton(cdp, label);
      const changed = await waitFor(async () => {
        const state = await freshTelemetry(cdp).catch(() => null);
        return state?.settings?.[key] !== previous ? state : null;
      }, `${label} changed through UI`, 5000);
      if (!restore) return changed;
    }
    if ((await freshTelemetry(cdp)).settings[key] !== restore[key]) throw new Error(`${label} defaults not restored`);
  };
  // Settings remembers its last page. Navigate by actual reachable controls.
  const changeSettingsPage = async (state, label) => {
    const previous = state.ui.buttons.map(button => button.text).join("\n");
    await chooseMenuButton(cdp, label);
    return waitFor(async () => {
      const current = await freshTelemetry(cdp).catch(() => null);
      const buttons = current?.ui?.buttons || [];
      return current?.ui?.active_menu === "settings"
        && new Set(buttons.map(button => button.text)).size === buttons.length
        && buttons.some(button => button.focused)
        && buttons.map(button => button.text).join("\n") !== previous ? current : null;
    }, `settings ${label} publication`, 5000);
  };
  for (let page = 0; page < 3; page += 1) {
    const state = await freshTelemetry(cdp);
    if (state.ui.buttons.some(button => button.text.startsWith("Master Volume"))) break;
    const next = state.ui.buttons.find(button => button.text === "Next Page");
    await changeSettingsPage(state, next?.enabled ? "Next Page" : "Previous Page");
  }
  await cycleSetting("Master Volume", "master_volume", 5);
  await changeSettingsPage(await freshTelemetry(cdp), "Next Page");
  await cycleSetting("Subtitle Size", "subtitle_scale", 3);
  await cycleSetting("Reduced Motion", "reduced_motion", 2);
  if (!restore) {
    for (const size of [{ width: 1920, height: 1080 }, { width: 1280, height: 720 }]) {
      Object.assign(viewport, size);
      await cdp.send("Emulation.setDeviceMetricsOverride", { ...size, deviceScaleFactor: 1, mobile: false });
      await sleep(180);
      const state = await freshTelemetry(cdp);
      const logical = state.ui?.viewport;
      const focused = state.ui?.buttons?.find(button => button.focused);
      if (!focused || !logical || focused.position.x < 0 || focused.position.y < 0
        || focused.position.x + focused.size.x > logical.x + 1
        || focused.position.y + focused.size.y > logical.y + 1) throw new Error("Resized settings lost reachable keyboard focus");
      checkpoints.push({ event: "browser_menu_resize", ...size, focused: focused.text });
    }
  }
  await chooseMenuButton(cdp, "Back");
  await chooseMenuButton(cdp, "Controls");
  await chooseMenuButton(cdp, "Customize Controls");
  if (restore) {
    await chooseMenuButton(cdp, "Reset Defaults");
    await waitFor(async () => {
      const state = await freshTelemetry(cdp).catch(() => null);
      return state && Object.keys(state.settings?.custom_bindings || {}).length === 0 ? state : null;
    }, "browser default bindings", 5000);
  } else {
    await chooseMenuButton(cdp, "Interact");
    await tapKey(cdp, "F9", "F9", 80);
    await waitFor(async () => {
      const state = await freshTelemetry(cdp).catch(() => null);
      return state?.ui?.buttons?.some(button => button.text.startsWith("Interact") && button.text.includes("F9"))
        && state.settings?.custom_bindings?.interact?.length ? state : null;
    }, "browser F9 interaction binding", 5000);
  }
  await chooseMenuButton(cdp, "Back");
  await chooseMenuButton(cdp, "Resume");
  const result = await waitFor(async () => {
    const state = await freshTelemetry(cdp).catch(() => null);
    return state?.player?.can_control && !state.paused ? state : null;
  }, "browser settings resume", 5000);
  if (restore) {
    for (const key of ["master_volume", "subtitle_scale", "reduced_motion", "quality_preset"]) {
      if (result.settings[key] !== restore[key]) throw new Error(`Default presentation changed: ${key}`);
    }
    checkpoints.push({ event: "browser_defaults_restored" });
    return result;
  }
  const settings = Object.fromEntries(["master_volume", "subtitle_scale", "reduced_motion"].map(key => [key, result.settings[key]]));
  if (settings.master_volume <= 0 || result.audio?.muted || !result.audio?.music_playing
    || result.settings.quality_preset !== before.settings.quality_preset) throw new Error("Settings lost audible mix or default quality");
  checkpoints.push({ event: "browser_settings_changed", settings });
  return { settings, interactBinding: JSON.stringify(result.settings.custom_bindings.interact), original: before.settings };
}

async function runOpeningThroughAshPreparation(cdp, url, checkpoints, onStartupReady, resumeAt = "new_game") {
  await runOpeningThroughNames(cdp, url, checkpoints, onStartupReady, resumeAt);
  await prepareCampaignHealing(cdp, checkpoints);
  await driveToInteraction(cdp, "tor_forge", checkpoints);
  await tapGameplayKey(cdp, "KeyE", "e", 80);
  const opened = await waitFor(async () => {
    const current = await freshTelemetry(cdp).catch(() => null);
    return current?.ui?.inventory_visible ? current : null;
  }, "Tor's forge vendor open", 5000);
  const startingArrows = Number(opened.inventory?.items?.standard_arrow || 0);
  const startingCoin = Number(opened.inventory?.coin || 0);
  if (startingArrows < 0 || startingArrows > 24 || startingCoin < 0) {
    throw new Error("Tor's vendor opened with invalid carried arrow or coin bounds");
  }
  if (startingArrows < 5) {
    await chooseMenuButton(cdp, "Claim Tor's free emergency arrows");
    await waitFor(async () => {
      const current = await freshTelemetry(cdp).catch(() => null);
      return Number(current?.inventory?.items?.standard_arrow) === 5
        && Number(current?.inventory?.coin) === startingCoin ? current : null;
    }, "Tor's free emergency refill", 5000);
  }
  const refilled = Math.max(5, startingArrows);
  const purchases = Math.max(0, 20 - refilled);
  if (startingCoin < purchases) throw new Error(`Campaign coin ${startingCoin} cannot fund ${purchases} standard arrows`);
  for (let purchased = 0; purchased < purchases; purchased += 1) {
    await chooseMenuButton(cdp, "Buy Standard Arrow");
    await waitFor(async () => {
      const current = await freshTelemetry(cdp).catch(() => null);
      return Number(current?.inventory?.items?.standard_arrow) === refilled + purchased + 1
        && Number(current?.inventory?.coin) === startingCoin - purchased - 1 ? current : null;
    }, `Tor arrow purchase ${purchased + 1}`, 5000);
  }
  await chooseMenuButton(cdp, "Close");
  const closed = await waitFor(async () => {
    const current = await freshTelemetry(cdp).catch(() => null);
    return !current?.ui?.inventory_visible && current?.player?.can_control ? current : null;
  }, "Tor's shop close", 5000);
  const expectedArrows = refilled + purchases;
  if (Number(closed.inventory?.items?.standard_arrow) !== expectedArrows) {
    throw new Error("Tor shop close changed carried ammunition");
  }
  await traverse(cdp, "deep_wood", checkpoints);
  await traverse(cdp, "old_mill", checkpoints);
  const arrived = await requireObjective(cdp, "main_ash_at_the_mill", "reach_mill", "Physical Old Mill arrival");
  if (arrived?.zone !== "old_mill" || Number(arrived.inventory?.items?.standard_arrow) !== expectedArrows) {
    throw new Error("Old Mill arrival lost Tor's purchased ammunition");
  }
  checkpoints.push({ event: "ash_mill_prepared", zone: arrived.zone, arrows: expectedArrows, coin_spent: purchases });
  return arrived;
}

async function fightAshMillPack(cdp, checkpoints, timeout = 90000) {
  await tapGameplayKey(cdp, "Digit1", "1", 80);
  await waitFor(async () => {
    const state = await freshCombatState(cdp).catch(() => null);
    return state?.player?.weapon_mode === "sword" ? state : null;
  }, "mill sword equip", 5000);
  const started = Date.now();
  let lastDamage = started;
  let lastHealth = Infinity;
  let lastPotion = 0;
  while (Date.now() - started < timeout) {
    const state = await combatTelemetry(cdp);
    if (state?.quests?.objectives_done?.main_ash_at_the_mill?.includes("mill_encounter")) {
      if (!state?.story?.flags?.ashwing_spawned
        || !state?.enemies?.some((enemy) => enemy.id === "ashwing" && !enemy.dead)) {
        throw new Error("Mill victory did not stage living Ashwing");
      }
      checkpoints.push({ event: "ash_mill_cleared", elapsed_ms: Date.now() - started });
      return state;
    }
    if (state?.player?.dead || Number(state?.player?.health) <= 0) throw new Error("Kael died clearing the mill");
    const enemy = selectActiveEnemy(state, "ghoulkin");
    if (!enemy) {
      await sleep(180);
      continue;
    }
    if (enemy.health > lastHealth + 1) {
      lastHealth = enemy.health;
      lastDamage = Date.now();
    } else if (enemy.health < lastHealth) {
      lastHealth = enemy.health;
      lastDamage = Date.now();
    }
    if (Date.now() - lastDamage > 22000) throw new Error(`Ash mill combat stalled at ${enemy.health} health`);
    const locked = state.camera?.locked_target_position;
    if (state.camera?.locked_target_id !== "ghoulkin" || !locked
      || Math.hypot(locked.x - enemy.position.x, locked.z - enemy.position.z) > 0.6) {
      await tapGameplayKey(cdp, "KeyT", "t", 80);
      await sleep(280);
      continue;
    }
    if (Number(state.player.health) < 65 && Date.now() - lastPotion > 6000
      && Number(state.inventory?.items?.redroot_potion || 0) > 0) {
      await tapGameplayKey(cdp, "KeyR", "r", 80);
      lastPotion = Date.now();
      continue;
    }
    const distance = Math.hypot(
      enemy.position.x - state.player.position.x,
      enemy.position.z - state.player.position.z,
    );
    if (distance > 2.84) await approachMovingEnemy(cdp, 2.84, 5000, "ghoulkin");
    else await attackLiveTarget(cdp, 2.84, "ghoulkin");
    await sleep(300);
  }
  throw new Error("Ash mill Ghoulkin did not resolve through real combat input");
}

async function fightAshwing(cdp, checkpoints, timeout = 90000) {
  const started = Date.now();
  let lastDamage = started;
  let lastHealth = Infinity;
  let lastPotion = 0;
  let oathfireUsed = false;
  while (Date.now() - started < timeout) {
    const state = await combatTelemetry(cdp);
    if (state?.story?.flags?.ashwing_defeated) {
      checkpoints.push({ event: "ashwing_defeated", elapsed_ms: Date.now() - started });
      return state;
    }
    if (state?.player?.dead || Number(state?.player?.health) <= 0) throw new Error("Kael died fighting Ashwing");
    const boss = selectActiveEnemy(state, "ashwing");
    if (!boss) throw new Error("Ashwing disappeared without its defeat flag");
    if (boss.health < lastHealth) {
      lastHealth = boss.health;
      lastDamage = Date.now();
    }
    if (Date.now() - lastDamage > 25000) throw new Error(`Ashwing combat stalled at ${boss.health} health`);
    if (state.camera?.locked_target_id !== "ashwing") {
      await tapGameplayKey(cdp, "KeyT", "t", 80);
      await sleep(300);
      continue;
    }
    if (!oathfireUsed) {
      await tapGameplayKey(cdp, "KeyC", "c", 1700);
      oathfireUsed = true;
      checkpoints.push({ event: "ashwing_oathfire_input" });
      await sleep(350);
      await tapGameplayKey(cdp, "Digit2", "2", 80);
      await waitFor(async () => {
        const equipped = await freshCombatState(cdp).catch(() => null);
        return equipped?.player?.weapon_mode === "bow" ? equipped : null;
      }, "Ashwing bow equip", 5000);
      continue;
    }
    if (Number(state.player.health) < 70 && Date.now() - lastPotion > 2000
      && Number(state.inventory?.items?.redroot_potion || 0) > 0) {
      await tapGameplayKey(cdp, "KeyR", "r", 80);
      lastPotion = Date.now();
      continue;
    }
    const arrowsBefore = Number(state.inventory?.items?.standard_arrow || 0);
    if (arrowsBefore <= 0) throw new Error(`Ashwing survived all carried standard arrows at ${boss.health} health`);
    await fireAimedArrow(cdp);
    await waitFor(async () => {
      const after = await freshCombatState(cdp).catch(() => null);
      if (after?.player?.dead || Number(after?.player?.health) <= 0) throw new Error("Kael died fighting Ashwing");
      return after?.story?.flags?.ashwing_defeated
        || Number(after?.inventory?.items?.standard_arrow ?? arrowsBefore) < arrowsBefore ? after : null;
    }, "Ashwing arrow consumption", 3000);
    await sleep(360);
  }
  throw new Error("Ashwing did not resolve through real bow input");
}

async function runOpeningToMiller(cdp, url, checkpoints, onStartupReady, resumeAt = "new_game") {
  await runOpeningThroughAshPreparation(cdp, url, checkpoints, onStartupReady, resumeAt);
  await useInteraction(cdp, "millstones", checkpoints);
  await requireObjective(cdp, "main_ash_at_the_mill", "inspect_millstones", "Real millstone inspection");
  await fightAshMillPack(cdp, checkpoints);
  await fightAshwing(cdp, checkpoints);
  const state = await freshTelemetry(cdp);
  if (state?.zone !== "old_mill" || !state?.story?.flags?.ashwing_defeated
    || state?.story?.flags?.mill_fate
    || !state?.quests?.active?.includes("main_ash_at_the_mill")) {
    throw new Error("Old Mill checkpoint is not at the unresolved miller record");
  }
  return state;
}

async function runOpeningThroughAsh(cdp, url, checkpoints, onStartupReady, resumeAt = "new_game") {
  await runOpeningToMiller(cdp, url, checkpoints, onStartupReady, resumeAt);
  await useInteraction(cdp, "miller_record", checkpoints, true, "Preserve the ledger");
  const state = await freshTelemetry(cdp);
  if (state?.zone !== "old_mill" || state?.story?.flags?.mill_fate !== "preserved"
    || !state?.quests?.completed?.includes("main_ash_at_the_mill")
    || !state?.quests?.active?.includes("main_soldier_without_banner")) {
    throw new Error("Real mill ledger choice did not preserve Ash and open Soldier Without a Banner");
  }
  checkpoints.push({ event: "ash_mill_completed", outcome: "preserved", next_chapter: "main_soldier_without_banner" });
  return state;
}

async function continueSavedMiller(cdp, url, checkpoints) {
  const resumeUrl = `${url}&miller_resume=${Date.now()}`;
  await cdp.send("Page.navigate", { url: resumeUrl });
  await waitFor(async () => cdp.evaluate(
    `location.href.startsWith(${JSON.stringify(resumeUrl)}) && Boolean(document.getElementById("start") && document.querySelector("canvas"))`
  ), "Miller checkpoint page reload", 10000);
  await activateBootShell(cdp);
  await waitFor(async () => {
    const current = await freshTelemetry(cdp).catch(() => null);
    return current?.new_game_ready && current?.ui?.active_menu === "main"
      && current?.ui?.buttons?.some((button) => button.text === "Continue" && button.enabled)
      ? current : null;
  }, "enabled Continue after Miller checkpoint reload", 45000);
  await chooseMenuButton(cdp, "Continue");
  const resumed = await waitFor(async () => {
    const current = await freshTelemetry(cdp).catch(() => null);
    return current?.zone === "old_mill" && current?.player?.can_control && !current?.transition_pending
      ? current : null;
  }, "Miller checkpoint gameplay control", 20000);
  if (!resumed?.quests?.active?.includes("main_ash_at_the_mill")
    || !resumed?.story?.flags?.ashwing_defeated
    || resumed?.story?.flags?.mill_fate
    || resumed?.quests?.objectives_done?.main_ash_at_the_mill?.includes("mill_choice")) {
    throw new Error("Real Continue did not restore the unresolved Miller checkpoint");
  }
  checkpoints.push({ event: "miller_checkpoint_restored", zone: resumed.zone });
  return resumed;
}

async function runOpeningMillMatrix(cdp, url, checkpoints, onStartupReady) {
  await runOpeningToMiller(cdp, url, checkpoints, onStartupReady);
  await saveThroughPauseMenu(cdp, checkpoints);
  const choices = [
    { label: "Preserve the ledger", fate: "preserved" },
    { label: "Burn the ledger", fate: "burned" },
    { label: "Post copies in Greyfen", fate: "exposed" },
  ];
  let lastState = null;
  for (const [index, choice] of choices.entries()) {
    if (index > 0) await continueSavedMiller(cdp, url, checkpoints);
    await useInteraction(cdp, "miller_record", checkpoints, true, choice.label);
    lastState = await freshTelemetry(cdp);
    if (lastState?.story?.flags?.mill_fate !== choice.fate
      || !lastState?.quests?.completed?.includes("main_ash_at_the_mill")
      || !lastState?.quests?.active?.includes("main_soldier_without_banner")) {
      throw new Error(`Real miller choice did not open Soldier as ${choice.fate}`);
    }
    checkpoints.push({ event: "miller_choice_completed", outcome: choice.fate });
  }
  return lastState;
}

async function fightSennGuards(cdp, checkpoints, timeout = 90000) {
  await tapGameplayKey(cdp, "Digit1", "1", 80);
  await waitFor(async () => {
    const state = await freshCombatState(cdp).catch(() => null);
    return state?.player?.weapon_mode === "sword" ? state : null;
  }, "Senn guard sword equip", 5000);
  const started = Date.now();
  let lastHealth = Infinity;
  let lastDamage = started;
  let lastPotion = 0;
  while (Date.now() - started < timeout) {
    const state = await combatTelemetry(cdp);
    if (state?.quests?.objectives_done?.main_soldier_without_banner?.includes("senn_confrontation")) {
      if (!state?.story?.flags?.senn_ready_to_testify) {
        throw new Error("Senn's guards fell without staging testimony");
      }
      checkpoints.push({ event: "senn_guard_defeat", elapsed_ms: Date.now() - started });
      return state;
    }
    if (state?.player?.dead || Number(state?.player?.health) <= 0) throw new Error("Kael died fighting Senn's guards");
    const enemy = selectActiveEnemy(state, "bandit");
    if (!enemy) {
      await sleep(180);
      continue;
    }
    if (enemy.health > lastHealth + 1) {
      lastHealth = enemy.health;
      lastDamage = Date.now();
    } else if (enemy.health < lastHealth) {
      lastHealth = enemy.health;
      lastDamage = Date.now();
    }
    if (Date.now() - lastDamage > 22000) throw new Error(`Senn guard combat stalled at ${enemy.health} health`);
    const locked = state.camera?.locked_target_position;
    if (state.camera?.locked_target_id !== "bandit" || !locked
      || Math.hypot(locked.x - enemy.position.x, locked.z - enemy.position.z) > 0.6) {
      await tapGameplayKey(cdp, "KeyT", "t", 80);
      await sleep(280);
      continue;
    }
    if (Number(state.player.health) < 65 && Date.now() - lastPotion > 6000
      && Number(state.inventory?.items?.redroot_potion || 0) > 0) {
      await tapGameplayKey(cdp, "KeyR", "r", 80);
      lastPotion = Date.now();
      continue;
    }
    const distance = Math.hypot(
      enemy.position.x - state.player.position.x,
      enemy.position.z - state.player.position.z,
    );
    if (distance > 2.84) await approachMovingEnemy(cdp, 2.84, 5000, "bandit");
    else await attackLiveTarget(cdp, 2.84, "bandit");
    await sleep(300);
  }
  throw new Error("Senn's guards did not resolve through real combat input");
}

async function runOpeningToSenn(cdp, url, checkpoints, onStartupReady, resumeAt = "new_game") {
  await runOpeningThroughAsh(cdp, url, checkpoints, onStartupReady, resumeAt);
  for (const zone of ["burned_farmstead", "marsh_crossing", "bandit_road"]) {
    await traverse(cdp, zone, checkpoints);
  }
  const arrival = await requireObjective(cdp, "main_soldier_without_banner", "reach_bandit_road", "Physical Bandit Road arrival");
  const guards = arrival?.enemies?.filter((enemy) => enemy.id === "bandit" && !enemy.dead) || [];
  if (arrival?.zone !== "bandit_road" || guards.length !== 2 || arrival?.story?.flags?.mill_fate !== "preserved") {
    throw new Error("Bandit Road did not stage two living guards with the preserved ledger");
  }
  await fightSennGuards(cdp, checkpoints);
  const state = await freshTelemetry(cdp);
  if (state?.zone !== "bandit_road" || state?.story?.flags?.senn_fate
    || !state?.quests?.active?.includes("main_soldier_without_banner")
    || !state?.quests?.objectives_done?.main_soldier_without_banner?.includes("senn_confrontation")) {
    throw new Error("Bandit Road checkpoint is not at unresolved Senn testimony");
  }
  return state;
}

async function runOpeningThroughSoldier(cdp, url, checkpoints, onStartupReady, resumeAt = "new_game") {
  await runOpeningToSenn(cdp, url, checkpoints, onStartupReady, resumeAt);
  await useInteraction(cdp, "captain_senn", checkpoints, true, "Testify in Greyfen");
  const state = await freshTelemetry(cdp);
  if (state?.zone !== "bandit_road" || state?.story?.flags?.senn_fate !== "testimony"
    || !state?.quests?.completed?.includes("main_soldier_without_banner")
    || !state?.quests?.active?.includes("main_blood_under_stone")) {
    throw new Error("Senn's real testimony choice did not open Blood Under Stone");
  }
  checkpoints.push({ event: "soldier_completed", outcome: "testimony", next_chapter: "main_blood_under_stone" });
  return state;
}

async function continueSavedSenn(cdp, url, checkpoints, expectedStage = "senn_unresolved") {
  const resumeUrl = `${url}&senn_resume=${Date.now()}`;
  await cdp.send("Page.navigate", { url: resumeUrl });
  await waitFor(async () => cdp.evaluate(
    `location.href.startsWith(${JSON.stringify(resumeUrl)}) && Boolean(document.getElementById("start") && document.querySelector("canvas"))`
  ), "Senn checkpoint page reload", 10000);
  await activateBootShell(cdp);
  await waitFor(async () => {
    const current = await freshTelemetry(cdp).catch(() => null);
    return current?.new_game_ready && current?.ui?.active_menu === "main"
      && current?.ui?.buttons?.some((button) => button.text === "Continue" && button.enabled)
      ? current : null;
  }, "enabled Continue after Senn checkpoint reload", 45000);
  await chooseMenuButton(cdp, "Continue");
  const resumed = await waitFor(async () => {
    const current = await freshTelemetry(cdp).catch(() => null);
    return current?.zone === "bandit_road" && current?.player?.can_control && !current?.transition_pending
      ? current : null;
  }, "Senn checkpoint gameplay control", 20000);
  if (expectedStage === "bannerless_muster") {
    if (!resumed?.quests?.completed?.includes("main_soldier_without_banner")
      || resumed?.story?.flags?.senn_fate !== "testimony"
      || !resumed?.quests?.active?.includes("side_soldiers_debt")
      || !resumed?.quests?.objectives_done?.side_soldiers_debt?.includes("find_deserters")
      || !resumed?.story?.flags?.deserters_muster_read
      || resumed?.story?.flags?.bannerless_fate) {
      throw new Error("Real Continue lost the unresolved deserters' muster checkpoint");
    }
  } else if (!resumed?.quests?.active?.includes("main_soldier_without_banner")
    || !resumed?.quests?.objectives_done?.main_soldier_without_banner?.includes("senn_confrontation")
    || resumed?.quests?.objectives_done?.main_soldier_without_banner?.includes("senn_choice")
    || resumed?.story?.flags?.senn_fate) {
    throw new Error("Real Continue did not restore the unresolved Senn checkpoint");
  }
  checkpoints.push({ event: "senn_checkpoint_restored", zone: resumed.zone, stage: expectedStage });
  return resumed;
}

async function runOpeningSennMatrix(cdp, url, checkpoints, onStartupReady) {
  await runOpeningToSenn(cdp, url, checkpoints, onStartupReady);
  await saveThroughPauseMenu(cdp, checkpoints);
  const choices = [
    { label: "Testify in Greyfen", fate: "testimony" },
    { label: "Leave and never return", fate: "exile" },
    { label: "Answer for the dead", fate: "punished" },
  ];
  let lastState = null;
  for (const [index, choice] of choices.entries()) {
    if (index > 0) await continueSavedSenn(cdp, url, checkpoints);
    await useInteraction(cdp, "captain_senn", checkpoints, true, choice.label);
    lastState = await freshTelemetry(cdp);
    if (lastState?.story?.flags?.senn_fate !== choice.fate
      || !lastState?.quests?.completed?.includes("main_soldier_without_banner")
      || !lastState?.quests?.active?.includes("main_blood_under_stone")) {
      throw new Error(`Real Senn choice did not open Blood Under Stone as ${choice.fate}`);
    }
    checkpoints.push({ event: "senn_choice_completed", outcome: choice.fate });
  }
  return lastState;
}

async function runBannerlessMatrix(cdp, url, checkpoints, onStartupReady) {
  await runOpeningThroughSoldier(cdp, url, checkpoints, onStartupReady);
  await useInteraction(cdp, "captain_senn", checkpoints, true, "Find the soldiers who left your banner");
  const active = await freshTelemetry(cdp);
  if (active?.zone !== "bandit_road" || !active?.quests?.active?.includes("side_soldiers_debt")) {
    throw new Error("Senn's visible request did not start The Bannerless");
  }
  await useInteraction(cdp, "deserters_muster", checkpoints);
  const muster = await freshTelemetry(cdp);
  if (!muster?.quests?.objectives_done?.side_soldiers_debt?.includes("find_deserters")
    || !muster?.story?.flags?.deserters_muster_read) {
    throw new Error("Focused deserters' muster did not establish signed testimony");
  }
  await saveThroughPauseMenu(cdp, checkpoints);
  const choices = [
    { label: "Carry the deserters' signed refusal to Greyfen", outcome: "testimony" },
    { label: "Shield the deserters' names from Vargan", outcome: "shielded" },
  ];
  let finalState = null;
  for (const [index, choice] of choices.entries()) {
    if (index > 0) await continueSavedSenn(cdp, url, checkpoints, "bannerless_muster");
    await useInteraction(cdp, "captain_senn", checkpoints, true, choice.label);
    finalState = await freshTelemetry(cdp);
    if (!finalState?.quests?.completed?.includes("side_soldiers_debt")
      || finalState?.story?.flags?.bannerless_fate !== choice.outcome) {
      throw new Error(`Real Bannerless ${choice.outcome} choice did not persist`);
    }
    checkpoints.push({ event: "bannerless_choice_completed", outcome: choice.outcome, zone: finalState.zone });
  }
  await continueSavedSenn(cdp, url, checkpoints, "bannerless_muster");
  return recordAssemblySideOutcome(cdp, url, checkpoints, onStartupReady, {
    resumeAt: "bandit_muster", quest: "side_soldiers_debt", clue: "find_deserters",
    flag: "bannerless_fate", label: "Read the deserters' refusal into the record",
  });
}

async function runOpeningThroughCastle(cdp, url, checkpoints, onStartupReady, resumeAt = "new_game") {
  if (resumeAt === "bandit_muster") {
    const saved = await freshTelemetry(cdp);
    if (saved?.zone !== "bandit_road" || !saved?.player?.can_control
      || saved?.story?.flags?.senn_fate !== "testimony"
      || !saved?.quests?.active?.includes("main_blood_under_stone")
      || !saved?.quests?.active?.includes("side_soldiers_debt")
      || !saved?.quests?.objectives_done?.side_soldiers_debt?.includes("find_deserters")
      || saved?.story?.flags?.bannerless_fate) {
      throw new Error("Earned Bandit Road muster checkpoint cannot continue to Castle");
    }
  } else {
    await runOpeningThroughSoldier(cdp, url, checkpoints, onStartupReady, resumeAt);
  }
  await traverse(cdp, "vargan_approach", checkpoints);
  await requireObjective(cdp, "main_blood_under_stone", "reach_castle", "Physical Vargan approach arrival");
  for (const clue of ["vargan_mile_marker", "vargan_supply_cart"]) {
    await useInteraction(cdp, clue, checkpoints);
  }
  await traverse(cdp, "vargan_court", checkpoints);
  await requireObjective(cdp, "main_blood_under_stone", "enter_courtyard", "Physical Vargan courtyard entry");
  await useInteraction(cdp, "vargan_gate_guard", checkpoints, true, "I carry testimony from the old road.");
  await requireObjective(cdp, "main_blood_under_stone", "speak_guard", "Real Vargan guard conversation");
  await useInteraction(cdp, "vargan_gate_notice", checkpoints);
  await requireObjective(cdp, "main_blood_under_stone", "castle_evidence_ready", "Three Castle evidence interactions");
  await traverse(cdp, "record_hall", checkpoints);
  const state = await requireObjective(cdp, "main_blood_under_stone", "locate_record_hall", "Physical Record Hall entry");
  if (state?.zone !== "record_hall" || !state?.quests?.active?.includes("main_blood_under_stone")) {
    throw new Error("Record Hall arrival lost Blood Under Stone");
  }
  checkpoints.push({ event: "record_hall_entered", zone: state.zone });
  return state;
}

async function continueSavedLedger(cdp, url, checkpoints) {
  const resumeUrl = `${url}&ledger_resume=${Date.now()}`;
  await cdp.send("Page.navigate", { url: resumeUrl });
  await waitFor(async () => cdp.evaluate(
    `location.href.startsWith(${JSON.stringify(resumeUrl)}) && Boolean(document.getElementById("start") && document.querySelector("canvas"))`
  ), "Ledger checkpoint page reload", 10000);
  await activateBootShell(cdp);
  await waitFor(async () => {
    const current = await freshTelemetry(cdp).catch(() => null);
    return current?.new_game_ready && current?.ui?.active_menu === "main"
      && current?.ui?.buttons?.some((button) => button.text === "Continue" && button.enabled)
      ? current : null;
  }, "enabled Continue after Ledger checkpoint reload", 45000);
  await chooseMenuButton(cdp, "Continue");
  const resumed = await waitFor(async () => {
    const current = await freshTelemetry(cdp).catch(() => null);
    return current?.zone === "record_hall" && current?.player?.can_control && !current?.transition_pending
      ? current : null;
  }, "Ledger checkpoint gameplay control", 20000);
  if (!resumed?.quests?.active?.includes("main_blood_under_stone")
    || !resumed?.quests?.objectives_done?.main_blood_under_stone?.includes("locate_record_hall")
    || resumed?.quests?.objectives_done?.main_blood_under_stone?.includes("ledger_choice")
    || resumed?.story?.flags?.vargan_ledger_choice_made) {
    throw new Error("Real Continue did not restore the unresolved Record Hall ledger checkpoint");
  }
  checkpoints.push({ event: "ledger_checkpoint_restored", zone: resumed.zone });
  return resumed;
}

async function runOpeningLedgerMatrix(cdp, url, checkpoints, onStartupReady) {
  const arrival = await runOpeningThroughCastle(cdp, url, checkpoints, onStartupReady);
  if (arrival?.story?.flags?.vargan_ledger_choice_made) {
    throw new Error("Record Hall ledger was resolved before the player-earned checkpoint");
  }
  await saveThroughPauseMenu(cdp, checkpoints);
  const choices = [
    { label: "Take the fragment openly", flag: "vargan_ledger_taken_openly" },
    { label: "Hide the fragment", flag: "vargan_ledger_hidden" },
    { label: "Leave it and copy the seal", flag: "vargan_ledger_left_copied" },
  ];
  let lastState = null;
  for (const [index, choice] of choices.entries()) {
    if (index > 0) await continueSavedLedger(cdp, url, checkpoints);
    await useInteraction(cdp, "vargan_ledger_choice", checkpoints, true, choice.label);
    lastState = await waitFor(async () => {
      const current = await freshTelemetry(cdp).catch(() => null);
      return current?.story?.flags?.vargan_ledger_choice_made ? current : null;
    }, `${choice.label} ledger choice`, 5000);
    if (!lastState?.story?.flags?.[choice.flag]
      || !lastState?.quests?.objectives_done?.main_blood_under_stone?.includes("recover_ledger")
      || !lastState?.quests?.objectives_done?.main_blood_under_stone?.includes("ledger_choice")) {
      throw new Error(`Real ledger choice did not persist ${choice.flag} and quest progress`);
    }
    checkpoints.push({ event: "ledger_choice_completed", outcome: choice.flag });
  }
  return lastState;
}

async function fightRecordHaunting(cdp, checkpoints, timeout = 50000) {
  await tapGameplayKey(cdp, "Digit1", "1", 80);
  const started = Date.now();
  let lastHealth = Infinity;
  let lastDamage = started;
  let lastPotion = 0;
  while (Date.now() - started < timeout) {
    const state = await combatTelemetry(cdp);
    if (state?.story?.flags?.castle_haunting_cleared
      && state?.quests?.objectives_done?.main_blood_under_stone?.includes("survive_haunting")) {
      checkpoints.push({ event: "record_haunting_cleared", elapsed_ms: Date.now() - started });
      return state;
    }
    if (state?.player?.dead || Number(state?.player?.health) <= 0) throw new Error("Kael died in Record Hall");
    const enemy = selectActiveEnemy(state, "wychwood_stalker");
    if (!enemy) throw new Error("Record Hall haunting vanished without completion");
    if (enemy.health < lastHealth) {
      lastHealth = enemy.health;
      lastDamage = Date.now();
    }
    if (Date.now() - lastDamage > 18000) throw new Error(`Record Hall combat stalled at ${enemy.health} health`);
    if (state.camera?.locked_target_id !== "wychwood_stalker") {
      await tapGameplayKey(cdp, "KeyT", "t", 80);
      await sleep(280);
      continue;
    }
    if (Number(state.player.health) < 65 && Date.now() - lastPotion > 5000
      && Number(state.inventory?.items?.redroot_potion || 0) > 0) {
      await tapGameplayKey(cdp, "KeyR", "r", 80);
      lastPotion = Date.now();
      continue;
    }
    const distance = Math.hypot(
      enemy.position.x - state.player.position.x,
      enemy.position.z - state.player.position.z,
    );
    if (distance > 2.84) await approachMovingEnemy(cdp, 2.84, 5000, "wychwood_stalker");
    else await attackLiveTarget(cdp, 2.84, "wychwood_stalker");
    await sleep(300);
  }
  throw new Error("Record Hall haunting did not resolve through real combat input");
}

async function runOpeningToEdric(cdp, url, checkpoints, onStartupReady, resumeAt = "new_game") {
  await runOpeningThroughCastle(cdp, url, checkpoints, onStartupReady, resumeAt);
  await useInteraction(cdp, "vargan_ledger_choice", checkpoints, true, "Take the fragment openly");
  let state = await waitFor(async () => {
    const current = await freshTelemetry(cdp).catch(() => null);
    return current?.enemies?.some((enemy) => enemy.id === "wychwood_stalker" && !enemy.dead)
      ? current : null;
  }, "Record Hall haunting staged", 5000);
  if (!state?.story?.flags?.vargan_ledger_choice_made
    || !state?.story?.flags?.vargan_ledger_taken_openly
    || !state?.quests?.objectives_done?.main_blood_under_stone?.includes("ledger_choice")
    || !state?.quests?.objectives_done?.main_blood_under_stone?.includes("recover_ledger")
    || !state?.enemies?.some((enemy) => enemy.id === "wychwood_stalker" && !enemy.dead)) {
    throw new Error("Ledger choice did not stage the Record Hall haunting");
  }
  await fightRecordHaunting(cdp, checkpoints);
  await waitFor(async () => {
    const current = await freshTelemetry(cdp).catch(() => null);
    return current?.zone === "record_hall" && current?.player?.can_control && !current?.transition_pending
      ? current : null;
  }, "Record Hall post-haunting control", 10000);
  state = await freshTelemetry(cdp);
  if (!state?.story?.flags?.castle_haunting_cleared || state?.story?.flags?.edric_stance
    || !state?.quests?.active?.includes("main_blood_under_stone")) {
    throw new Error("Record Hall checkpoint is not at unresolved Edric testimony");
  }
  return state;
}

async function runOpeningThroughRecordHall(cdp, url, checkpoints, onStartupReady, resumeAt = "new_game") {
  await runOpeningToEdric(cdp, url, checkpoints, onStartupReady, resumeAt);
  await useInteraction(cdp, "edric_campaign", checkpoints, true, "Testify under protection");
  const state = await freshTelemetry(cdp);
  if (state?.zone !== "record_hall" || state?.story?.flags?.edric_stance !== "cooperate"
    || !state?.quests?.completed?.includes("main_blood_under_stone")
    || !state?.quests?.active?.includes("main_last_witness")) {
    throw new Error("Edric's real testimony did not open The Last Witness");
  }
  checkpoints.push({ event: "blood_under_stone_completed", outcome: "cooperate", next_chapter: "main_last_witness" });
  return state;
}

async function continueSavedEdric(cdp, url, checkpoints) {
  const resumeUrl = `${url}&edric_resume=${Date.now()}`;
  await cdp.send("Page.navigate", { url: resumeUrl });
  await waitFor(async () => cdp.evaluate(
    `location.href.startsWith(${JSON.stringify(resumeUrl)}) && Boolean(document.getElementById("start") && document.querySelector("canvas"))`
  ), "Edric checkpoint page reload", 10000);
  await activateBootShell(cdp);
  await waitFor(async () => {
    const current = await freshTelemetry(cdp).catch(() => null);
    return current?.new_game_ready && current?.ui?.active_menu === "main"
      && current?.ui?.buttons?.some((button) => button.text === "Continue" && button.enabled)
      ? current : null;
  }, "enabled Continue after Edric checkpoint reload", 45000);
  await chooseMenuButton(cdp, "Continue");
  const resumed = await waitFor(async () => {
    const current = await freshTelemetry(cdp).catch(() => null);
    return current?.zone === "record_hall" && current?.player?.can_control && !current?.transition_pending
      ? current : null;
  }, "Edric checkpoint gameplay control", 20000);
  if (!resumed?.quests?.active?.includes("main_blood_under_stone")
    || !resumed?.story?.flags?.castle_haunting_cleared
    || resumed?.story?.flags?.edric_stance
    || resumed?.quests?.objectives_done?.main_blood_under_stone?.includes("last_witness_hook")) {
    throw new Error("Real Continue did not restore the unresolved Edric checkpoint");
  }
  checkpoints.push({ event: "edric_checkpoint_restored", zone: resumed.zone });
  return resumed;
}

async function runOpeningEdricMatrix(cdp, url, checkpoints, onStartupReady) {
  await runOpeningToEdric(cdp, url, checkpoints, onStartupReady);
  await saveThroughPauseMenu(cdp, checkpoints);
  const choices = [
    { label: "Testify under protection", stance: "cooperate" },
    { label: "Expose him now", stance: "exposed" },
    { label: "Compel a confession", stance: "compelled" },
  ];
  let lastState = null;
  for (const [index, choice] of choices.entries()) {
    if (index > 0) await continueSavedEdric(cdp, url, checkpoints);
    await useInteraction(cdp, "edric_campaign", checkpoints, true, choice.label);
    lastState = await freshTelemetry(cdp);
    if (lastState?.story?.flags?.edric_stance !== choice.stance
      || !lastState?.quests?.completed?.includes("main_blood_under_stone")
      || !lastState?.quests?.active?.includes("main_last_witness")) {
      throw new Error(`Real Edric choice did not complete Blood Under Stone as ${choice.stance}`);
    }
    checkpoints.push({ event: "edric_choice_completed", outcome: choice.stance });
  }
  return lastState;
}

async function parryHalvernGuard(cdp, checkpoints, timeout = 18000) {
  const started = Date.now();
  let parryAttempts = 0;
  while (Date.now() - started < timeout) {
    const state = await combatTelemetry(cdp);
    if (state?.story?.flags?.halvern_guard_broken
      && state?.quests?.objectives_done?.main_last_witness?.includes("break_halvern_guard")) {
      checkpoints.push({ event: "halvern_guard_parried", attempts: parryAttempts });
      return state;
    }
    if (state?.player?.dead || Number(state?.player?.health) <= 0) throw new Error("Kael died before breaking Halvern's guard");
    const boss = selectActiveEnemy(state, "halvern_boss");
    if (!boss) throw new Error("Halvern disappeared before the witness decision");
    const distance = Math.hypot(
      boss.position.x - state.player.position.x,
      boss.position.z - state.player.position.z,
    );
    if (distance > 2.4) {
      await approachMovingEnemy(cdp, 2.4, 5000, "halvern_boss");
      continue;
    }
    if (boss.pending_attack_time > 0 && boss.pending_attack_time < 0.225) {
      await tapGameplayKey(cdp, "KeyQ", "q", 75);
      parryAttempts += 1;
      await sleep(100);
    } else {
      await sleep(35);
    }
  }
  throw new Error(`Halvern guard did not break through real Q parry input (${parryAttempts} attempts)`);
}

async function runOpeningThroughLastWitness(cdp, url, checkpoints, onStartupReady, resumeAt = "new_game") {
  await runOpeningThroughRecordHall(cdp, url, checkpoints, onStartupReady, resumeAt);
  await traverse(cdp, "undercroft", checkpoints);
  const arrival = await requireObjective(cdp, "main_last_witness", "reach_undercroft", "Physical undercroft arrival");
  if (arrival?.zone !== "undercroft" || !arrival?.enemies?.some((enemy) => enemy.id === "halvern_boss" && !enemy.dead)) {
    throw new Error("Undercroft did not stage one living Halvern");
  }
  await parryHalvernGuard(cdp, checkpoints);
  await useInteraction(cdp, "halvern", checkpoints, true, "Stand as the last witness");
  const state = await freshTelemetry(cdp);
  if (state?.story?.flags?.halvern_fate !== "witness"
    || !state?.story?.flags?.boss_reward_sealed_testimony
    || !state?.story?.flags?.halvern_testimony_available
    || !state?.quests?.completed?.includes("main_last_witness")
    || !state?.quests?.active?.includes("main_crowns_without_mercy")) {
    throw new Error("Peaceful Halvern witness resolution did not grant reward and assembly chapter");
  }
  checkpoints.push({ event: "last_witness_completed", outcome: "witness" });
  return state;
}

async function continueSavedAssemblySideOutcome(cdp, url, checkpoints, quest, flag) {
  const resumeUrl = `${url}&assembly_side_resume=${Date.now()}`;
  await cdp.send("Page.navigate", { url: resumeUrl });
  await waitFor(async () => cdp.evaluate(
    `location.href.startsWith(${JSON.stringify(resumeUrl)}) && Boolean(document.getElementById("start") && document.querySelector("canvas"))`
  ), "assembly side-outcome page reload", 10000);
  await activateBootShell(cdp);
  await waitFor(async () => {
    const current = await freshTelemetry(cdp).catch(() => null);
    return current?.new_game_ready && current?.ui?.active_menu === "main"
      && current?.ui?.buttons?.some((button) => button.text === "Continue" && button.enabled)
      ? current : null;
  }, "enabled Continue after assembly side-outcome reload", 45000);
  await chooseMenuButton(cdp, "Continue");
  const resumed = await waitFor(async () => {
    const current = await freshTelemetry(cdp).catch(() => null);
    return current?.zone === "assembly" && current?.player?.can_control && !current?.transition_pending
      ? current : null;
  }, "assembly side-outcome gameplay control", 20000);
  if (!resumed?.quests?.completed?.includes(quest)
    || resumed?.story?.flags?.[flag] !== "assembly"
    || !resumed?.quests?.active?.includes("main_crowns_without_mercy")) {
    throw new Error(`Real Continue lost the public-record ${quest} outcome`);
  }
  checkpoints.push({ event: "assembly_side_outcome_restored", quest, outcome: "assembly" });
  return resumed;
}

async function recordAssemblySideOutcome(cdp, url, checkpoints, onStartupReady, spec) {
  await runOpeningThroughLastWitness(cdp, url, checkpoints, onStartupReady, spec.resumeAt);
  const carried = await freshTelemetry(cdp);
  if (!carried?.quests?.active?.includes(spec.quest)
    || !carried?.quests?.objectives_done?.[spec.quest]?.includes(spec.clue)
    || carried?.story?.flags?.[spec.flag]) {
    throw new Error(`Main route lost unresolved ${spec.quest} evidence before assembly`);
  }
  await traverse(cdp, "assembly", checkpoints);
  await requireObjective(cdp, "main_crowns_without_mercy", "greyfen_assembly", "Physical assembly side-route arrival");
  for (const witness of ["witness_3", "witness_-3", "witness_-7", "witness_7"]) {
    await useInteraction(cdp, witness, checkpoints, true);
  }
  await useInteraction(cdp, "witnesses_ready", checkpoints);
  await requireObjective(cdp, "main_crowns_without_mercy", "gather_witnesses", "Assembly witness record");
  await useInteraction(cdp, "assembly_choice", checkpoints, true, spec.label);
  const recorded = await freshTelemetry(cdp);
  if (recorded?.zone !== "assembly" || !recorded?.quests?.completed?.includes(spec.quest)
    || recorded?.story?.flags?.[spec.flag] !== "assembly"
    || !recorded?.quests?.active?.includes("main_crowns_without_mercy")) {
    throw new Error(`Real assembly choice did not record ${spec.quest} evidence`);
  }
  await saveThroughPauseMenu(cdp, checkpoints, true);
  return continueSavedAssemblySideOutcome(cdp, url, checkpoints, spec.quest, spec.flag);
}

async function runOpeningThroughAssembly(cdp, url, checkpoints, onStartupReady) {
  await runOpeningThroughLastWitness(cdp, url, checkpoints, onStartupReady);
  await traverse(cdp, "assembly", checkpoints);
  await requireObjective(cdp, "main_crowns_without_mercy", "greyfen_assembly", "Physical assembly arrival");
  for (const witness of ["witness_3", "witness_-3", "witness_-7", "witness_7"]) {
    await useInteraction(cdp, witness, checkpoints, true);
  }
  await useInteraction(cdp, "witnesses_ready", checkpoints);
  await requireObjective(cdp, "main_crowns_without_mercy", "gather_witnesses", "Witness record interaction");
  await useInteraction(cdp, "assembly_choice", checkpoints, true, "Let every witness speak");
  const state = await freshTelemetry(cdp);
  if (state?.zone !== "assembly" || state?.story?.flags?.confession_method !== "witnesses"
    || !state?.quests?.completed?.includes("main_crowns_without_mercy")
    || !state?.quests?.active?.includes("main_hart_remembers")) {
    throw new Error("Public assembly choice did not open The Hart Remembers");
  }
  checkpoints.push({ event: "assembly_completed", outcome: "witnesses", next_chapter: "main_hart_remembers" });
  return state;
}

async function runOpeningThroughFinale(cdp, url, checkpoints, onStartupReady) {
  await runOpeningThroughAssembly(cdp, url, checkpoints, onStartupReady);
  await traverse(cdp, "hart_glade", checkpoints);
  await requireObjective(cdp, "main_hart_remembers", "enter_glade", "Physical Hart Glade arrival");
  await useInteraction(cdp, "white_hart", checkpoints, true, "Witness: name every dead", false);
  const state = await waitFor(async () => {
    const current = await freshTelemetry(cdp).catch(() => null);
    return current?.story?.flags?.final_choice_completed ? current : null;
  }, "White Hart witness ending", 10000);
  if (state?.zone !== "hart_glade" || state?.story?.flags?.final_covenant !== "witness"
    || state?.quests?.world_flags?.ending !== "expose"
    || !state?.quests?.completed?.includes("main_hart_remembers")
    || !Array.isArray(state?.story?.flags?.epilogue_cards)
    || state.story.flags.epilogue_cards.length === 0
    || !state?.ui?.buttons?.some((button) => button.text === "Return to Main Menu")) {
    throw new Error("Real White Hart choice did not complete the Witness ending and epilogue");
  }
  checkpoints.push({ event: "witness_ending_completed", ending: "expose", cards: state.story.flags.epilogue_cards.length });
  return state;
}

async function continueSavedHart(cdp, url, checkpoints) {
  const resumeUrl = `${url}&hart_resume=${Date.now()}`;
  await cdp.send("Page.navigate", { url: resumeUrl });
  await waitFor(async () => cdp.evaluate(
    `location.href.startsWith(${JSON.stringify(resumeUrl)}) && Boolean(document.getElementById("start") && document.querySelector("canvas"))`
  ), "Hart checkpoint page reload", 10000);
  await activateBootShell(cdp);
  await waitFor(async () => {
    const current = await freshTelemetry(cdp).catch(() => null);
    return current?.new_game_ready && current?.ui?.active_menu === "main"
      && current?.ui?.buttons?.some((button) => button.text === "Continue" && button.enabled)
      ? current : null;
  }, "enabled Continue after Hart checkpoint reload", 45000);
  await chooseMenuButton(cdp, "Continue");
  const resumed = await waitFor(async () => {
    const current = await freshTelemetry(cdp).catch(() => null);
    return current?.zone === "hart_glade" && current?.player?.can_control && !current?.transition_pending
      ? current : null;
  }, "Hart checkpoint gameplay control", 20000);
  if (!resumed?.quests?.active?.includes("main_hart_remembers")
    || resumed?.story?.flags?.final_covenant
    || resumed?.story?.flags?.final_choice_completed) {
    throw new Error("Real Continue did not restore the unresolved Hart checkpoint");
  }
  checkpoints.push({ event: "hart_checkpoint_restored", zone: resumed.zone });
  return resumed;
}

async function fightHartEnding(cdp, covenant, timeout = 90000) {
  await tapGameplayKey(cdp, "Digit1", "1", 70);
  await tapGameplayKey(cdp, "KeyT", "t", 70);
  const started = Date.now();
  let lastProgress = started;
  let lastHealth = Infinity;
  let lastPotion = 0;
  while (Date.now() - started < timeout) {
    const state = await freshTelemetry(cdp);
    if (state?.story?.flags?.final_choice_completed) return state;
    const boss = selectActiveEnemy(state, "white_hart_avatar");
    if (!boss?.position || Number(state?.player?.health || 0) <= 0) {
      throw new Error(`${covenant} Hart combat lost the living boss or player`);
    }
    if (Number(boss.health) < lastHealth) {
      lastHealth = Number(boss.health);
      lastProgress = Date.now();
    }
    if (Date.now() - lastProgress > 15000) {
      throw new Error(`${covenant} Hart combat made no damage progress for 15 seconds`);
    }
    if (Number(state.player.health) < 65 && Number(state?.inventory?.items?.redroot_potion || 0) > 0
      && Date.now() - lastPotion > 5000) {
      await tapGameplayKey(cdp, "KeyR", "r", 70);
      lastPotion = Date.now();
      continue;
    }
    const dx = Number(boss.position.x) - Number(state.player.position.x);
    const dz = Number(boss.position.z) - Number(state.player.position.z);
    if (Math.hypot(dx, dz) > 2.5) {
      await approachMovingEnemy(cdp, 2.5, 3000, "white_hart_avatar");
    } else if (Number(boss.pending_attack_time || 0) > 0
      && Number(boss.pending_attack_time) < 0.225) {
      await tapGameplayKey(cdp, "KeyQ", "q", 70);
    } else {
      await attackLiveTarget(cdp, 2.5, "white_hart_avatar");
    }
    await sleep(60);
  }
  throw new Error(`${covenant} Hart combat exceeded its 90-second real-input deadline`);
}

async function resolveHartChoice(cdp, choice, checkpoints) {
  await useInteraction(cdp, "white_hart", checkpoints, true, choice.label, choice.combat);
  if (choice.combat) {
    const pending = await freshTelemetry(cdp);
    if (pending?.story?.flags?.final_covenant !== choice.covenant
      || pending?.quests?.world_flags?.ending !== choice.ending
      || !selectActiveEnemy(pending, "white_hart_avatar")) {
      throw new Error(`${choice.covenant} choice did not stage the White Hart avatar`);
    }
    await fightHartEnding(cdp, choice.covenant);
  }
  const state = await waitFor(async () => {
    const current = await freshTelemetry(cdp).catch(() => null);
    return current?.story?.flags?.final_choice_completed ? current : null;
  }, `${choice.covenant} Hart ending`, 10000);
  if (state?.story?.flags?.final_covenant !== choice.covenant
    || state?.quests?.world_flags?.ending !== choice.ending
    || !state?.quests?.completed?.includes("main_hart_remembers")
    || !Array.isArray(state?.story?.flags?.epilogue_cards)
    || state.story.flags.epilogue_cards.length === 0
    || !state?.ui?.buttons?.some((button) => button.text === "Return to Main Menu")) {
    throw new Error(`${choice.covenant} Hart ending lacked its epilogue or quest resolution`);
  }
  checkpoints.push({ event: "hart_ending_completed", ending: choice.ending,
    covenant: choice.covenant, cards: state.story.flags.epilogue_cards.length });
  return state;
}

async function runOpeningEndingMatrix(cdp, url, checkpoints, onStartupReady) {
  await runOpeningThroughAssembly(cdp, url, checkpoints, onStartupReady);
  await traverse(cdp, "hart_glade", checkpoints);
  await requireObjective(cdp, "main_hart_remembers", "enter_glade", "Physical Hart Glade arrival");
  await saveThroughPauseMenu(cdp, checkpoints);
  const choices = [
    { label: "Witness: name every dead", covenant: "witness", ending: "expose", combat: false },
    { label: "Mercy: release me, keep selected guilt", covenant: "mercy", ending: "free", combat: false },
    { label: "Duty: bind the covenant to Kael", covenant: "duty", ending: "bind", combat: true },
    { label: "Ash: destroy the witness", covenant: "ash", ending: "kill", combat: true },
  ];
  let lastState = null;
  for (const [index, choice] of choices.entries()) {
    if (index > 0) await continueSavedHart(cdp, url, checkpoints);
    lastState = await resolveHartChoice(cdp, choice, checkpoints);
  }
  return lastState;
}

async function inspectRenderer(cdp) {
  return cdp.evaluate(`(() => {
    const canvas = document.querySelector('canvas');
    const gl = canvas?.getContext('webgl2');
    if (!gl) return null;
    const debug = gl.getExtension('WEBGL_debug_renderer_info');
    return {
      renderer: gl.getParameter(gl.RENDERER),
      unmasked_renderer: debug ? gl.getParameter(debug.UNMASKED_RENDERER_WEBGL) : null,
      vendor: debug ? gl.getParameter(debug.UNMASKED_VENDOR_WEBGL) : null,
    };
  })()`, TELEMETRY_TIMEOUT_MS);
}

function readDevToolsPort(profile) {
  try {
    const lines = readFileSync(join(profile, "DevToolsActivePort"), "utf8")
      .trim()
      .split(/\r?\n/);
    const port = Number(lines[0]);
    return Number.isInteger(port) && port > 0 && port < 65536 ? port : 0;
  } catch {
    return 0;
  }
}

async function testBrowser(name, executable) {
  const profile = join(QA_TEMP_ROOT, `ashen-oath-${fullCampaign ? "web002" : "qa002"}-${name.toLowerCase()}-${Date.now()}`);
  mkdirSync(profile, { recursive: true });
  const diagnosticQuery = traceMovement ? "&diag=1" : "";
  const observationQuery = productionObserver ? "observe=1" : "qa=1";
  const targetUrl = new URL(args.url || `http://127.0.0.1:${port}/index.html`);
  targetUrl.searchParams.set(productionObserver ? "observe" : "qa", "1");
  targetUrl.searchParams.set("v", `${fullCampaign ? "web002" : "qa002"}-${name.toLowerCase()}-${Date.now()}`);
  const url = `${targetUrl}${mobileMode ? "&touch=1" : ""}${diagnosticQuery}`;
  const browser = name === "Firefox" ? null : spawn(executable, [
    ...(presentationMode === "headless" ? ["--headless=new"] : []),
    // Ask Chrome to choose a port and publish it in this isolated profile.
    // A preallocated port can be claimed by an orphaned prior QA browser
    // between the probe and spawn, leaving the child alive with no DevTools
    // endpoint while the old harness waits for the full route timeout.
    "--remote-debugging-port=0",
    "--remote-debugging-address=127.0.0.1",
    "--remote-allow-origins=*",
    `--user-data-dir=${profile}`,
    "--window-size=1280,720",
    "--force-device-scale-factor=1",
    "--no-first-run",
    "--no-default-browser-check",
    "--disable-background-networking",
    "--disable-component-update",
    "--no-sandbox",
    ...(rendererMode === "software" ? [
      "--in-process-gpu", "--disable-gpu-sandbox", "--use-angle=swiftshader",
      "--enable-unsafe-swiftshader", "--ignore-gpu-blocklist",
    ] : []),
    "about:blank",
  ], { stdio: ["ignore", "ignore", "pipe"], windowsHide: presentationMode !== "headed" });
  let spawnError = null;
  let firefoxBrowser = null;
  const browserStderr = [];
  browser?.once("error", (error) => { spawnError = error; });
  browser?.stderr?.on("data", (chunk) => {
    if (browserStderr.join("").length < 12000) browserStderr.push(chunk.toString());
  });
  const started = Date.now();
  let cdp;
  let debugPort = 0;
  const checkpoints = [];
  let failureScreenshot = "";
  let completedSuccessfully = false;
  let cpuProfileStarted = false;
  let finishStartupProfile = async () => {};
  try {
    if (name === "Firefox") {
      if (mobileMode) throw fatal("Firefox mobile emulation is not supported by this transport");
      if (args["profile-startup"]) throw fatal("Firefox startup CPU profiling is not supported by this transport");
      const { default: puppeteer } = await import("puppeteer-core");
      firefoxBrowser = await puppeteer.launch({
        browser: "firefox", executablePath: executable,
        defaultViewport: null,
        headless: presentationMode === "headless", userDataDir: profile,
        args: ["--no-remote", "--new-instance"],
      });
      const firefoxPage = (await firefoxBrowser.pages()).find((item) => item.url() === "about:blank")
        || await firefoxBrowser.newPage();
      cdp = new FirefoxTransport(firefoxPage);
      await cdp.open();
    } else {
      const page = await waitFor(async () => {
      if (spawnError) throw fatal(`${name} browser spawn failed: ${spawnError.message}`);
      debugPort = readDevToolsPort(profile);
      if (debugPort) {
        const targets = await fetchJson(`http://127.0.0.1:${debugPort}/json/list`).catch(() => []);
        const target = targets.find((entry) => entry.type === "page" && entry.url === "about:blank");
        if (target) return target;
      }
      // Edge's compatibility relaunch can retire the original launcher after
      // handing the unique profile to a new root process. Give that isolated
      // root time to publish DevToolsActivePort instead of treating the clean
      // launcher exit as a browser crash.
      if (browser.exitCode !== null || browser.signalCode !== null) {
        if (name === "Edge" && Date.now() - started < CDP_OPEN_TIMEOUT_MS) return null;
        throw fatal(`${name} browser exited before DevTools became ready (code=${browser.exitCode ?? ""}, signal=${browser.signalCode ?? ""})`);
      }
      return null;
      }, `${name} DevTools`);
      cdp = new Cdp(page.webSocketDebuggerUrl);
      await cdp.open();
    }
    await Promise.all([
      cdp.send("Page.enable"),
      cdp.send("Log.enable"),
      cdp.send("Network.enable"),
      cdp.send("Performance.enable"),
      ...(name === "Firefox" ? [] : [cdp.send("WebAudio.enable")]),
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
    // Establish a renderer before enabling Runtime. Chrome's initial
    // about:blank target can accept navigation but never resolves Runtime
    // domain commands in the managed runner.
    await cdp.send("Page.navigate", { url: "data:text/html,<body></body>" });
    await cdp.send("Runtime.enable");
    await cdp.send("Runtime.addBinding", { name: OBSERVATION_BINDING });
    if (productionObserver && !(name === "Firefox" && browserSmoke)) {
      await cdp.send("Runtime.addBinding", { name: ROUTE_BINDING });
      await cdp.send("Page.addScriptToEvaluateOnNewDocument", {
        source: `(() => {
          let result = null;
          Object.defineProperty(window, "__ashenOathReadOnlyRouteResult", {
            configurable: true, enumerable: true,
            get: () => result,
            set: value => {
              result = value;
              if (value?.read_only === true && Number.isInteger(value.request_id)
                && typeof value.target_id === "string") window[${JSON.stringify(ROUTE_BINDING)}](JSON.stringify(value));
            }
          });
        })();`,
      });
      cdp.routeBindingEnabled = true;
    }
    if (name === "Firefox" && !browserSmoke) {
      await cdp.send("Page.addScriptToEvaluateOnNewDocument", {
        source: readFileSync(new URL("./firefox_audio_context_probe.js", import.meta.url), "utf8"),
      });
    }
    if (args["profile-startup"]) {
      await cdp.send("Page.addScriptToEvaluateOnNewDocument", {
        source: readFileSync(new URL("./webgl_startup_probe.js", import.meta.url), "utf8"),
      });
      await cdp.send("Profiler.enable");
      await cdp.send("Profiler.setSamplingInterval", { interval: 1000 });
      await cdp.send("Profiler.start");
      cpuProfileStarted = true;
      finishStartupProfile = async () => {
        if (!cpuProfileStarted) return;
        cpuProfileStarted = false;
        const profilePath = reportPath.replace(/\.json$/i, `_${name.toLowerCase()}.cpuprofile`);
        try {
          const graphics = await cdp.send("Runtime.evaluate", {
            expression: "window.__ASHEN_WEBGL_PROFILE__ || null", returnByValue: true,
          }, 10000);
          writeFileSync(`${profilePath}.webgl.json`, JSON.stringify(graphics.result?.value));
        } catch (error) {
          writeFileSync(`${profilePath}.webgl.error.txt`, String(error.message));
        }
        try {
          const result = await cdp.send("Profiler.stop", {}, 30000);
          writeFileSync(profilePath, JSON.stringify(result.profile));
        } catch (error) {
          writeFileSync(`${profilePath}.error.txt`, String(error.message));
        }
      };
    }

    const routeScope = routeTransport(cdp);
    const finalState = await withDeadline(() => {
      const cdp = routeScope.cdp;
      if (fullCampaign) return runFullCampaign(cdp, url, checkpoints, finishStartupProfile);
      if (browserSmoke) return runBrowserSmoke(cdp, url, checkpoints, finishStartupProfile);
      if (openingSaveContinue) return runOpeningSaveContinue(cdp, url, checkpoints, finishStartupProfile);
      if (shrineMatrix) return runOpeningShrineMatrix(cdp, url, checkpoints, finishStartupProfile);
      if (ledgerMatrix) return runOpeningLedgerMatrix(cdp, url, checkpoints, finishStartupProfile);
      if (edricMatrix) return runOpeningEdricMatrix(cdp, url, checkpoints, finishStartupProfile);
      if (millMatrix) return runOpeningMillMatrix(cdp, url, checkpoints, finishStartupProfile);
      if (sennMatrix) return runOpeningSennMatrix(cdp, url, checkpoints, finishStartupProfile);
      if (reportMatrix) return runOpeningReportMatrix(cdp, url, checkpoints, finishStartupProfile);
      if (widowMatrix) return runOpeningWidowMatrix(cdp, url, checkpoints, finishStartupProfile);
      if (ironMatrix) return runGreyfenSideMatrix(cdp, url, checkpoints, finishStartupProfile, GREYFEN_SIDE_MATRIX.iron);
      if (returnedSoldierMatrix) return runGreyfenSideMatrix(cdp, url, checkpoints, finishStartupProfile, GREYFEN_SIDE_MATRIX.returned_soldier);
      if (bitterRootsMatrix) return runBitterRootsMatrix(cdp, url, checkpoints, finishStartupProfile);
      if (blackDogMatrix) return runBlackDogMatrix(cdp, url, checkpoints, finishStartupProfile);
      if (namedDeadMatrix) return runNamedDeadSideRoute(cdp, url, checkpoints, finishStartupProfile);
      if (rooksMapMatrix) return runRooksMapMatrix(cdp, url, checkpoints, finishStartupProfile);
      if (millersMeasureMatrix) return runMillersMeasureMatrix(cdp, url, checkpoints, finishStartupProfile);
      if (bannerlessMatrix) return runBannerlessMatrix(cdp, url, checkpoints, finishStartupProfile);
      if (endingMatrix) return runOpeningEndingMatrix(cdp, url, checkpoints, finishStartupProfile);
      if (throughFinale) return runOpeningThroughFinale(cdp, url, checkpoints, finishStartupProfile);
      if (throughAssembly) return runOpeningThroughAssembly(cdp, url, checkpoints, finishStartupProfile);
      if (throughLastWitness) return runOpeningThroughLastWitness(cdp, url, checkpoints, finishStartupProfile);
      if (throughRecordHall) return runOpeningThroughRecordHall(cdp, url, checkpoints, finishStartupProfile);
      if (throughCastle) return runOpeningThroughCastle(cdp, url, checkpoints, finishStartupProfile);
      if (throughSoldier) return runOpeningThroughSoldier(cdp, url, checkpoints, finishStartupProfile);
      if (throughAsh) return runOpeningThroughAsh(cdp, url, checkpoints, finishStartupProfile);
      if (throughAshPreparation) return runOpeningThroughAshPreparation(cdp, url, checkpoints, finishStartupProfile);
      if (throughNames) return runOpeningThroughNames(cdp, url, checkpoints, finishStartupProfile);
      if (throughRootbound) return runOpeningThroughRootbound(cdp, url, checkpoints, finishStartupProfile);
      if (throughRegister) return runOpeningThroughRegister(cdp, url, checkpoints, finishStartupProfile);
      if (throughTeeth) return runOpeningThroughTeeth(cdp, url, checkpoints, finishStartupProfile);
      if (throughBellEater) return runOpeningThroughBellEater(cdp, url, checkpoints, finishStartupProfile);
      if (throughCemetery) return runOpeningAndCemetery(cdp, url, checkpoints, finishStartupProfile);
      if (openingOnly) return runOpeningCampaign(cdp, url, checkpoints, finishStartupProfile);
      return (async () => {
        await runScenario(cdp, url, "greyfen-wychwood-return", ["wychwood", "greyfen"], checkpoints, finishStartupProfile);
        await runScenario(cdp, url, "greyfen-deep-woods-return", ["deep_wood", "wychwood", "greyfen"], checkpoints, finishStartupProfile);
        await runScenario(
          cdp,
          url,
          "greyfen-castle-record-hall-return",
          ["vargan_approach", "vargan_court", "record_hall", "vargan_court", "vargan_approach"],
          checkpoints,
          finishStartupProfile
        );
        return telemetry(cdp);
      })();
    }, `${name} player route`, routeTimeoutMs, routeScope.revoke);
    const targetMisses = [];
    if (fullCampaign) {
      const perf = finalState?.performance || {};
      if (!mobileMode && (enforcePerformance || functionalCandidate) && (Number(perf.samples || 0) < 120
        || !Number.isFinite(perf.average_fps) || !Number.isFinite(perf.one_percent_low_fps))) {
        throw new Error(`${name} campaign performance sample is incomplete`);
      }
      if (!mobileMode && enforcePerformance && (
        Number(perf.average_fps || 0) < 32 || Number(perf.one_percent_low_fps || 0) < 30
      )) {
        throw new Error(
          `${name} campaign performance ${Number(perf.average_fps || 0).toFixed(2)} avg / `
          + `${Number(perf.one_percent_low_fps || 0).toFixed(2)} 1% low`
        );
      }
      if (!mobileMode && enforcePerformance) {
        requireZonePerformance(cdp.zonePerformance.summary());
      }
      if (!mobileMode && functionalCandidate) {
        targetMisses.push(...requireZonePerformance(cdp.zonePerformance.summary(), undefined, acceptanceProfile));
        if (perf.average_fps < 32 || perf.one_percent_low_fps < 30) {
          targetMisses.push(`Final campaign: ${perf.average_fps} average / ${perf.one_percent_low_fps} 1% low FPS`);
        }
      }
      if (!mobileMode && !enforcePerformance && !functionalCandidate) {
        checkpoints.push({
          event: "campaign_performance_diagnostic",
          mode: `headless_${rendererMode}`,
          acceptance_gate: "verify_perf_001_graphical_compatibility",
          samples: Number(perf.samples || 0),
          average_fps: Number(perf.average_fps || 0),
          one_percent_low_fps: Number(perf.one_percent_low_fps || 0),
        });
      }
    }
    if (openingOnly && checkpoints.some((checkpoint) => checkpoint.event === "gate_approach_recovery")) {
      throw new Error(`${name} opening route required QA position recovery`);
    }
    const renderer = await inspectRenderer(cdp);
    if (rendererMode === "hardware" && (!renderer?.unmasked_renderer
      || /swiftshader|llvmpipe|software|basic render/i.test(renderer.unmasked_renderer))) {
      throw new Error(`Hardware renderer not proven: ${JSON.stringify(renderer)}`);
    }
    const errors = consoleErrors(cdp);
    if (errors.length) throw new Error(`${name} console error: ${errors[0]}`);
    const audioContexts = await observedAudioContexts(cdp, name);
    if ((fullCampaign || openingSaveContinue)
      && !audioContexts.some((context) => context.type === "realtime" && context.state === "running")) {
      throw new Error(`${name} Web Audio context never entered running state after real browser input`);
    }
    const networkFailures = cdp.events.filter((event) => event.method === "Network.loadingFailed")
      .map((event) => event.params)
      .filter((failure) => !failure.canceled);
    if (networkFailures.length) {
      throw new Error(`${name} network failure: ${networkFailures[0].errorText}`);
    }
    const metrics = await cdp.send("Performance.getMetrics");
    const metric = Object.fromEntries(metrics.metrics.map((entry) => [entry.name, entry.value]));
    const jsHeapMb = Number.isFinite(metric.JSHeapUsedSize)
      ? Number((metric.JSHeapUsedSize / 1048576).toFixed(1)) : null;
    const firefoxMemory = name === "Firefox"
      ? measureFirefoxContentMemory(firefoxBrowser?.process()?.pid, profile) : null;
    const chromiumMemory = name === "Firefox" ? null
      : measureChromiumRendererMemory(name, browser?.pid, profile);
    const runtimeMemoryMb = firefoxMemory ? firefoxMemory.content_private_mb : chromiumMemory.renderer_private_mb;
    if ((!Number.isFinite(runtimeMemoryMb) || runtimeMemoryMb <= 0) && (fullCampaign || functionalCandidate)) throw new Error(`${name} runtime memory was not measured`);
    if (runtimeMemoryMb !== null && runtimeMemoryMb >= 450) {
      const message = `${name} runtime memory ${runtimeMemoryMb} MB exceeds the below-450 MB limit`;
      if (!functionalCandidate) throw new Error(message);
      targetMisses.push(message);
    }
    for (const timing of cdp.startupRuns || []) {
      const navigationTargetMs = timing.kind === "warm_continue" ? 7000 : 15000;
      if (timing.navigation_to_control_ms > navigationTargetMs) targetMisses.push(`${timing.kind || "cold_new_game"} navigation to control: ${timing.navigation_to_control_ms} ms exceeds ${navigationTargetMs} ms`);
      if (timing.click_to_control_ms > 750) targetMisses.push(`${timing.kind === "warm_continue" ? "Continue" : "Prewarmed New Game"}: ${timing.click_to_control_ms} ms exceeds 750 ms`);
    }
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
    completedSuccessfully = !startupDiagnostic;
    return {
      browser: name,
      status: startupDiagnostic ? "diagnostic" : "pass",
      acceptance_profile: acceptanceProfile,
      performance_certified: !functionalCandidate && enforcePerformance,
      target_misses: targetMisses,
      listening_reviewed: false,
      observation_mode: productionObserver ? "production_read_only" : "qa_diagnostic",
      route_scope: browserSmoke ? "browser_compatibility_smoke" : fullCampaign ? "campaign_main_player_driven" : endingMatrix ? "ending_matrix_partial" : shrineMatrix ? "shrine_matrix_partial" : reportMatrix ? "report_matrix_partial" : widowMatrix ? "widow_matrix_partial" : ironMatrix ? "iron_matrix_partial" : returnedSoldierMatrix ? "returned_soldier_matrix_partial" : bitterRootsMatrix ? "bitter_roots_matrix_partial" : blackDogMatrix ? "black_dog_matrix_partial" : namedDeadMatrix ? "named_dead_route_partial" : rooksMapMatrix ? "rooks_map_matrix_partial" : millersMeasureMatrix ? "millers_measure_matrix_partial" : bannerlessMatrix ? "bannerless_matrix_partial" : openingSaveContinue ? "opening_save_continue_partial" : throughFinale ? "opening_finale_partial" : throughAssembly ? "opening_assembly_partial" : throughLastWitness ? "opening_last_witness_partial" : throughRecordHall ? "opening_record_hall_partial" : throughCastle ? "opening_castle_partial" : throughSoldier ? "opening_soldier_partial" : throughAsh ? "opening_ash_partial" : throughAshPreparation ? "opening_ash_prep_partial" : throughNames ? "opening_names_partial" : throughRootbound ? "opening_rootbound_partial" : throughRegister ? "opening_register_partial" : throughTeeth ? "opening_teeth_partial" : throughBellEater ? "opening_bell_eater_partial" : throughCemetery ? "opening_cemetery_partial" : openingOnly ? "opening_route" : "gate_circuit",
      failure: startupDiagnostic ? "Startup observation override is diagnostic evidence, not acceptance" : undefined,
      startup_timings: cdp.startupTimings,
      startup_runs: cdp.startupRuns || [],
      renderer_mode: rendererMode,
      presentation_mode: presentationMode,
      renderer,
      elapsed_ms: Date.now() - started,
      transport: cdp.transportSummary(),
      checkpoints,
      console_errors: [],
      console_warnings: consoleWarnings(cdp),
      network_failures: [],
      network_timeline: networkTimeline(cdp),
      js_heap_mb: jsHeapMb,
      runtime_memory_mb: runtimeMemoryMb,
      memory_method: firefoxMemory?.method || chromiumMemory.method,
      firefox_process_memory: firefoxMemory,
      chromium_process_memory: chromiumMemory,
      runtime_resources: resources.filter((entry) => /index\.(js|wasm|pck)/.test(entry.name)),
      loading_timeline: loadingTimeline(cdp),
      console_messages: consoleMessages(cdp).slice(-120),
      audio_context_timeline: audioContexts,
      audio_unlock: audioContexts.some((context) => context.type === "realtime" && context.state === "running")
          ? "observed_running" : "not_observed",
      final_screenshot: finalScreenshot,
      final_telemetry: finalState || await telemetry(cdp),
      performance_by_zone: cdp.zonePerformance.summary(),
      profile_dir: profile,
      devtools_port: debugPort,
      transport_protocol: name === "Firefox" ? "webdriver_bidi" : "cdp",
      browser_stderr: browserStderr.join("").slice(-12000),
      route_limitations: [
        "Castle Vargan Approach has no direct Greyfen return gate; QA returns Record Hall to Courtyard to Approach.",
        "Deep Woods returns through Wychwood because its authored back gate targets Wychwood.",
      ],
    };
  } catch (error) {
    if (cdp) {
      await releaseMovementKeys(cdp).catch(() => {});
      failureScreenshot = await capture(
        cdp,
        reportPath.replace(/\.json$/i, `_${name.toLowerCase()}_failure.png`)
      ).catch(() => "");
    }
    return {
      browser: name,
      status: "fail",
      acceptance_profile: acceptanceProfile,
      startup_timings: cdp?.startupTimings,
      startup_runs: cdp?.startupRuns || [],
      renderer_mode: rendererMode,
      presentation_mode: presentationMode,
      renderer: cdp ? await inspectRenderer(cdp).catch(() => null) : null,
      failure: error.message,
      elapsed_ms: Date.now() - started,
      transport: cdp ? cdp.transportSummary() : null,
      checkpoints,
      console_errors: cdp ? consoleErrors(cdp) : [],
      network_timeline: cdp ? networkTimeline(cdp) : [],
      console_warnings: cdp ? consoleWarnings(cdp) : [],
      loading_timeline: cdp ? loadingTimeline(cdp) : [],
      console_messages: cdp ? consoleMessages(cdp).slice(-120) : [],
      audio_context_timeline: cdp ? await observedAudioContexts(cdp, name).catch(() => []) : [],
      failure_screenshot: failureScreenshot,
      last_telemetry: cdp ? await telemetry(cdp).catch(() => null) : null,
      performance_by_zone: cdp?.zonePerformance.summary() || {},
      profile_dir: profile,
      devtools_port: debugPort,
      transport_protocol: name === "Firefox" ? "webdriver_bidi" : "cdp",
      browser_stderr: browserStderr.join("").slice(-12000),
    };
  } finally {
    if (cpuProfileStarted && cdp) await finishStartupProfile();
    if (cdp) cdp.close();
    if (firefoxBrowser) await firefoxBrowser.close().catch(() => {});
    if (browser || firefoxBrowser) {
      const ownedProcess = browser || firefoxBrowser.process();
      const browserExit = new Promise((done) => {
        if (!ownedProcess || ownedProcess.exitCode !== null || ownedProcess.signalCode !== null) done();
        else ownedProcess.once("exit", done);
      });
      terminateIsolatedBrowser(ownedProcess, profile);
      await Promise.race([browserExit, sleep(1500)]);
    }
    if (!completedSuccessfully) {
      console.warn(`QA-002 BROWSER ${name}: failed-run profile and earned saves retained: ${profile}`);
    } else if (!(await removeTemporaryProfile(profile))) {
      console.warn(`QA-002 BROWSER ${name}: temporary profile could not be removed: ${profile}`);
    }
  }
}

function terminateIsolatedBrowser(browser, profile) {
  // Kill only the process tree created by this test. The browser root was
  // launched with a unique profile, and taskkill's tree mode covers its
  // renderer/utility children without a blocking WMI scan of every browser
  // process on the machine.
  if (browser?.pid && browser.exitCode === null && browser.signalCode === null) {
    spawnSync("taskkill.exe", ["/PID", String(browser.pid), "/T", "/F"], {
      encoding: "utf8",
      windowsHide: true,
      timeout: 15000,
    });
  }
  // Edge may replace its launcher with a compatibility-layer root, so the
  // original PID can already be gone. Terminate only processes carrying this
  // run's unique user-data directory before removing that directory.
  spawnSync("powershell.exe", ["-NoProfile", "-Command",
    "$profile=$env:ASHEN_QA_PROFILE; Get-CimInstance Win32_Process | "
    + "Where-Object { $_.Name -in @('chrome.exe','msedge.exe','firefox.exe') -and $_.CommandLine -like ('*'+$profile+'*') } | "
    + "ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }",
  ], {
    encoding: "utf8",
    windowsHide: true,
    timeout: 15000,
    env: { ...process.env, ASHEN_QA_PROFILE: profile },
  });
}

const report = {
  schema_version: 1,
  acceptance_profile: acceptanceProfile,
  release_basis: functionalCandidate ? "functionality-certified candidate; numerical targets not certified" : "strict",
  listening_reviewed: false,
  ticket: fullCampaign ? "WEB-002" : "QA-002",
  status: diagnosticPreparation ? "diagnostic" : "pass",
  observation_mode: productionObserver ? "production_read_only" : "qa_diagnostic",
  route_scope: browserSmoke ? "browser_compatibility_smoke" : fullCampaign ? "campaign_main_player_driven" : endingMatrix ? "ending_matrix_partial" : shrineMatrix ? "shrine_matrix_partial" : reportMatrix ? "report_matrix_partial" : widowMatrix ? "widow_matrix_partial" : ironMatrix ? "iron_matrix_partial" : returnedSoldierMatrix ? "returned_soldier_matrix_partial" : bitterRootsMatrix ? "bitter_roots_matrix_partial" : blackDogMatrix ? "black_dog_matrix_partial" : namedDeadMatrix ? "named_dead_route_partial" : rooksMapMatrix ? "rooks_map_matrix_partial" : millersMeasureMatrix ? "millers_measure_matrix_partial" : bannerlessMatrix ? "bannerless_matrix_partial" : openingSaveContinue ? "opening_save_continue_partial" : throughFinale ? "opening_finale_partial" : throughAssembly ? "opening_assembly_partial" : throughLastWitness ? "opening_last_witness_partial" : throughRecordHall ? "opening_record_hall_partial" : throughCastle ? "opening_castle_partial" : throughSoldier ? "opening_soldier_partial" : throughAsh ? "opening_ash_partial" : throughAshPreparation ? "opening_ash_prep_partial" : throughNames ? "opening_names_partial" : throughRootbound ? "opening_rootbound_partial" : throughRegister ? "opening_register_partial" : throughTeeth ? "opening_teeth_partial" : throughBellEater ? "opening_bell_eater_partial" : throughCemetery ? "opening_cemetery_partial" : openingOnly ? "opening_route" : "gate_circuit",
  complete_qa_002_acceptance: false,
  export_dir: exportDir,
  artifact: candidateIdentity,
  qa_temp_root: QA_TEMP_ROOT,
  browsers: [],
};
try {
  for (const [name, executable] of browsers) {
    const result = await testBrowser(name, executable);
    report.browsers.push(result);
    if (result.status !== "pass") throw new Error(`${name}: ${result.failure}`);
    console.log(`${fullCampaign && diagnosticPreparation ? "WEB-002 DIAGNOSTIC" : fullCampaign ? "WEB-002" : "QA-002"} ${name}: ${diagnosticPreparation ? "ROUTE OBSERVED" : "PASS"} - ${result.checkpoints.length} route checkpoints in ${result.elapsed_ms} ms; profile ${result.profile_dir} (cleaned)`);
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
