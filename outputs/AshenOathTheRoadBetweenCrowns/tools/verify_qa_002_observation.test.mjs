import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import vm from "node:vm";
import test from "node:test";
import { ZonePerformanceEvidence } from "./qa_002_zone_performance.mjs";

// Exercise the actual driver functions without starting its HTTP server/browser.
const source = readFileSync(new URL("./verify_qa_002_browser.mjs", import.meta.url), "utf8");
const authoredApproach = source.slice(source.indexOf("function authoredCemeteryDeparture("),
  source.indexOf("function collapseCollinearRoute("));
const functions = source.slice(source.indexOf("async function telemetry(cdp)"), source.indexOf("async function freshCombatState(cdp)"));
const context = vm.createContext({ TELEMETRY_TIMEOUT_MS: 2500, productionObserver: false });
vm.runInContext(`${functions}\nglobalThis.subject = { telemetry, freshTelemetry };`, context);
const { telemetry, freshTelemetry } = context.subject;

test("compatibility smoke proves ordinary input and exact earned Save/Continue without campaign automation", async () => {
  const start = source.indexOf("async function runBrowserSmoke(");
  const end = source.indexOf("async function exerciseBrowserSettings(", start);
  const earned = { player: { position: { x: 0, z: -1 } }, settings: { master_volume: 1 },
    inventory: { coin: 12 }, story: { flags: {} }, quests: { active: ["road"], completed: [] }, zone: "greyfen" };
  const events = [];
  let reads = 0;
  const subject = vm.createContext({
    Date, Math, JSON,
    startNewGame: async () => ({ ...earned, player: { position: { x: 0, z: 0 } } }),
    tapGameplayKey: async (_cdp, code) => events.push(code),
    freshTelemetry: async () => ++reads <= 2 ? earned : { ...earned, player: { position: { x: 0, z: -0.5 } } },
    saveThroughPauseMenu: async (_cdp, checkpoints) => checkpoints.push({ event: "manual_save_created" }),
    continueSavedOpening: async (_cdp, _url, checkpoints, stage) => {
      assert.equal(stage, "startup");
      checkpoints.push({ event: "opening_continue_restored" });
      return earned;
    },
  });
  vm.runInContext(`${source.slice(start, end)}\nglobalThis.smoke = runBrowserSmoke;`, subject);
  const checkpoints = [];
  await subject.smoke({}, "http://fixture/?observe=1", checkpoints, () => {});
  assert.deepEqual(events, ["KeyW", "KeyS"]);
  assert.ok(checkpoints.some(event => event.event === "browser_save_durable"));
  assert.ok(checkpoints.some(event => event.event === "browser_continue_input"));
  vm.runInContext("continueSavedOpening = async () => ({ ...await freshTelemetry(), inventory: { coin: 999 } })", subject);
  reads = 0;
  await assert.rejects(subject.smoke({}, "http://fixture/", [], () => {}), /earned inventory/);
});

test("functional response waits remain finite and strict deadlines are unchanged", async () => {
  let now = 0;
  const subject = vm.createContext({ functionalCandidate: false, timeoutMs: 5000,
    Date: { now: () => now }, sleep: async ms => { now += ms; } });
  const start = source.indexOf("async function waitFor(");
  const end = source.indexOf("async function withDeadline(", start);
  vm.runInContext(`${source.slice(start, end)}\nglobalThis.wait = waitFor;`, subject);
  await assert.rejects(subject.wait(() => now >= 12730, "response", 5000), /timed out/);
  now = 0;
  vm.runInContext("functionalCandidate = true", subject);
  assert.equal(await subject.wait(() => now >= 12730, "response", 5000), true);
  now = 0;
  await assert.rejects(subject.wait(() => false, "missing result", 5000), /timed out/);
  assert.equal(now, 30000);
  now = 0;
  await assert.rejects(subject.wait(() => false, "optional intermediate focus", 420), /timed out/);
  assert.equal(now, 450);
  await assert.rejects(subject.wait(() => { throw Object.assign(new Error("runtime failure"), { fatal: true }); }, "error"), /runtime failure/);
});

test("refresh waits for the current earned save in durable browser storage, never in-memory presence", () => {
  const start = source.indexOf("function persistedSaveMatches(");
  const end = source.indexOf("async function saveThroughPauseMenu(", start);
  const subject = vm.createContext({});
  vm.runInContext(`${source.slice(start, end)}\nglobalThis.matches = persistedSaveMatches;`, subject);
  const state = { zone: "greyfen", settings: { master_volume: 1, custom_bindings: { interact: [{ key: 4194340 }] } },
    story: { flags: { evidence_report: "private" } }, inventory: { items: { redroot_potion: 1 }, coin: 12 },
    quests: { active: ["bell"], completed: ["road"] } };
  const saved = { saved_at_utc: "2026-10-02T00:00:00", zone: "greyfen",
    settings: { ...state.settings, target_fps: 30 }, story_state: state.story, inventory: state.inventory,
    quests: { active: { bell: {} }, completed: { road: {} } } };
  const files = { "ashen_oath_save.json": saved, "ashen_oath_settings.json": saved.settings };
  const now = Date.parse("2026-10-02T00:00:00.500Z");
  assert.equal(subject.matches({}, state, now), false);
  assert.equal(subject.matches(files, state, now), true);
  assert.equal(subject.matches(files, state, now + 2000), false, "older manual slot cannot prove overwrite");
  assert.equal(subject.matches({ ...files, "ashen_oath_settings.json": { ...saved.settings, master_volume: .85 } }, state, now), false);
  assert.equal(subject.matches({ ...files, "ashen_oath_save.json": { ...saved, story_state: { flags: {} } } }, state, now), false);
  assert.equal(subject.matches({ ...files, "ashen_oath_save.json": { invalid_json: true } }, state, now), false);
  const read = source.slice(source.indexOf("async function readBrowserPersistence("), start);
  assert.match(read, /db.transaction\("FILE_DATA", "readonly"\)/);
  assert.match(read, /onupgradeneeded = \(\) => request.transaction.abort\(\)/);
  assert.doesNotMatch(read, /\.put\(|\.delete\(|force_fs_sync|syncfs|GodotFS/);
  const save = source.slice(end, source.indexOf("async function continueSavedOpening(", end));
  assert.match(save, /persistedSaveMatches\(await readBrowserPersistence/);
});

test("cemetery departures follow the existing native gate aisle rather than the cap-crossing segment", () => {
  const routeContext = vm.createContext({});
  vm.runInContext(`${authoredApproach}\nglobalThis.route = authoredCemeteryDeparture;`, routeContext);
  const start = { x: 15.09957, y: 0.02943, z: 9.23792 };
  const original = [start, { x: 0, y: 0, z: start.z }, { x: 0, y: 0, z: -15.2 }];
  const actual = routeContext.route(original, { zone: "greyfen", player: { position: start } });
  assert.equal(actual[1].x, start.x);
  assert.equal(actual[1].z, 8.29);
  assert.deepEqual([actual[2].x, actual[2].z], [9, 8.29]);
  assert.deepEqual([actual[3].x, actual[3].z], [9, 10.45]);
  assert.deepEqual([actual[4].x, actual[4].z], [0, 10.45]);
  const capZ = 9.55;
  assert.ok(Math.abs(start.z - capZ) < 0.31 + 0.32 + 0.035, "recorded direct segment intersects cap clearance");
  assert.ok(Math.abs(actual[2].z - capZ) > 0.31 + 0.32 + 0.035, "authored crossing has capsule clearance");
  assert.equal(routeContext.route(original, { zone: "wychwood", player: { position: start } }), original);
  assert.equal(routeContext.route([start, { x: 16, z: 8 }], { zone: "greyfen", player: { position: start } }).length, 2);
});

test("westbound forge interactions use the native frontage instead of crossing the rack", () => {
  const subject = vm.createContext({});
  vm.runInContext(`${authoredApproach}\nglobalThis.route = authoredGreyfenInteractionDeparture;`, subject);
  const start = { x: 9.2342, y: 0.03, z: -2.0711 };
  const destination = { x: -4.4652, y: 0, z: -0.3702 };
  const points = [start, destination];
  const actual = subject.route(points, { zone: "greyfen", player: { position: start } });
  assert.deepEqual(JSON.parse(JSON.stringify(actual)), [start,
    { x: start.x, y: start.y, z: -4.3 }, { x: 0, y: start.y, z: -4.3 }, destination]);
  // Rack x8.7 +/-0.08, z-1.35 +/-0.725, plus the real player radius0.32.
  assert.ok(actual[1].x > 8.7 + 0.08 + 0.32);
  assert.ok(actual[1].z < -1.35 - 0.725 - 0.32);
  assert.equal(subject.route(points, { zone: "wychwood", player: { position: start } }), points);
  const east = [start, { x: 10.2, z: -.3 }];
  assert.equal(subject.route(east, { zone: "greyfen", player: { position: start } }), east);
});

test("aimed arrows wait for the existing full draw and release both buttons", async () => {
  const inputs = [];
  const delays = [];
  const shotContext = vm.createContext({ viewport: { width: 1280, height: 720 },
    INPUT_TIMEOUT_MS: 3000, sleep: async ms => delays.push(ms), focusGameCanvas: async () => {} });
  const start = source.indexOf("async function fireAimedArrow(");
  const end = source.indexOf("async function fightRootbound(", start);
  vm.runInContext(`${source.slice(start, end)}\nglobalThis.fire = fireAimedArrow;`, shotContext);
  await shotContext.fire({ send: async (method, params) => inputs.push({ method, params }),
    evaluate: async () => {} });
  assert.equal(delays[0], 1100);
  assert.deepEqual(inputs.filter(input => input.method === "Input.dispatchMouseEvent")
    .map(input => [input.params.type, input.params.button, input.params.buttons]), [
      ["mousePressed", "right", 2], ["mousePressed", "left", 3],
      ["mouseReleased", "left", 2], ["mouseReleased", "right", 0],
    ]);
  inputs.length = 0;
  delays.length = 0;
  await shotContext.fire({ send: async (method, params) => inputs.push({ method, params }),
    evaluate: async () => { throw new Error("held aim must not evaluate DOM focus per shot"); } }, 1350, true);
  assert.equal(delays[0], 1350);
  assert.deepEqual(inputs.map(input => [input.params.type, input.params.button, input.params.buttons]),
    [["mousePressed", "left", 3], ["mouseReleased", "left", 2]]);
});

test("Rootbound holds one real aim gesture and releases it on failure without changing game state", async () => {
  const inputs = [];
  const state = { player: { weapon_mode: "bow", health: 100 }, camera: { locked_target_id: "rootbound_colossus" },
    inventory: { items: { standard_arrow: 24, redroot_potion: 3 } }, story: { flags: {} },
    enemies: [{ id: "rootbound_colossus", health: 320, position: { x: 4, z: -10 } }] };
  const subject = vm.createContext({ Date, viewport: { width: 1280, height: 720 }, INPUT_TIMEOUT_MS: 1000,
    tapGameplayKey: async () => {}, focusGameCanvas: async () => {}, sleep: async () => {},
    freshCombatState: async () => state, combatTelemetry: async () => state,
    waitFor: async check => check(), selectActiveEnemy: sample => sample.enemies[0],
    fireAimedArrow: async (_, delay, held) => {
      assert.equal(delay, 1350); assert.equal(held, true);
      throw new Error("actual missing arrow outcome");
    },
  });
  const start = source.indexOf("async function fightRootbound(");
  const end = source.indexOf("async function runOpeningThroughRootbound(", start);
  vm.runInContext(`${source.slice(start, end)}\nglobalThis.fight = fightRootbound;`, subject);
  await assert.rejects(subject.fight({ send: async (method, params) => inputs.push({ method, params }) }, []),
    /actual missing arrow outcome/);
  assert.deepEqual(inputs.filter(entry => entry.method === "Input.dispatchMouseEvent")
    .map(entry => [entry.params.type, entry.params.button]), [["mousePressed", "right"], ["mouseReleased", "right"]]);
  assert.equal(state.inventory.items.standard_arrow, 24);
  assert.equal(state.enemies[0].health, 320);
});

test("campaign healing is earned by crafting and paid shop input, not observation writes", async () => {
  const state = { zone: "greyfen", player: { can_control: true },
    inventory: { items: { redroot_potion: 0 }, ingredients: { redroot: 2, bitterleaf: 1 }, coin: 15 },
    ui: { inventory_visible: false } };
  const actions = [];
  const supplyContext = vm.createContext({
    freshTelemetry: async () => state,
    waitFor: async check => { const result = await check(); assert.ok(result); return result; },
    tapGameplayKey: async (_, code) => { actions.push(code); state.ui.inventory_visible = true; },
    driveToInteraction: async (_, id) => actions.push(id),
    chooseMenuButton: async (_, label) => {
      actions.push(label);
      if (label === "Craft Redroot Potion") {
        state.inventory.items.redroot_potion += 1;
        state.inventory.ingredients.redroot -= 2;
        state.inventory.ingredients.bitterleaf -= 1;
      } else if (label === "Buy Redroot Potion") {
        state.inventory.items.redroot_potion += 1;
        state.inventory.coin -= 6;
      } else if (label === "Close") state.ui.inventory_visible = false;
    },
  });
  const start = source.indexOf("async function prepareCampaignHealing(");
  const end = source.indexOf("async function fireAimedArrow(", start);
  vm.runInContext(`${source.slice(start, end)}\nglobalThis.prepare = prepareCampaignHealing;`, supplyContext);
  const checkpoints = [];
  await supplyContext.prepare({}, checkpoints);
  assert.equal(state.inventory.items.redroot_potion, 3);
  assert.equal(state.inventory.coin, 3);
  assert.equal(actions.filter(action => action === "Buy Redroot Potion").length, 2);
  assert.ok(actions.includes("Tab") && actions.includes("mira_apothecary") && actions.includes("KeyE"));
  assert.equal(checkpoints[0].event, "campaign_healing_prepared");
  state.zone = "deep_wood";
  await assert.rejects(supplyContext.prepare({}, []), /real Greyfen return/);
});

test("automatic boot does not turn optional Crow Flight into a launch gate", () => {
  const expression = source.match(/const hasBootStart = await cdp\.evaluate\(`([\s\S]*?)`\);/)[1];
  const page = vm.createContext({ document: { getElementById: () => ({}) }, window: {} });
  assert.equal(vm.runInContext(expression, page), true);
  page.window.__ashenOathBoot = { engine_start_ms: 12 };
  assert.equal(vm.runInContext(expression, page), false);
});

test("headed certification does not hide its initial browser window or wait until after WebGL to foreground it", () => {
  assert.match(source, /windowsHide: presentationMode !== "headed"/);
  const startup = source.slice(source.indexOf("async function startNewGame("), source.indexOf("async function startNewGame(") + 450);
  const foreground = startup.indexOf('cdp.send("Page.bringToFront")');
  const navigation = startup.indexOf('cdp.send("Page.navigate"');
  assert.ok(foreground >= 0 && navigation > foreground);
});

test("saved reload requires the correct new shell, not completion of background downloads", () => {
  const expressions = [...source.matchAll(/`(location\.href\.startsWith\(\$\{JSON\.stringify\(resumeUrl\)\}\)[^`]+)`/g)];
  assert.equal(expressions.length, 8);
  for (const [, expression] of expressions) {
    const executable = expression.replace("${JSON.stringify(resumeUrl)}", JSON.stringify("http://localhost/index.html?observe=1&resume=42"));
    const page = vm.createContext({ location: { href: "http://localhost/index.html?observe=1&resume=42" },
      document: { readyState: "interactive", getElementById: () => ({}), querySelector: () => ({}) } });
    assert.equal(vm.runInContext(executable, page), true);
    page.location.href = "http://localhost/index.html?observe=1";
    assert.equal(vm.runInContext(executable, page), false);
    page.location.href += "&resume=42";
    page.document.querySelector = () => null;
    assert.equal(vm.runInContext(executable, page), false);
  }
});

test("read-only route query accepts a matching result after a late acknowledgment, never stale data or a resend", async () => {
  let assignmentCount = 0;
  let resultId = 1;
  let assignmentError = "CDP Runtime.evaluate timed out";
  const routeContext = vm.createContext({
    productionObserver: true, commandSequence: 0, TELEMETRY_TIMEOUT_MS: 2500,
    waitFor: async (check) => {
      const result = await check();
      if (!result) throw new Error("read-only route timed out");
      return result;
    },
  });
  const start = source.indexOf("async function routeToCatalogEntry(");
  const end = source.indexOf("function fatal(", start);
  vm.runInContext(`${source.slice(start, end)}\nglobalThis.run = routeToCatalogEntry;`, routeContext);
  const cdp = { sendObservation: async (_, request) => {
    if (request.expression.includes("ReadOnlyRouteQuery =")) {
      assignmentCount += 1;
      throw new Error(assignmentError);
    }
    return { result: { value: { read_only: true, request_id: resultId,
      target_id: "sister_anwen", points: [{ x: 1, z: 2 }] } } };
  } };
  assert.equal((await routeContext.run(cdp, { id: "sister_anwen" })).request_id, 1);
  assert.equal(assignmentCount, 1);
  await assert.rejects(routeContext.run(cdp, { id: "sister_anwen" }), /route timed out/);
  assert.equal(assignmentCount, 2, "only one request per attempt; old request ID cannot pass");
  assignmentError = "JavaScript route failure";
  await assert.rejects(routeContext.run(cdp, { id: "sister_anwen" }), /JavaScript route failure/);
});

test("published route binding accepts only the current genuine result without repeated page evaluation", async () => {
  const routeContext = vm.createContext({ productionObserver: true, commandSequence: 0, TELEMETRY_TIMEOUT_MS: 2500,
    waitFor: async check => { const result = await check(); if (!result) throw new Error("route timed out"); return result; } });
  const start = source.indexOf("async function routeToCatalogEntry(");
  const end = source.indexOf("function fatal(", start);
  vm.runInContext(`${source.slice(start, end)}\nglobalThis.run = routeToCatalogEntry;`, routeContext);
  let queries = 0;
  let target = "sister_anwen";
  const cdp = { routeBindingEnabled: true, lastRouteResult: null, sendObservation: async (_, request) => {
    assert.ok(request.expression.includes("ReadOnlyRouteQuery ="), "Result polling must not evaluate the page");
    queries += 1;
    cdp.lastRouteResult = { read_only: true, request_id: queries, target_id: target, points: [{ x: 1, z: 2 }] };
    throw new Error("CDP Runtime.evaluate timed out");
  } };
  assert.equal((await routeContext.run(cdp, { id: "sister_anwen" })).request_id, 1);
  target = "wrong_target";
  await assert.rejects(routeContext.run(cdp, { id: "sister_anwen" }), /route timed out/);
  cdp.sendObservation = async () => { queries += 1; throw new Error("CDP Runtime.evaluate timed out"); };
  await assert.rejects(routeContext.run(cdp, { id: "sister_anwen" }), /route timed out/);
  assert.equal(queries, 3, "Exactly one actual query is issued per attempt");
});

test("dialogue mouse selection uses rendered hit bounds without requiring keyboard focus or DOM evaluation", async () => {
  const inputs = [];
  const cdp = { lastObservation: {
    dialogue: { visible: true, page: 2, focused_action: -1, actions: ["Cleanse", "Disturb", "Bind"] },
    ui: { viewport: { x: 1280, y: 720 }, buttons: [
      { text: "Cleanse", enabled: true, position: { x: 248, y: 540 }, size: { x: 784, y: 34 } },
      { text: "Disturb", enabled: true, position: { x: 248, y: 579 }, size: { x: 784, y: 34 } },
      { text: "Bind", enabled: true, position: { x: 248, y: 618 }, size: { x: 784, y: 34 } },
    ] },
  }, send: async (method, params) => { inputs.push({ method, params }); } };
  const clickContext = vm.createContext({
    viewport: { width: 1280, height: 720 }, INPUT_TIMEOUT_MS: 3000,
    sleep: async () => {}, waitFor: async check => { const result = check(); assert.ok(result); return result; },
  });
  const start = source.indexOf("async function clickDialogueAction(");
  const end = source.indexOf("async function advanceDialogueInput(", start);
  vm.runInContext(`${source.slice(start, end)}\nglobalThis.click = clickDialogueAction;`, clickContext);
  assert.equal(await clickContext.click(cdp, "Disturb", 2), "Disturb");
  assert.equal(inputs[1].method, "Input.dispatchMouseEvent");
  assert.equal(inputs[1].params.type, "mousePressed");
  assert.equal(inputs[1].params.x, 640);
  assert.equal(inputs[1].params.y, 596);
  assert.equal(inputs[2].params.type, "mouseReleased");
  assert.ok(inputs.every(input => input.method !== "Runtime.evaluate"));
  cdp.lastObservation.ui.buttons[1].position.y = 710;
  await assert.rejects(clickContext.click(cdp, "Disturb", 2), /outside the viewport/);
  assert.equal(inputs.length, 3, "clipped actions must fail before dispatching a click");
});

test("lost dialogue acknowledgements require a new actual page outcome and never replay activation", async () => {
  const subject = vm.createContext({
    viewport: { width: 1280, height: 720 }, INPUT_TIMEOUT_MS: 3000,
    sleep: async () => {}, waitFor: async check => {
      const result = check();
      if (!result) throw new Error("delivered dialogue click timed out");
      return result;
    },
  });
  const start = source.indexOf("async function clickDialogueAction(");
  const end = source.indexOf("async function advanceDialogueInput(", start);
  vm.runInContext(`${source.slice(start, end)}\nglobalThis.click = clickDialogueAction;`, subject);
  const initial = () => ({ timestamp_ms: 100, dialogue: { visible: true, page: 2, pages: 3, actions: ["Continue"] },
    ui: { viewport: { x: 1280, y: 720 }, buttons: [
      { text: "Continue", enabled: true, position: { x: 248, y: 540 }, size: { x: 784, y: 34 } },
    ] } });
  for (const lostEdge of ["mousePressed", "mouseReleased"]) {
    const edges = [];
    const cdp = { lastObservation: initial(), send: async (method, params) => {
      if (method !== "Input.dispatchMouseEvent") return;
      edges.push(params.type);
      if (params.type === "mouseReleased") cdp.lastObservation = {
        timestamp_ms: 110, dialogue: { visible: false, page: 2, pages: 3 },
      };
      if (params.type === lostEdge) throw new Error("CDP Input.dispatchMouseEvent timed out");
    } };
    assert.equal(await subject.click(cdp, "", 2), "Continue");
    assert.deepEqual(edges, ["mousePressed", "mouseReleased"]);
  }
  for (const outcome of [
    { timestamp_ms: 100, dialogue: { visible: false, page: 2, pages: 3 } },
    { timestamp_ms: 110, dialogue: { visible: true, page: 2, pages: 3 } },
    { timestamp_ms: 110, dialogue: { visible: false, page: 2, pages: 4 } },
  ]) {
    const cdp = { lastObservation: initial(), send: async (method, params) => {
      if (params?.type !== "mouseReleased") return;
      cdp.lastObservation = outcome;
      throw new Error("CDP Input.dispatchMouseEvent timed out");
    } };
    await assert.rejects(subject.click(cdp, "", 2), /delivered dialogue click timed out/);
  }
  let released = false;
  const cdp = { lastObservation: initial(), send: async (method, params) => {
    if (params?.type === "mouseReleased") released = true;
    if (params?.type === "mousePressed") throw new Error("CDP socket closed");
  } };
  await assert.rejects(subject.click(cdp, "", 2), /socket closed/);
  assert.equal(released, true);
});

test("dialogue pointer handoff respects the Web guard and requires real capture after an acknowledgement timeout", async () => {
  const cdp = { lastObservation: { timestamp_ms: 100 } };
  const delays = [];
  const subject = vm.createContext({
    driveToInteraction: async () => ({}), findInteraction: () => null,
    tapGameplayKey: async () => {}, dispatchKey: async () => {},
    sleep: async ms => delays.push(ms), dialogueInput: "mouse",
    freshDialogueState: async () => ({ visible: delays.length === 1, page: 0, pages: 1 }),
    advanceDialogueInput: async () => {}, telemetry: async () => ({ zone: "greyfen" }),
    waitFor: async check => {
      const result = await check();
      if (!result) throw new Error("pointer outcome timed out");
      return result;
    },
    clickAttack: async () => {
      assert.ok(delays.includes(400), "capture must follow InputRouter's 350 ms guard");
      cdp.lastObservation = { timestamp_ms: 110, dialogue: { visible: false },
        player: { can_control: true }, paused: false, mouse_mode: 2 };
      throw new Error("CDP Input.dispatchMouseEvent timed out");
    },
  });
  const start = source.indexOf("async function useInteraction(");
  const end = source.indexOf("function movementKeyToward(", start);
  vm.runInContext(`${source.slice(start, end)}\nglobalThis.run = useInteraction;`, subject);
  const checkpoints = [];
  await subject.run(cdp, "sister_anwen", checkpoints, true);
  assert.equal(checkpoints.at(-1).event, "interaction_used");
  subject.clickAttack = async () => {
    cdp.lastObservation = { timestamp_ms: 120, dialogue: { visible: false },
      player: { can_control: true }, paused: false, mouse_mode: 0 };
    throw new Error("CDP Input.dispatchMouseEvent timed out");
  };
  delays.length = 0;
  await assert.rejects(subject.run(cdp, "sister_anwen", [], true), /pointer outcome timed out/);
});

test("combat clicks always release the physical button and do not accept missing acknowledgements", async () => {
  const subject = vm.createContext({ viewport: { width: 1280, height: 720 },
    INPUT_TIMEOUT_MS: 3000, sleep: async () => {} });
  const start = source.indexOf("async function clickAttack(");
  const end = source.indexOf("function selectActiveEnemy(", start);
  vm.runInContext(`${source.slice(start, end)}\nglobalThis.click = clickAttack;`, subject);
  const edges = [];
  await assert.rejects(subject.click({ send: async (_, params) => {
    if (!params?.type) return;
    edges.push(params.type);
    if (params.type === "mousePressed") throw new Error("CDP Input.dispatchMouseEvent timed out");
  } }), /timed out/);
  assert.deepEqual(edges, ["mousePressed", "mouseReleased"]);
});

test("shrine assertion requires the actual outcome and completed quest, not an erased active array", async () => {
  let state = { story: { flags: { crow_shrine_state: "cleansed" } },
    quests: { completed: ["main_bell_beneath_greyfen"], objectives_done: {} } };
  const shrineContext = vm.createContext({
    runOpeningToShrine: async () => {}, useInteraction: async () => {},
    freshTelemetry: async () => state,
  });
  const start = source.indexOf("async function runOpeningAndCemetery(");
  const end = source.indexOf("async function continueSavedShrine(", start);
  vm.runInContext(`${source.slice(start, end)}\nglobalThis.run = runOpeningAndCemetery;`, shrineContext);
  assert.equal(await shrineContext.run({}, "", [], () => {}), state);
  state = { story: { flags: { crow_shrine_state: "bound" } }, quests: { completed: ["main_bell_beneath_greyfen"] } };
  await assert.rejects(shrineContext.run({}, "", [], () => {}), /cleansed state/);
  state = { story: { flags: { crow_shrine_state: "cleansed" } }, quests: { completed: [] } };
  await assert.rejects(shrineContext.run({}, "", [], () => {}), /cleansed state/);
});

test("a resolved shrine focus activates a prop without requiring a human-speaker standing route", async () => {
  const state = { ready: true, zone: "greyfen", paused: false,
    player: { can_control: true, position: { x: 16.4105, z: 7.8657 } },
    focus: { id: "crow_shrine_choice" },
    interactions: [{ id: "crow_shrine_choice", type: "dialogue", distance: 0.272,
      position: { x: 16.35, z: 7.7 } }],
  };
  const routeContext = vm.createContext({
    telemetry: async () => state,
    freshTelemetry: async () => state,
    findInteraction: (sample, id) => sample.interactions.find(entry => entry.id === id),
    routeToCatalogEntry: async () => { throw new Error("unnecessary speaker route"); },
  });
  const start = source.indexOf("async function driveToInteraction(");
  const end = source.indexOf("async function useInteraction(", start);
  vm.runInContext(`${authoredApproach}\n${source.slice(start, end)}\nglobalThis.run = driveToInteraction;`, routeContext);
  const checkpoints = [];
  assert.equal(await routeContext.run({}, "crow_shrine_choice", checkpoints), state);
  assert.equal(checkpoints[0].event, "interaction_focus");
  state.interactions[0].id = "sister_anwen";
  state.focus.id = "sister_anwen";
  await assert.rejects(routeContext.run({}, "sister_anwen", []), /unnecessary speaker route/);
});

test("a competing herb focus requires a real bounded standing move, never a target override", async () => {
  const target = { id: "ritual_stones", type: "clue", distance: 0.25, position: { x: 8, y: 0, z: -10 } };
  const state = { ready: true, zone: "wychwood", paused: false,
    player: { can_control: true, position: { x: 8.16, y: 0, z: -10.18 } },
    camera: { yaw: 2.48 }, focus: { id: "bitter_roots", position: { x: 8, z: -7.8 } } };
  const movements = [];
  const routeContext = vm.createContext({
    telemetry: async () => state, findInteraction: () => target,
    routeToCatalogEntry: async () => ({ points: [target.position] }),
    approachPointWithReplan: async (_, point, timeout, tolerance) => {
      movements.push({ point, timeout, tolerance }); state.player.position = point; return state;
    },
    holdTowardPoint: async () => { throw new Error("must not return to the prop center"); },
    turnCameraToward: async () => {
      if (movements.length && state.camera.yaw === 0) state.focus = { id: "ritual_stones" };
      state.camera.yaw = 0;
    },
    sleep: async () => {},
  });
  const start = source.indexOf("async function driveToInteraction(");
  const end = source.indexOf("async function useInteraction(", start);
  vm.runInContext(`${authoredApproach}\n${source.slice(start, end)}\nglobalThis.run = driveToInteraction;`, routeContext);
  const checkpoints = [];
  await routeContext.run({}, "ritual_stones", checkpoints);
  assert.equal(movements.length, 1);
  assert.equal(movements[0].point.x, 8);
  assert.equal(movements[0].point.z, -12.2);
  assert.equal(movements[0].timeout, 5000);
  assert.equal(movements[0].tolerance, 0.20);
  for (const rival of [{ x: 8, z: -7.8 }, { x: 10, z: -9.2 }, { x: 5, z: -13 }]) {
    assert.ok(Math.hypot(rival.x - 8, rival.z + 12.2) - 0.20 > 2.8);
  }
  assert.ok(checkpoints.some(entry => entry.event === "interaction_physical_standing_adjustment"));
  assert.equal(checkpoints.at(-1).event, "interaction_focus");
});

test("menu accept sends one physical Enter edge without an extra carriage-return text event", async () => {
  const packets = [];
  const keyContext = vm.createContext({ INPUT_TIMEOUT_MS: 10000, sleep: async () => {} });
  const start = source.indexOf("async function dispatchKey(");
  const end = source.indexOf("async function dispatchMovementKey(", start);
  const tapStart = source.indexOf("async function tapKey(");
  const tapEnd = source.indexOf("async function tapGameplayKey(", tapStart);
  vm.runInContext(`${source.slice(start, end)}\n${source.slice(tapStart, tapEnd)}\nglobalThis.run = tapKey;`, keyContext);
  await keyContext.run({ send: async (_, packet) => packets.push(packet) }, "Enter", "Enter", 80, true);
  assert.deepEqual(packets.map(packet => packet.type), ["rawKeyDown", "keyUp"]);
  assert.ok(packets.every(packet => !Object.hasOwn(packet, "text") && packet.windowsVirtualKeyCode === 13));
  const menuStart = source.indexOf("async function chooseMenuButton(");
  const menuEnd = source.indexOf("async function saveThroughPauseMenu(", menuStart);
  assert.match(source.slice(menuStart, menuEnd), /tapKey\(cdp, "Enter", "Enter", 80, true\)/);
});

test("browser settings route restores defaults by real menu cycles and keeps resize and remap proof", async () => {
  const state = { paused: false, player: { can_control: true, position: { x: 0, z: 0 } },
    settings: { master_volume: 0.85, subtitle_scale: 1, reduced_motion: false, quality_preset: "balanced", custom_bindings: {} },
    audio: { muted: false, music_playing: true }, ui: { viewport: { x: 1920, y: 1080 }, buttons: [] } };
  const cycles = { "Master Volume": ["master_volume", [0, 0.35, 0.6, 0.85, 1]],
    "Subtitle Size": ["subtitle_scale", [0.9, 1, 1.2]], "Reduced Motion": ["reduced_motion", [false, true]] };
  const pressed = [];
  let settingsPage = 0;
  let pendingPage = null;
  let pendingSettings = false;
  const pageButtons = () => [{ text: ["Visual Preset", "Master Volume", "Subtitle Size"][settingsPage], focused: true,
    position: { x: 100, y: 100 }, size: { x: 400, y: 34 } },
    { text: "Next Page", enabled: settingsPage < 2 }, { text: "Previous Page", enabled: settingsPage > 0 }];
  const settingContext = vm.createContext({
    freshTelemetry: async () => {
      const current = structuredClone(state);
      if (pendingSettings) { pendingSettings = false; state.ui.active_menu = "settings"; state.ui.buttons = pageButtons(); }
      if (pendingPage !== null) { settingsPage = pendingPage; pendingPage = null; state.ui.buttons = pageButtons(); }
      return current;
    },
    tapGameplayKey: async () => { state.paused = true; state.ui.active_menu = "pause"; },
    waitFor: async check => {
      for (let attempt = 0; attempt < 3; attempt += 1) { const value = await check(); if (value) return value; }
      assert.fail("Expected published settings state");
    },
    tapKey: async (_, code) => {
      pressed.push(code);
      if (code === "F9") {
        state.settings.custom_bindings.interact = [{ type: "key", keycode: 123 }];
        state.ui.buttons = [{ text: "Interact F9", focused: true }];
      }
    },
    chooseMenuButton: async (_, label) => {
      pressed.push(label);
      if (cycles[label]) {
        const [key, values] = cycles[label]; state.settings[key] = values[(values.indexOf(state.settings[key]) + 1) % values.length];
      }
      if (label === "Settings") { pendingSettings = true; state.ui.active_menu = "pause"; state.ui.buttons = []; }
      if (label === "Next Page" || label === "Previous Page") {
        assert.ok(label === "Next Page" ? settingsPage < 2 : settingsPage > 0);
        pendingPage = settingsPage + (label === "Next Page" ? 1 : -1);
      }
      if (label === "Reset Defaults") state.settings.custom_bindings = {};
      if (label === "Resume") { state.paused = false; state.player.can_control = true; }
    },
    viewport: { width: 1280, height: 720 }, sleep: async () => {},
  });
  const start = source.indexOf("async function exerciseBrowserSettings(");
  const end = source.indexOf("async function runOpeningThroughAshPreparation(", start);
  vm.runInContext(`${source.slice(start, end)}\nglobalThis.run = exerciseBrowserSettings;`, settingContext);
  const checkpoints = [];
  const dimensions = [];
  const cdp = { send: async (_, size) => dimensions.push([size.width, size.height]) };
  const changed = await settingContext.run(cdp, checkpoints);
  assert.equal(changed.settings.master_volume, 1);
  assert.equal(changed.settings.subtitle_scale, 1.2);
  assert.equal(changed.settings.reduced_motion, true);
  assert.deepEqual(dimensions, [[1920, 1080], [1280, 720]]);
  assert.ok(pressed.includes("F9"));
  await settingContext.run(cdp, checkpoints, changed.original);
  assert.equal(state.settings.master_volume, 0.85);
  assert.equal(state.settings.subtitle_scale, 1);
  assert.equal(state.settings.reduced_motion, false);
  assert.deepEqual(state.settings.custom_bindings, {});
  assert.equal(checkpoints.at(-1).event, "browser_defaults_restored");
});

test("precision digital holds release on observed overshoot instead of walking away", async () => {
  let now = 0;
  const distance = [0.21, 0.1, 0.17];
  const inputs = [];
  const holdContext = vm.createContext({
    Date: { now: () => now }, noRearm: false,
    telemetry: async () => ({ player: { position: { x: distance.shift(), z: 0 } } }),
    releaseMovementKeys: async () => {},
    dispatchMovementKey: async (_, code, key, pressed) => inputs.push({ code, key, pressed }),
    startMovementHeartbeat: () => async () => {}, sleep: async duration => { now += duration; },
  });
  const start = source.indexOf("async function holdAxisTowardPoint(");
  const end = source.indexOf("async function holdTowardPoint(", start);
  vm.runInContext(`${source.slice(start, end)}\nglobalThis.run = holdAxisTowardPoint;`, holdContext);
  await holdContext.run({ send: async () => {} }, [["KeyW", "w"]], { x: 0, z: 0 }, 0.08, 820);
  assert.equal(distance.length, 0);
  assert.ok(now < 820, "overshoot must release before the full hold deadline");
  assert.deepEqual(inputs, [{ code: "KeyW", key: "w", pressed: true },
    { code: "KeyW", key: "w", pressed: false }]);
});

test("blocked contact approach makes a bounded physical side leg and re-reads the living target", async () => {
  const inputs = [];
  let state = { player: { position: { x: 12.25, z: 9.18 } }, camera: { yaw: Math.PI },
    enemies: [{ id: "ghoulkin", active: true, dead: false, health: 55,
      position: { x: 12.21, z: 10.90 } }] };
  const approachContext = vm.createContext({
    combatTelemetry: async () => state,
    selectActiveEnemy: sample => sample.enemies[0],
    movementKeyForCombat: () => ({ code: "KeyW", key: "w" }),
    clamp: (value, low, high) => Math.min(high, Math.max(low, value)),
    holdAxisTowardPoint: async (_, selected, waypoint, tolerance, duration) => {
      inputs.push({ selected: JSON.parse(JSON.stringify(selected)), waypoint, tolerance, duration });
      if (selected[0][0] === "KeyA") {
        assert.ok(waypoint.x > 13.2);
        assert.equal(tolerance, 0.2); assert.equal(duration, 600);
        state = { ...state, player: { position: { x: 12.5, z: 10.1 } } };
      }
      return state;
    }, sleep: async () => {},
  });
  const start = source.indexOf("async function approachMovingEnemy(");
  const end = source.indexOf("async function clickDialogueAction(", start);
  vm.runInContext(`${source.slice(start, end)}\nglobalThis.run = approachMovingEnemy;`, approachContext);
  const result = await approachContext.run({}, 1.1, 5000, "ghoulkin");
  assert.equal(inputs.length, 3);
  assert.equal(inputs[0].selected[0][0], "KeyW");
  assert.equal(inputs[2].selected[0][0], "KeyA");
  assert.ok(Math.hypot(result.player.position.x - 12.21, result.player.position.z - 10.90) <= 1.1);
});

test("locked sword contact approaches real striking distance and attacks without a camera-forward movement override", async () => {
  let state = { player: { position: { x: 0, z: 0 } }, camera: { yaw: 0, locked_target_id: "ghoulkin" },
    enemies: [{ id: "ghoulkin", position: { x: 0, z: -1.72 } }] };
  const moves = [];
  let clicks = 0;
  const attackContext = vm.createContext({
    freshCombatState: async () => state,
    selectActiveEnemy: sample => sample.enemies[0],
    approachMovingEnemy: async (_, distance, timeout, id) => {
      assert.equal(distance, 1.1); assert.equal(id, "ghoulkin");
      state = { ...state, player: { position: { x: 0, z: -0.8 } } };
    }, angleDelta: (a, b) => a - b,
    dispatchMovementKey: async (_, code, key, down) => moves.push({ code, down }),
    clickAttack: async () => { clicks += 1; }, sleep: async () => {},
  });
  const start = source.indexOf("async function attackLiveTarget(");
  const end = source.indexOf("async function fightWychwoodPack(", start);
  vm.runInContext(`${source.slice(start, end)}\nglobalThis.run = attackLiveTarget;`, attackContext);
  await attackContext.run({ send: async () => {} }, 2.84, "ghoulkin");
  assert.equal(clicks, 1);
  assert.ok(moves.every(move => !move.down));
});

test("repeated loading logs cannot erase the original network or runtime failure", () => {
  const transportContext = vm.createContext({ ZonePerformanceEvidence });
  const transportSource = source.slice(source.indexOf("class Cdp {"), source.indexOf("function consoleMessages(cdp)"));
  vm.runInContext(`${transportSource}\nglobalThis.Cdp = Cdp;`, transportContext);
  const cdp = new transportContext.Cdp(null);
  const failure = { method: "Network.loadingFailed", params: { errorText: "connection closed" } };
  cdp.recordEvent(failure);
  for (let i = 0; i < 3000; i += 1) {
    cdp.recordEvent({ method: "Runtime.consoleAPICalled", params: {
      type: "log", timestamp: i, args: [{ value: "LOADING: retry limit" }],
    } });
  }
  assert.equal(cdp.events.length, 2);
  assert.equal(cdp.events[0], failure);
  assert.equal(cdp.events[1].repeat_count, 3000);
  for (let i = 0; i < 3000; i += 1) {
    cdp.recordEvent({ method: "WebAudio.audioNodeCreated", params: { node: i } });
    cdp.recordEvent({ method: "Network.dataReceived", params: {
      requestId: "opening", dataLength: 4, encodedDataLength: 2,
    } });
  }
  assert.equal(cdp.events.length, 3);
  assert.equal(cdp.events[2].params.dataLength, 12000);
  assert.equal(cdp.events[2].params.encodedDataLength, 6000);
});

test("Greyfen west departure follows the native road instead of cutting through Mira's work area", () => {
  const start = { x: -3.4956, y: 0.0294, z: -1.1383 };
  const destination = { x: -18, y: 0, z: -10 };
  const section = source.slice(source.indexOf("function authoredCemeteryDeparture("), source.indexOf("function collapseCollinearRoute("));
  const context = vm.createContext({});
  vm.runInContext(`${section}\nglobalThis.route = authoredGreyfenGateDeparture;`, context);
  const points = [start, destination];
  const route = context.route(points, { zone: "greyfen", player: { position: start } });
  assert.deepEqual(JSON.parse(JSON.stringify(route)), [start,
    { x: 0, y: start.y, z: start.z }, { x: 0, y: start.y, z: -10 }, destination]);
  const mira = { x: -6.8222, z: -0.4077 };
  for (let index = 1; index < route.length; index += 1) {
    const a = route[index - 1], b = route[index];
    const dx = b.x - a.x, dz = b.z - a.z;
    const t = Math.max(0, Math.min(1, ((mira.x - a.x) * dx + (mira.z - a.z) * dz) / (dx * dx + dz * dz)));
    assert.ok(Math.hypot(mira.x - a.x - t * dx, mira.z - a.z - t * dz) > 0.8);
  }
  assert.equal(context.route(points, { zone: "wychwood", player: { position: start } }), points);
  const bridgeStart = { x: 0, y: 0.55, z: 4.5 };
  assert.equal(context.route(points, { zone: "greyfen", player: { position: bridgeStart } }), points);
});

test("Bell-Eater driver holds the actual Q block binding during windup", async () => {
  const inputs = [];
  const boss = { id: "bell_eater", health: 150, position: { x: 1.19, z: 0 } };
  const states = [0, 0.4, 0].map(windup => ({
    player: { health: 100, position: { x: 0, z: 0 }, weapon_mode: "sword" },
    camera: { locked_target_id: "bell_eater" },
    inventory: { items: { standard_arrow: 24 } },
    enemies: [{ ...boss, pending_attack_time: windup }],
  }));
  states.push({ story: { flags: { bell_eater_defeated: true, cemetery_bell_silent: true,
    boss_reward_granted_bell_eater: true, boss_reward_bell_iron: true, boss_reward_chapel_key: true } } });
  const fightContext = vm.createContext({
    combatTelemetry: async () => states.shift(),
    selectActiveEnemy: state => state.enemies[0],
    tapGameplayKey: async (_, code, key, duration) => inputs.push({ code, duration }),
    dispatchKey: async (_, code, key, down, raw) => inputs.push({ code, down, raw }),
    viewport: { width: 1280, height: 720 }, INPUT_TIMEOUT_MS: 1000,
    releaseMovementKeys: async () => {},
    attackLiveTarget: async () => inputs.push({ code: "contact_attack" }),
    approachMovingEnemy: async () => { throw new Error("Unexpected approach"); },
    sleep: async () => {},
  });
  const start = source.indexOf("async function fightBellEater(");
  const end = source.indexOf("async function runOpeningThroughBellEater(", start);
  vm.runInContext(`${source.slice(start, end)}\nglobalThis.run = fightBellEater;`, fightContext);
  const checkpoints = [];
  await fightContext.run({ send: async (_, event) => inputs.push({ code: event.type, button: event.button }) }, checkpoints);
  assert.deepEqual(inputs, [{ code: "KeyC", duration: 1700 },
    { code: "KeyQ", down: true, raw: true }, { code: "KeyQ", down: false, raw: true },
    { code: "contact_attack" }]);
});

test("Bell-Eater driver uses carried healing even during a windup", async () => {
  const inputs = [];
  const states = [{ player: { health: 40, position: { x: 0, z: 0 } },
    inventory: { items: { redroot_potion: 1 } },
    enemies: [{ id: "bell_eater", health: 64, pending_attack_time: 0.4,
      position: { x: 2, z: 0 } }] },
    { story: { flags: { bell_eater_defeated: true, cemetery_bell_silent: true,
      boss_reward_granted_bell_eater: true, boss_reward_bell_iron: true,
      boss_reward_chapel_key: true } } }];
  const context = vm.createContext({
    combatTelemetry: async () => states.shift(),
    selectActiveEnemy: state => state.enemies[0],
    tapGameplayKey: async (_, code) => inputs.push(code),
    releaseMovementKeys: async () => {},
  });
  const start = source.indexOf("async function fightBellEater(");
  const end = source.indexOf("async function runOpeningThroughBellEater(", start);
  vm.runInContext(`${source.slice(start, end)}\nglobalThis.run = fightBellEater;`, context);
  await context.run({}, []);
  assert.deepEqual(inputs, ["KeyR"]);
});

test("Bell-Eater approaches native blade-contact range before its light attack", async () => {
  const inputs = [];
  const state = distance => ({ player: { health: 100, position: { x: 0, z: 0 }, weapon_mode: "sword" },
    camera: { locked_target_id: "bell_eater" },
    enemies: [{ id: "bell_eater", health: 260, pending_attack_time: 0,
      position: { x: distance, z: 0 } }] });
  const states = [state(1.93), state(1.93), state(1.18),
    { story: { flags: { bell_eater_defeated: true, cemetery_bell_silent: true,
      boss_reward_granted_bell_eater: true, boss_reward_bell_iron: true,
      boss_reward_chapel_key: true } } }];
  const context = vm.createContext({
    combatTelemetry: async () => states.shift(), selectActiveEnemy: sample => sample.enemies[0],
    tapGameplayKey: async (_, code) => inputs.push(code),
    approachMovingEnemy: async (_, distance, timeout, id) => inputs.push(["approach", distance, timeout, id]),
    attackLiveTarget: async (_, distance, id) => inputs.push(["attack", distance, id]),
    releaseMovementKeys: async () => {}, sleep: async () => {},
  });
  const start = source.indexOf("async function fightBellEater(");
  const end = source.indexOf("async function runOpeningThroughBellEater(", start);
  vm.runInContext(`${source.slice(start, end)}\nglobalThis.run = fightBellEater;`, context);
  await context.run({}, []);
  assert.deepEqual(inputs, ["KeyC", ["approach", 1.2, 5000, "bell_eater"], ["attack", 1.2, "bell_eater"]]);
});

test("Bell approach requires an observed physical doorway crossing before combat", async () => {
  let actualX = 13.6;
  let actualZ = 8.29;
  const moves = [];
  const routeContext = vm.createContext({
    runOpeningAndCemetery: async () => {},
    freshTelemetry: async () => ({ zone: "greyfen", camera: { yaw: 0 },
      player: { position: { x: 16.2132, y: 0.03, z: 7.6281 } } }),
    approachPointWithReplan: async (_, point, timeout, tolerance) => {
      assert.equal(point.x, 16.2132); assert.equal(point.z, 8.29);
      assert.equal(timeout, 4000); assert.equal(tolerance, 0.12);
      moves.push("aligned");
      return { camera: { yaw: 0 }, player: { position: { x: point.x, z: actualZ } } };
    },
    turnCameraToward: async (_, yaw) => assert.equal(yaw, 0),
    selectActiveEnemy: () => ({ position: { x: 12.67, z: 8.74 } }),
    holdTowardPoint: async (_, point, timeout, zone, accepts, yaw) => {
      assert.equal(point.z, 8.29); assert.equal(timeout, 8000); assert.equal(yaw, 0);
      assert.equal(accepts({ x: 16.36, z: 8.53 }, {}), false);
      assert.equal(accepts({ x: 13.6, z: 8.53 }, {}), true);
      moves.push("crossed");
      return { player: { can_control: true, dead: false, position: { x: actualX, z: 8.53 } } };
    },
    fightBellEater: async () => { throw new Error("validated approach reached combat"); },
  });
  const start = source.indexOf("async function runOpeningThroughBellEater(");
  const end = source.indexOf("async function fightBogWretch(", start);
  vm.runInContext(`${source.slice(start, end)}\nglobalThis.run = runOpeningThroughBellEater;`, routeContext);
  await assert.rejects(routeContext.run({}, "", [], () => {}), /validated approach reached combat/);
  assert.deepEqual(moves, ["aligned", "crossed"]);
  actualX = 16.36;
  await assert.rejects(routeContext.run({}, "", [], () => {}), /doorway crossing/);
  actualZ = 7.6281;
  const movesBefore = moves.length;
  await assert.rejects(routeContext.run({}, "", [], () => {}), /entrance alignment/);
  assert.equal(moves.length, movesBefore + 1, "do not walk across the facade after failed alignment");
});

test("precision waypoint replans pass complete key pairs to both ordinary and alternate holds", async () => {
  let state = { player: { position: { x: 0, z: 1 } }, camera: { yaw: 0 } };
  const holds = [];
  const routeContext = vm.createContext({
    telemetry: async () => state, sleep: async () => {},
    turnCameraToward: async (_, yaw) => yaw,
    holdAxisTowardPoint: async (_, selected) => {
      assert.equal(selected.length, 1);
      assert.equal(selected[0].length, 2);
      assert.ok(selected[0][0].startsWith("Key"));
      assert.equal(selected[0][1].length, 1);
      holds.push(Array.from(selected[0]));
      if (holds.length === 3) state = { player: { position: { x: 0, z: 0 } }, camera: { yaw: 0 } };
    },
    clamp: (value, min, max) => Math.min(max, Math.max(min, value)),
  });
  const start = source.indexOf("async function approachPointWithReplan(");
  const end = source.indexOf("function collapseCollinearRoute(", start);
  vm.runInContext(`${source.slice(start, end)}\nglobalThis.run = approachPointWithReplan;`, routeContext);
  assert.equal((await routeContext.run({}, { x: 0, z: 0 }, 5000, 0.08)).player.position.z, 0);
  assert.deepEqual(holds, [["KeyW", "w"], ["KeyW", "w"], ["KeyD", "d"]]);
});

test("opening combat preserves potions at full health and uses carried healing when injured", async () => {
  const inputs = [];
  const healthy = { player: { position: { x: 0, z: -6.5 }, health: 125 },
    enemies: [{ id: "ghoulkin", active: true, health: 55, position: { x: 1, z: -6.5 } }],
    inventory: { items: { redroot_potion: 3 } } };
  const injured = { ...healthy, player: { ...healthy.player, health: 60 } };
  const states = [healthy, healthy, healthy, healthy, injured, { quests: { fight_complete: true } }];
  let current;
  let now = 0;
  const fightContext = vm.createContext({
    Date: { now: () => now += 6000 },
    combatTelemetry: async () => current = states.shift(),
    sleep: async () => {},
    tapGameplayKey: async (_, code) => inputs.push(code),
    tapKey: async (_, code) => inputs.push(code),
    attackLiveTarget: async () => current,
  });
  const start = source.indexOf("async function fightWychwoodPack(");
  const end = source.indexOf("async function runOpeningCampaign(", start);
  vm.runInContext(`${source.slice(start, end)}\nglobalThis.run = fightWychwoodPack;`, fightContext);
  await fightContext.run({}, []);
  assert.deepEqual(inputs, ["KeyT", "KeyF", "KeyR"]);
});

test("gameplay activation restores canvas focus before the physical key edge", async () => {
  const inputs = [];
  const inputContext = vm.createContext({
    focusGameCanvas: async () => inputs.push("canvas_focus"),
    dispatchKey: async (_, code, key, down, raw) => inputs.push({ code, down, raw }),
    sleep: async () => {},
  });
  const start = source.indexOf("async function tapGameplayKey(");
  const end = source.indexOf("async function acceptDialogue(", start);
  vm.runInContext(`${source.slice(start, end)}\nglobalThis.run = tapGameplayKey;`, inputContext);
  await inputContext.run({ send: async method => inputs.push(method) }, "KeyE", "e");
  assert.deepEqual(inputs, ["Page.bringToFront", "canvas_focus",
    { code: "KeyE", down: false, raw: true },
    { code: "KeyE", down: true, raw: true },
    { code: "KeyE", down: false, raw: true }]);
  inputs.length = 0;
  await inputContext.run({ send: async method => inputs.push(method) }, "KeyT", "t");
  assert.equal(inputs.includes("canvas_focus"), false);
});

test("unlocked melee physically turns toward the live enemy before striking", async () => {
  const inputs = [];
  const enemy = { id: "ghoulkin", position: { x: -1, z: 0 } };
  const state = { player: { position: { x: 0, z: 0 } }, camera: { yaw: 0, locked_target_id: "" } };
  const attackContext = vm.createContext({
    freshCombatState: async () => state,
    selectActiveEnemy: () => enemy,
    turnCameraToward: async (_, yaw) => { inputs.push("camera_turn"); state.camera.yaw = yaw; },
    angleDelta: (a, b) => a - b,
    dispatchMovementKey: async () => {},
    clickAttack: async () => inputs.push("blade_input"),
    sleep: async () => {},
  });
  const start = source.indexOf("async function attackLiveTarget(");
  const end = source.indexOf("async function fightWychwoodPack(", start);
  vm.runInContext(`${source.slice(start, end)}\nglobalThis.run = attackLiveTarget;`, attackContext);
  await attackContext.run({ send: async () => {} }, 2.84, "ghoulkin");
  assert.deepEqual(inputs, ["camera_turn", "blade_input"]);
});

test("conversation approach does not stop at an early cached prompt", async () => {
  let state = { ready: true, zone: "greyfen", focus: { id: "sister_anwen" },
    player: { can_control: true, position: { x: 0, z: 0 } }, camera: { yaw: 0 } };
  const moves = [];
  const actor = { id: "sister_anwen", type: "dialogue", distance: 3,
    position: { x: 3, z: 0 } };
  const routeContext = vm.createContext({
    telemetry: async () => state,
    findInteraction: () => actor,
    routeToCatalogEntry: async () => ({ points: [{ x: 0, z: 0 }, { x: 0.8, z: 0 }] }),
    turnCameraToward: async (_, yaw) => yaw,
    holdTowardPoint: async (_, point) => { moves.push(point); state.player.position = point; return state; },
    waitFor: async callback => callback(), clamp: value => value, sleep: async () => {}, traceMovement: false,
  });
  const start = source.indexOf("async function driveToInteraction(");
  const end = source.indexOf("async function useInteraction(", start);
  vm.runInContext(`${authoredApproach}\n${source.slice(start, end)}\nglobalThis.run = driveToInteraction;`, routeContext);
  const checkpoints = [];
  await routeContext.run({}, "sister_anwen", checkpoints);
  assert.equal(moves.length, 1);
  assert.equal(moves[0].x, 0.8);
  assert.equal(checkpoints.at(-1).event, "interaction_focus");
});

function driver() {
  const old = { player: { position: { z: 9.8 } } };
  const current = { player: { position: { z: 5.49 } } };
  return {
    current,
    lastObservation: old,
    observationQueue: [old],
    zonePerformance: new ZonePerformanceEvidence(),
    async waitForObservation() { return this.observationQueue.pop() || null; },
    async sendObservation() { return { result: { value: current } }; },
  };
}

test("fresh read supersedes queued positions for the next route decision", async () => {
  const cdp = driver();
  assert.equal(await freshTelemetry(cdp), cdp.current);
  assert.equal(await telemetry(cdp), cdp.current);
});

test("failed live observation cannot masquerade as a current waypoint", async () => {
  const cdp = driver();
  cdp.observationQueue.length = 0;
  cdp.sendObservation = async () => { throw new Error("observation unavailable"); };
  await assert.rejects(telemetry(cdp), /observation unavailable/);
});

test("binding arriving during a fresh request is preserved", async () => {
  const cdp = driver();
  const next = { player: { position: { z: 4.5 } } };
  cdp.sendObservation = async () => {
    cdp.observationQueue.push(next);
    return { result: { value: cdp.current } };
  };
  assert.equal(await freshTelemetry(cdp), cdp.current);
  assert.equal(await telemetry(cdp), next);
});

test("production mode reads only the read-only observer global", async () => {
  const production = vm.createContext({ TELEMETRY_TIMEOUT_MS: 2500, productionObserver: true, functionalCandidate: false });
  vm.runInContext(`${functions}\nglobalThis.subject = { telemetry, freshTelemetry };`, production);
  const expressions = [];
  const cdp = {
    observationQueue: [],
    lastObservation: null,
    zonePerformance: new ZonePerformanceEvidence(),
    async waitForObservation() { return null; },
    async sendObservation(_method, params) {
      expressions.push(params.expression);
      return { result: { value: { read_only: true, zone: "greyfen" } } };
    },
  };
  assert.equal((await production.subject.telemetry(cdp)).read_only, true);
  assert.equal((await production.subject.freshTelemetry(cdp)).zone, "greyfen");
  assert.equal(expressions.length, 2);
  assert.ok(expressions.every((expression) => expression.includes("__ashenOathReadOnlyObservation")));
  assert.ok(expressions.every((expression) => !expression.includes("__ASHEN_OATH_QA__")));
});

test("post-input acceptance consumes a new published frame, never the retained pre-input sample", async () => {
  const production = vm.createContext({ TELEMETRY_TIMEOUT_MS: 2500, productionObserver: true, functionalCandidate: false, CDP_EVALUATE_TIMEOUT_MS: 10000 });
  vm.runInContext(`${functions}\nglobalThis.fresh = freshTelemetry;`, production);
  const old = { read_only: true, paused: true };
  const current = { read_only: true, paused: false, player: { can_control: true } };
  const cdp = { observationQueue: [old], lastObservation: old,
    waitForObservation: async timeout => {
      assert.equal(timeout, 2500);
      assert.equal(cdp.observationQueue.length, 0);
      cdp.lastObservation = current;
      return current;
    },
    takeObservation: () => cdp.observationQueue.pop() || null,
    sendObservation: async () => { throw new Error("Runtime transport unavailable"); } };
  assert.equal(await production.fresh(cdp), current);
  cdp.waitForObservation = async () => null;
  await assert.rejects(production.fresh(cdp), /Runtime transport unavailable/);
  cdp.sendObservation = async () => {
    cdp.observationQueue.push(current);
    throw new Error("Runtime acknowledgment unavailable");
  };
  assert.equal(await production.fresh(cdp), current);
  vm.runInContext("functionalCandidate = true;", production);
  cdp.waitForObservation = async timeout => {
    assert.equal(timeout, 10000, "functional publication uses the existing finite command watchdog");
    return current;
  };
  assert.equal(await production.fresh(cdp), current);
});
