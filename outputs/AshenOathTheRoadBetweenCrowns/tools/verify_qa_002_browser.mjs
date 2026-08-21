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
const openingOnly = Boolean(args["opening-only"]);
const mobileMode = Boolean(args.mobile);
// This harness launches headless Chromium/Edge with SwiftShader. It is a
// route, resource, input, and console diagnostic, not the hardware FPS gate.
// Native 720p performance is accepted by verify_perf_001 with the graphical
// Compatibility renderer. Keep an explicit opt-in for future hardware runs.
const enforcePerformance = String(args["enforce-performance"] || "false") === "true";
const INPUT_TIMEOUT_MS = 60000;
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
  send(method, params = {}, timeoutMs = 15000) {
    const id = this.nextId++;
    return new Promise((done, reject) => {
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
      : code === "KeyA" ? 65
      : code === "KeyS" ? 83
      : code === "KeyD" ? 68
      : code === "KeyE" ? 69
      : code === "KeyC" ? 67
      : code === "KeyR" ? 82
      : code === "KeyF" ? 70
      : code === "KeyQ" ? 81
      : code === "ShiftLeft" ? 16
      : code === "Space" ? 32
      : code === "ArrowLeft" ? 37
      : code === "ArrowRight" ? 39
      : code === "Enter" ? 13 : 0,
    modifiers: code === "ShiftLeft" && down ? 8 : 0,
  }, INPUT_TIMEOUT_MS);
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

async function moveCameraRelative(cdp, yaw, dx, dz, duration = 180) {
  const forward = dx * -Math.sin(yaw) + dz * -Math.cos(yaw);
  const right = dx * Math.cos(yaw) + dz * -Math.sin(yaw);
  const movementKeys = [["KeyW", "w"], ["KeyA", "a"], ["KeyS", "s"], ["KeyD", "d"]];
  for (const [code, key] of movementKeys) await dispatchKey(cdp, code, key, false);
  const selected = Math.abs(forward) >= Math.abs(right)
    ? (forward > 0 ? ["KeyW", "w"] : ["KeyS", "s"])
    : (right > 0 ? ["KeyD", "d"] : ["KeyA", "a"]);
  await dispatchKey(cdp, selected[0], selected[1], true);
  await sleep(duration);
  await dispatchKey(cdp, selected[0], selected[1], false);
  for (const [code, key] of movementKeys) await dispatchKey(cdp, code, key, false);
}

async function clickAttack(cdp, heavy = false) {
  await cdp.send("Input.dispatchMouseEvent", {
    type: "mousePressed", x: 640, y: 360, button: heavy ? "right" : "left", clickCount: 1,
  }, INPUT_TIMEOUT_MS);
  await sleep(65);
  await cdp.send("Input.dispatchMouseEvent", {
    type: "mouseReleased", x: 640, y: 360, button: heavy ? "right" : "left", clickCount: 1,
  }, INPUT_TIMEOUT_MS);
}

async function clickDialogueAction(cdp) {
  await cdp.send("Input.dispatchMouseEvent", {
    type: "mouseMoved", x: 640, y: 654, button: "none",
  }, INPUT_TIMEOUT_MS);
  await cdp.send("Input.dispatchMouseEvent", {
    type: "mousePressed", x: 640, y: 654, button: "left", clickCount: 1,
  }, INPUT_TIMEOUT_MS);
  await sleep(70);
  await cdp.send("Input.dispatchMouseEvent", {
    type: "mouseReleased", x: 640, y: 654, button: "left", clickCount: 1,
  }, INPUT_TIMEOUT_MS);
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

async function startNewGame(cdp, expectedUrl) {
  await cdp.send("Page.navigate", { url: expectedUrl });
  await waitFor(async () => cdp.evaluate(
    `location.href.startsWith(${JSON.stringify(expectedUrl.split("?")[0])}) && document.readyState === "complete"`
  ), "QA page load");
  const hasBootStart = await cdp.evaluate(`Boolean(document.getElementById("start"))`);
  if (hasBootStart) {
    await cdp.evaluate(`(() => {
      const start = document.getElementById("start");
      if (!start || start.disabled) return false;
      start.click();
      return true;
    })()`);
  }
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
  // Use the visible in-game menu action for startup. The earlier Enter tap
  // could leave a CDP key-up request pending while the WebGL renderer was
  // compiling the prewarmed scene, which looked like a browser hang even
  // though the launch action had already fired. This remains real player
  // input and matches the stable desktop Web smoke path.
  await cdp.send("Input.dispatchMouseEvent", { type: "mouseMoved", x: 1015, y: 227, button: "none" }, INPUT_TIMEOUT_MS);
  await cdp.send("Input.dispatchMouseEvent", { type: "mousePressed", x: 1015, y: 227, button: "left", clickCount: 1 }, INPUT_TIMEOUT_MS);
  await sleep(70);
  await cdp.send("Input.dispatchMouseEvent", { type: "mouseReleased", x: 1015, y: 227, button: "left", clickCount: 1 }, INPUT_TIMEOUT_MS);
  await waitFor(async () => (await telemetry(cdp))?.new_game_ready, "Greyfen menu prewarm", 15000);
  await sleep(420);
  await cdp.send("Input.dispatchMouseEvent", { type: "mouseMoved", x: 1015, y: 227, button: "none" }, INPUT_TIMEOUT_MS);
  await cdp.send("Input.dispatchMouseEvent", { type: "mousePressed", x: 1015, y: 227, button: "left", clickCount: 1 }, INPUT_TIMEOUT_MS);
  await sleep(70);
  await cdp.send("Input.dispatchMouseEvent", { type: "mouseReleased", x: 1015, y: 227, button: "left", clickCount: 1 }, INPUT_TIMEOUT_MS);
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
    }
    if (!route.length) {
      const routeResult = await qaCommand(cdp, "route_to", gate.position);
      route = routeResult.points || [];
      if (!route.length) throw new Error(`No navigation route to ${target} in ${state.zone}`);
      routeIndex = route.length > 1 ? 1 : 0;
    }
    const player = state.player.position;
    let waypoint = route[Math.min(routeIndex, route.length - 1)] || gate.position;
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
    const desiredYaw = Math.atan2(-dx, -dz);
    const delta = angleDelta(Number(state.camera?.yaw || 0), desiredYaw);
    if (Math.abs(delta) > 0.10) {
      await qaCommand(cdp, "orient_camera", { yaw: desiredYaw });
      await sleep(60);
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
  await clickAttack(cdp, false);
  await sleep(180);
  return arrival;
}

async function traverse(cdp, target, checkpoints) {
  await driveToGate(cdp, target, checkpoints);
  return useGate(cdp, target, checkpoints);
}

async function driveToInteraction(cdp, id, checkpoints, timeout = 45000) {
  const started = Date.now();
  let route = [];
  let routeIndex = 0;
  while (Date.now() - started < timeout) {
    const state = await telemetry(cdp);
    if (!state?.ready || state.transition_pending || state.paused) {
      await sleep(120);
      continue;
    }
    if (state.player && !state.player.can_control) throw new Error(`Player lost control while routing to ${id}`);
    const interaction = findInteraction(state, id);
    if (!interaction) throw new Error(`No ${id} interaction exposed in ${state.zone}`);
    if (state.focus?.id === id && interaction.distance <= 3.0) {
      checkpoints.push({ event: "interaction_focus", id, zone: state.zone, distance: interaction.distance });
      return state;
    }
    if (!route.length) {
      const routeResult = await qaCommand(cdp, "route_to", interaction.position);
      route = routeResult.points || [];
      if (!route.length) throw new Error(`No navigation route to ${id} in ${state.zone}`);
      routeIndex = route.length > 1 ? 1 : 0;
    }
    const player = state.player.position;
    let waypoint = route[Math.min(routeIndex, route.length - 1)] || interaction.position;
    const previous = route[Math.max(0, routeIndex - 1)] || player;
    const passedWaypoint = routeIndex > 0
      && ((player.x - waypoint.x) * (waypoint.x - previous.x) + (player.z - waypoint.z) * (waypoint.z - previous.z)) >= 0;
    if ((Math.hypot(waypoint.x - player.x, waypoint.z - player.z) < 0.72 || passedWaypoint) && routeIndex < route.length - 1) {
      routeIndex += 1;
      waypoint = route[routeIndex];
    }
    const dx = waypoint.x - player.x;
    const dz = waypoint.z - player.z;
    const distance = Math.hypot(dx, dz);
    const desiredYaw = Math.atan2(-dx, -dz);
    const delta = angleDelta(Number(state.camera?.yaw || 0), desiredYaw);
    if (Math.abs(delta) > 0.10) {
      await qaCommand(cdp, "orient_camera", { yaw: desiredYaw });
      await sleep(60);
    }
    if (interaction.distance <= 2.55) {
      await sleep(140);
      continue;
    }
    if (distance > 0.38) await holdKey(cdp, "KeyW", "w", clamp(distance * 32, 80, 240));
    else await sleep(120);
  }
  throw new Error(`Could not focus interaction ${id}`);
}

async function useInteraction(cdp, id, checkpoints, expectsDialogue = false) {
  await driveToInteraction(cdp, id, checkpoints);
  await tapKey(cdp, "KeyE", "e", 80);
  await sleep(220);
  if (expectsDialogue) {
    for (let page = 0; page < 12; page += 1) {
      const state = await telemetry(cdp);
      if (!state?.paused) break;
      // Dialogue rebuilds its action button after every page. Click the rendered
      // control so the packed-browser gate exercises Godot's real pointer path.
      await sleep(260);
      await clickDialogueAction(cdp);
      await sleep(220);
    }
    if ((await telemetry(cdp))?.paused) throw new Error(`${id} dialogue did not close through real input`);
    // Reacquire pointer lock with a direct gameplay gesture. Browsers reject
    // deferred lock requests made by the dialogue callback itself.
    await clickAttack(cdp, false);
    await sleep(180);
  }
  checkpoints.push({ event: "interaction_used", id, zone: (await telemetry(cdp))?.zone });
}

async function fightWychwoodPack(cdp, checkpoints, timeout = 150000) {
  const started = Date.now();
  let lastBeam = 0;
  let lastPotion = Date.now();
  let lastDodge = 0;
  let bombUsed = false;
  while (Date.now() - started < timeout) {
    const state = await telemetry(cdp);
    if (state?.quests?.fight_complete) {
      checkpoints.push({ event: "wychwood_pack_defeated", elapsed_ms: Date.now() - started });
      return;
    }
    const living = (state?.enemies || []).filter((enemy) => enemy.health > 0.01);
    const target = living.find((enemy) => enemy.active) || living[0];
    if (!target) {
      await holdKey(cdp, "KeyW", "w", 300);
      await sleep(150);
      continue;
    }
    const player = state.player.position;
    if (player.dead || Number(player.health) <= 0) throw new Error("Kael died during the Wychwood pack");
    const dx = target.position.x - player.x;
    const dz = target.position.z - player.z;
    const distance = Math.hypot(dx, dz);
    const desiredYaw = Math.atan2(-dx, -dz);
    const delta = angleDelta(Number(state.camera?.yaw || 0), desiredYaw);
    if (Math.abs(delta) > 2.65 && distance > 0.78) {
      await holdKey(cdp, "KeyS", "s", clamp(distance * 32, 90, 220));
      continue;
    }
    if (Math.abs(delta) > 0.10) {
      await holdKey(cdp, delta > 0 ? "ArrowLeft" : "ArrowRight", delta > 0 ? "ArrowLeft" : "ArrowRight", clamp(Math.abs(delta) / 2.2 * 1000, 45, 350));
      if (Math.abs(delta) > 0.24) continue;
    }
    if (!bombUsed && distance <= 6.0) {
      await tapKey(cdp, "KeyF", "f", 70);
      bombUsed = true;
      await sleep(300);
      continue;
    }
    if (distance <= 11.5 && Date.now() - lastBeam > 5200) {
      await holdKey(cdp, "KeyC", "c", 1350);
      lastBeam = Date.now();
      await sleep(240);
      continue;
    }
    if (distance > 1.65) {
      await holdKey(cdp, "KeyW", "w", clamp((distance - 1.35) * 45, 110, 320));
      continue;
    }
    await holdKey(cdp, "KeyW", "w", 75);
    {
      if (Date.now() - lastDodge > 1400) {
        await tapKey(cdp, "Space", " ", 70);
        lastDodge = Date.now();
        await sleep(180);
      }
      {
        await dispatchKey(cdp, "KeyQ", "q", true);
        await clickAttack(cdp, target.health > 45);
        await dispatchKey(cdp, "KeyQ", "q", false);
        await sleep(420);
      }
    }
    if (Date.now() - lastPotion > 5000) {
      await tapKey(cdp, "KeyR", "r", 60);
      lastPotion = Date.now();
    }
  }
  throw new Error(`Wychwood pack did not resolve through real combat input`);
}

async function runOpeningCampaign(cdp, url, checkpoints) {
  const state = await startNewGame(cdp, `${url}&scenario=opening-campaign-${Date.now()}`);
  checkpoints.push({ event: "scenario_start", scenario: "opening-campaign", zone: state.zone });
  await useInteraction(cdp, "sister_anwen", checkpoints, true);
  await traverse(cdp, "wychwood", checkpoints);
  for (const clue of ["corpse", "black_feathers", "claw_marks"]) {
    await useInteraction(cdp, clue, checkpoints, false);
  }
  if (!(await telemetry(cdp))?.quests?.evidence_ready) throw new Error("Three real clue interactions did not resolve evidence threshold");
  await fightWychwoodPack(cdp, checkpoints);
  await traverse(cdp, "greyfen", checkpoints);
  await useInteraction(cdp, "sister_anwen", checkpoints, true);
  const finalState = await telemetry(cdp);
  if (!finalState?.quests?.road_complete || !finalState?.quests?.bell_active) {
    throw new Error(`Real report did not complete Road of Crows and open Bell Beneath Greyfen`);
  }
  checkpoints.push({ event: "opening_complete", zone: finalState.zone, quests: finalState.quests });
  return finalState;
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
    "--no-sandbox",
    "--in-process-gpu",
    "--disable-gpu-sandbox",
    "--use-angle=swiftshader",
    "--enable-unsafe-swiftshader",
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
    // Establish a renderer before enabling Runtime. Chrome's initial
    // about:blank target can accept navigation but never resolves Runtime
    // domain commands in the managed runner.
    await cdp.send("Page.navigate", { url: "data:text/html,<body></body>" });
    await cdp.send("Runtime.enable");

    let finalState;
    if (fullCampaign) {
      finalState = await runFullCampaign(cdp, url, checkpoints);
      const perf = finalState?.performance || {};
      if (!mobileMode && enforcePerformance && Number(perf.samples || 0) < 120) {
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
      if (!mobileMode && !enforcePerformance) {
        checkpoints.push({
          event: "campaign_performance_diagnostic",
          mode: "headless_swiftshader",
          acceptance_gate: "verify_perf_001_graphical_compatibility",
          samples: Number(perf.samples || 0),
          average_fps: Number(perf.average_fps || 0),
          one_percent_low_fps: Number(perf.one_percent_low_fps || 0),
        });
      }
    } else {
      if (openingOnly) {
        finalState = await runOpeningCampaign(cdp, url, checkpoints);
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
    }
    if (openingOnly && checkpoints.some((checkpoint) => checkpoint.event === "gate_approach_recovery")) {
      throw new Error(`${name} opening route required QA position recovery`);
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
    terminateIsolatedBrowser(browser, profile);
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
