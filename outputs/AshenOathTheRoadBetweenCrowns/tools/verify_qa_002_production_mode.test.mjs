import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { spawnSync } from "node:child_process";
import test from "node:test";
import { fileURLToPath } from "node:url";
import vm from "node:vm";

const source = readFileSync(new URL("./verify_qa_002_browser.mjs", import.meta.url), "utf8");
const body = source.slice(source.indexOf("async function qaCommand("), source.indexOf("function findGate("));

test("production mode refuses every QA mutation command before touching the browser", async () => {
  const context = vm.createContext({ productionObserver: true, commandSequence: 0 });
  vm.runInContext(`${body}\nglobalThis.subject = { qaCommand, routeToCatalogEntry };`, context);
  let called = false;
  const cdp = { sendObservation: async () => { called = true; } };
  for (const action of ["stage_gate", "prepare_route", "save", "route_to", "reset_performance"]) {
    await assert.rejects(context.subject.qaCommand(cdp, action), /forbidden/);
  }
  assert.equal(called, false);
});

test("production route query accepts only the matching read-only catalog response", async () => {
  const context = vm.createContext({
    productionObserver: true,
    commandSequence: 0,
    TELEMETRY_TIMEOUT_MS: 2500,
    waitFor: async (predicate) => predicate(),
  });
  vm.runInContext(`${body}\nglobalThis.routeToCatalogEntry = routeToCatalogEntry;`, context);
  let requested = null;
  const cdp = {
    async sendObservation(_method, params) {
      if (params.expression.includes("__ashenOathReadOnlyRouteQuery =")) {
        const json = params.expression.split("__ashenOathReadOnlyRouteQuery = ")[1];
        requested = JSON.parse(json);
        return { result: { value: requested } };
      }
      return { result: { value: {
        read_only: true,
        ok: true,
        request_id: requested.request_id,
        target_id: requested.target_id,
        points: [{ x: 0, y: 0, z: 0 }, { x: 1, y: 0, z: 1 }],
      } } };
    },
  };
  const route = await context.routeToCatalogEntry(cdp, { id: "sister_anwen", position: { x: 1, y: 0, z: 1 } });
  assert.equal(requested.target_id, "sister_anwen");
  assert.equal(route.ok, true);
  assert.equal(route.points.length, 2);
});

test("full-campaign gate invocations require production bytes and read-only observation", () => {
  for (const name of ["run_ticket_gate.ps1", "run_release_gate.ps1"]) {
    const runner = readFileSync(new URL(`./${name}`, import.meta.url), "utf8");
    const pattern = name === "run_ticket_gate.ps1"
      ? /\}\s*elseif\s*\(\$gate -eq "verify_web_002_(?:browser|mobile)"\)\s*\{[\s\S]*?\)\s*\$gateInputs\s+\$cache/g
      : /Invoke-ExternalGate\s+"verify_web_002_(?:browser|mobile)"[\s\S]*?\)\s*-TimeoutOverride\s+\$BrowserRouteTimeoutSeconds/g;
    const gateCalls = [...runner.matchAll(pattern)]
      .map((match) => match[0]);
    assert.ok(gateCalls.length > 0, `${name} has full-campaign gates`);
    for (const call of gateCalls) {
      assert.match(call, /"--export",\s*\$Web\b/, `${name} must select the production export`);
      assert.match(call, /"--production-observer",\s*"true"/, `${name} must use the read-only observer`);
      assert.doesNotMatch(call, /"--export",\s*\$QAWeb\b/, `${name} must not certify the QA export`);
    }
  }
});

test("full-campaign implementation is player-driven and rejects diagnostic shortcuts", () => {
  const routeSource = source.slice(source.indexOf("async function runFullCampaign("), source.indexOf("async function fightCemeteryAmbush("));
  const gateSource = source.slice(source.indexOf("async function driveToGate("), source.indexOf("async function traverse("));
  assert.match(routeSource, /return runOpeningThroughFinale\(cdp, url, checkpoints, onStartupReady\)/);
  assert.doesNotMatch(routeSource, /qaCommand\(|stage_gate|prepare_route|route_to|reset_performance/);
  assert.doesNotMatch(gateSource, /qaCommand\(|stage_gate|prepare_route|route_to|reset_performance/);
  assert.match(source, /if \(fullCampaign && \(!productionObserver \|\| diagnosticPreparation \|\| stopAfter \|\| startupDiagnostic \|\| repeatStartup\)\)/);
  assert.doesNotMatch(source, /Full-campaign certification is pending/);
});

test("full-campaign preflight requires production observation and an uninterrupted run", () => {
  const driver = fileURLToPath(new URL("./verify_qa_002_browser.mjs", import.meta.url));
  const invalid = [
    ["--full-campaign"],
    ["--full-campaign", "--production-observer", "--stop-after", "anwen"],
    ["--full-campaign", "--production-observer", "--startup-observation-ms", "20000"],
    ["--full-campaign", "--production-observer", "--repeat-startup"],
  ];
  for (const flags of invalid) {
    const result = spawnSync(process.execPath, [driver, ...flags], { encoding: "utf8" });
    assert.notEqual(result.status, 0, flags.join(" "));
    assert.match(`${result.stdout}\n${result.stderr}`, /requires production read-only observation and a complete, non-diagnostic run/);
  }
  const ready = spawnSync(process.execPath, [driver, "--full-campaign", "--production-observer",
    "--export", "Z:/ashenoath/nonexistent-candidate"], { encoding: "utf8" });
  assert.notEqual(ready.status, 0);
  assert.match(`${ready.stdout}\n${ready.stderr}`, /export missing/);
});

test("a partial campaign run cannot pass with mutation-capable observation", () => {
  const driver = fileURLToPath(new URL("./verify_qa_002_browser.mjs", import.meta.url));
  const result = spawnSync(process.execPath, [driver, "--through-finale"], { encoding: "utf8" });
  assert.notEqual(result.status, 0);
  assert.match(`${result.stdout}\n${result.stderr}`, /require --production-observer/);
});

test("boot shell activation uses a physical pointer event, not DOM click", async () => {
  const routeSource = source.slice(source.indexOf("async function activateBootShell("), source.indexOf("async function startNewGame("));
  const points = [];
  const context = vm.createContext({
    waitFor: async (predicate) => predicate(),
    clickPoint: async (_cdp, point) => { points.push(point); },
  });
  vm.runInContext(`${routeSource}\nglobalThis.activateBootShell = activateBootShell;`, context);
  let reads = 0;
  await context.activateBootShell({ evaluate: async () => ++reads === 1 ? false : ({ x: 415, y: 260 }) });
  assert.equal(points.length, 1);
  assert.equal(points[0].x, 415);
  assert.equal(points[0].y, 260);
  assert.doesNotMatch(routeSource, /\.click\(/);
});

test("a newer QA export cannot invalidate selected production bytes", () => {
  assert.match(source, /if \(!productionObserver && canonicalPckStat && canonicalPckStat\.mtimeMs > selectedPckStat\.mtimeMs/);
});

test("partial Bell-Eater route selects only a live named enemy and never calls QA mutation", () => {
  const selectSource = source.slice(source.indexOf("function selectActiveEnemy("), source.indexOf("async function approachMovingEnemy("));
  const context = vm.createContext({});
  vm.runInContext(`${selectSource}\nglobalThis.selectActiveEnemy = selectActiveEnemy;`, context);
  const enemies = [
    { id: "ghoulkin", active: true, health: 20, position: { x: 1, z: 1 } },
    { id: "bell_eater", active: false, health: 320, position: { x: 2, z: 2 } },
    { id: "bell_eater", active: true, health: 240, position: { x: 3, z: 3 } },
  ];
  assert.equal(context.selectActiveEnemy({ enemies }, "bell_eater"), enemies[2]);
  assert.equal(context.selectActiveEnemy({ enemies }, "ashwing"), undefined);
  const routeSource = source.slice(source.indexOf("async function fightBellEater("), source.indexOf("async function inspectRenderer("));
  assert.doesNotMatch(routeSource, /qaCommand\(|routeToCatalogEntry\(/);
  assert.match(routeSource, /await tapGameplayKey\(cdp, "KeyT"/);
  assert.match(routeSource, /const meleeDistance = 1\.2/);
  assert.match(routeSource, /await attackLiveTarget\(cdp, meleeDistance, "bell_eater"\)/);
  assert.match(routeSource, /await useInteraction\(cdp, "mira"/);
  assert.match(routeSource, /await useInteraction\(cdp, "chapel_names"/);
  assert.match(routeSource, /await useInteraction\(cdp, "ritual_stones"/);
  assert.match(routeSource, /await useInteraction\(cdp, "bog_core_choice"/);
  assert.match(source, /if \(throughTeeth\) return runOpeningThroughTeeth/);
});

test("register route uses ordinary gates and focused clues before claiming reconstruction", () => {
  const routeSource = source.slice(source.indexOf("async function runOpeningThroughRegister("), source.indexOf("async function inspectRenderer("));
  assert.doesNotMatch(routeSource, /qaCommand\(|routeToCatalogEntry\(|stage_gate|prepare_route/);
  for (const zone of ["wychwood", "greyfen", "deep_wood", "old_mill", "burned_farmstead"]) {
    assert.match(routeSource, new RegExp(`"${zone}"`));
  }
  assert.match(routeSource, /\["register_anwen", "fragment_anwen"\]/);
  assert.match(routeSource, /\["register_tor", "fragment_tor"\]/);
  assert.match(routeSource, /await useInteraction\(cdp, id, checkpoints\)/);
  assert.match(routeSource, /await useInteraction\(cdp, "register_rook"/);
  assert.match(routeSource, /requireObjective\(cdp, "main_names_they_burned", "fragment_rook"/);
  assert.match(routeSource, /includes\("reconstruct_register"\)/);
  assert.match(source, /if \(throughRegister\) return runOpeningThroughRegister/);
});

test("register route preserves the native travel and clue order", async () => {
  const routeSource = source.slice(source.indexOf("async function runOpeningThroughRegister("), source.indexOf("async function prepareCampaignHealing("));
  const calls = [];
  const namesState = { quests: { active: ["main_names_they_burned"] } };
  const reconstructed = { zone: "burned_farmstead", quests: { objectives_done: { main_names_they_burned: ["fragment_rook", "reconstruct_register"] } } };
  const millState = { zone: "old_mill", quests: { objectives_done: { main_names_they_burned: ["reconstruct_register"] } } };
  const observations = [namesState, millState];
  const context = vm.createContext({
    runOpeningThroughTeeth: async () => { calls.push("opening-through-teeth"); },
    traverse: async (_cdp, zone) => { calls.push(`travel:${zone}`); },
    useInteraction: async (_cdp, id, _checkpoints, _dialogue, choice) => {
      calls.push(`interact:${id}${choice ? `:${choice}` : ""}`);
    },
    requireObjective: async (_cdp, _quest, objective) => {
      calls.push(`objective:${objective}`);
      return objective === "fragment_rook" ? reconstructed : namesState;
    },
    freshTelemetry: async () => observations.shift(),
    prepareCampaignHealing: async () => { calls.push("earned-healing"); },
  });
  vm.runInContext(`${routeSource}\nglobalThis.runOpeningThroughRegister = runOpeningThroughRegister;`, context);
  const checkpoints = [];
  const result = await context.runOpeningThroughRegister({}, "http://local.test", checkpoints, async () => {});
  assert.deepEqual(calls, [
    "opening-through-teeth", "travel:wychwood", "travel:greyfen",
    "interact:register_anwen", "objective:fragment_anwen",
    "interact:register_tor", "objective:fragment_tor",
    "earned-healing",
    "travel:deep_wood", "travel:old_mill", "travel:burned_farmstead",
    "interact:register_rook", "objective:fragment_rook", "travel:old_mill",
  ]);
  assert.equal(result.zone, "old_mill");
  assert.equal(checkpoints.at(-1).event, "register_reconstructed");
});

test("bow input keeps aim held through the physical fire edge", async () => {
  const keySource = source.slice(source.indexOf("async function dispatchKey("), source.indexOf("async function dispatchMovementKey("));
  const arrowSource = source.slice(source.indexOf("async function fireAimedArrow("), source.indexOf("async function fightRootbound("));
  const calls = [];
  const cdp = {
    async send(method, params = {}) { calls.push([method, params]); },
    async evaluate() {},
  };
  const context = vm.createContext({
    viewport: { width: 1280, height: 720 },
    INPUT_TIMEOUT_MS: 10000,
    sleep: async () => {},
    focusGameCanvas: async () => {},
  });
  vm.runInContext(`${keySource}\n${arrowSource}\nglobalThis.subject = { dispatchKey, fireAimedArrow };`, context);
  await context.subject.dispatchKey(cdp, "Digit2", "2", true);
  assert.equal(calls[0][1].windowsVirtualKeyCode, 50);
  calls.length = 0;
  await context.subject.fireAimedArrow(cdp);
  const edges = calls.filter(([method]) => method === "Input.dispatchMouseEvent")
    .map(([, params]) => [params.type, params.button, params.buttons]);
  assert.deepEqual(edges, [
    ["mousePressed", "right", 2],
    ["mousePressed", "left", 3],
    ["mouseReleased", "left", 2],
    ["mouseReleased", "right", 0],
  ]);
});

test("Rootbound and Names scopes require real input and explicit chapter outcomes", () => {
  const routeSource = source.slice(source.indexOf("async function fireAimedArrow("), source.indexOf("async function inspectRenderer("));
  assert.doesNotMatch(routeSource, /qaCommand\(|stage_gate|prepare_route|route_to/);
  assert.match(routeSource, /await traverse\(cdp, "deep_wood", checkpoints\)/);
  assert.match(routeSource, /await tapGameplayKey\(cdp, "Digit2", "2"/);
  assert.match(routeSource, /await fireAimedArrow\(cdp\)/);
  assert.match(routeSource, /await useInteraction\(cdp, "names_decision", checkpoints, true, "Publish every recovered name"\)/);
  assert.match(routeSource, /after\?\.story\?\.flags\?\.names_policy !== "published"/);
  assert.match(source, /if \(throughNames\) return runOpeningThroughNames/);
});

test("vendor navigation reaches button zero and activates through Enter", async () => {
  const routeSource = source.slice(source.indexOf("async function chooseMenuButton("), source.indexOf("async function runOpeningThroughAshPreparation("));
  let focused = 1;
  const keys = [];
  const context = vm.createContext({
    freshTelemetry: async () => ({ ui: { buttons: [
      { text: "Buy Standard Arrow - 1 coin", enabled: true, focused: focused === 0 },
      { text: "Close", enabled: true, focused: focused === 1 },
    ] } }),
    waitFor: async (predicate) => predicate(),
    tapKey: async (_cdp, code) => { keys.push(code); if (code === "ArrowUp") focused = 0; },
  });
  vm.runInContext(`${routeSource}\nglobalThis.chooseMenuButton = chooseMenuButton;`, context);
  await context.chooseMenuButton({}, "Buy Standard Arrow");
  assert.deepEqual(keys, ["ArrowUp", "Enter"]);
});

test("Ash scope keeps mill clue, combat, boss, and ledger in real-input order", async () => {
  const routeSource = source.slice(source.indexOf("async function runOpeningToMiller("), source.indexOf("async function inspectRenderer("));
  const calls = [];
  let readCount = 0;
  const context = vm.createContext({
    runOpeningThroughAshPreparation: async () => { calls.push("ash-prepared"); },
    useInteraction: async (_cdp, id, _checkpoints, _dialogue, choice) => { calls.push(`interact:${id}:${choice || ""}`); },
    requireObjective: async (_cdp, quest, objective) => { calls.push(`objective:${quest}:${objective}`); },
    fightAshMillPack: async () => { calls.push("mill-pack"); },
    fightAshwing: async () => { calls.push("ashwing"); },
    freshTelemetry: async () => {
      readCount += 1;
      return readCount === 1 ? {
        zone: "old_mill", story: { flags: { ashwing_defeated: true } },
        quests: { active: ["main_ash_at_the_mill"] },
      } : {
        zone: "old_mill", story: { flags: { mill_fate: "preserved" } },
        quests: { completed: ["main_ash_at_the_mill"], active: ["main_soldier_without_banner"] },
      };
    },
  });
  vm.runInContext(`${routeSource}\nglobalThis.runOpeningThroughAsh = runOpeningThroughAsh;`, context);
  const checkpoints = [];
  await context.runOpeningThroughAsh({}, "http://local.test", checkpoints, async () => {});
  assert.deepEqual(calls, [
    "ash-prepared", "interact:millstones:",
    "objective:main_ash_at_the_mill:inspect_millstones", "mill-pack", "ashwing",
    "interact:miller_record:Preserve the ledger",
  ]);
  assert.equal(checkpoints.at(-1).event, "ash_mill_completed");
  assert.doesNotMatch(routeSource, /qaCommand\(|route_to|stage_gate|prepare_route/);
  assert.match(source, /if \(throughAsh\) return runOpeningThroughAsh/);
});

test("Soldier scope reaches Bandit Road and earns Senn's testimony without mutation", async () => {
  const routeSource = source.slice(source.indexOf("async function runOpeningToSenn("), source.indexOf("async function inspectRenderer("));
  const calls = [];
  let readCount = 0;
  const context = vm.createContext({
    runOpeningThroughAsh: async () => { calls.push("ash-complete"); },
    traverse: async (_cdp, zone) => { calls.push(`travel:${zone}`); },
    requireObjective: async () => ({
      zone: "bandit_road", story: { flags: { mill_fate: "preserved" } },
      enemies: [{ id: "bandit", dead: false }, { id: "bandit", dead: false }],
    }),
    fightSennGuards: async () => { calls.push("guards-defeated"); },
    useInteraction: async (_cdp, id, _checkpoints, _dialogue, choice) => { calls.push(`interact:${id}:${choice}`); },
    freshTelemetry: async () => {
      readCount += 1;
      return readCount === 1 ? {
        zone: "bandit_road", story: { flags: {} },
        quests: { active: ["main_soldier_without_banner"], objectives_done: { main_soldier_without_banner: ["senn_confrontation"] } },
      } : {
        zone: "bandit_road", story: { flags: { senn_fate: "testimony" } },
        quests: { completed: ["main_soldier_without_banner"], active: ["main_blood_under_stone"] },
      };
    },
  });
  vm.runInContext(`${routeSource}\nglobalThis.runOpeningThroughSoldier = runOpeningThroughSoldier;`, context);
  const checkpoints = [];
  await context.runOpeningThroughSoldier({}, "http://local.test", checkpoints, async () => {});
  assert.deepEqual(calls, [
    "ash-complete", "travel:burned_farmstead", "travel:marsh_crossing", "travel:bandit_road",
    "guards-defeated", "interact:captain_senn:Testify in Greyfen",
  ]);
  assert.equal(checkpoints.at(-1).event, "soldier_completed");
  assert.doesNotMatch(routeSource, /qaCommand\(|route_to|stage_gate|prepare_route/);
  assert.match(source, /if \(throughSoldier\) return runOpeningThroughSoldier/);
});

test("Castle scope requires physical entry and all three evidence interactions", async () => {
  const routeSource = source.slice(source.indexOf("async function runOpeningThroughCastle("), source.indexOf("async function inspectRenderer("));
  const calls = [];
  const context = vm.createContext({
    runOpeningThroughSoldier: async () => { calls.push("soldier-complete"); },
    traverse: async (_cdp, zone) => { calls.push(`travel:${zone}`); },
    useInteraction: async (_cdp, id, _checkpoints, _dialogue, choice) => {
      calls.push(`interact:${id}${choice ? `:${choice}` : ""}`);
    },
    requireObjective: async (_cdp, _quest, objective) => {
      calls.push(`objective:${objective}`);
      return { zone: "record_hall", quests: { active: ["main_blood_under_stone"] } };
    },
  });
  vm.runInContext(`${routeSource}\nglobalThis.runOpeningThroughCastle = runOpeningThroughCastle;`, context);
  const checkpoints = [];
  await context.runOpeningThroughCastle({}, "http://local.test", checkpoints, async () => {});
  assert.deepEqual(calls, [
    "soldier-complete", "travel:vargan_approach", "objective:reach_castle",
    "interact:vargan_mile_marker", "interact:vargan_supply_cart",
    "travel:vargan_court", "objective:enter_courtyard",
    "interact:vargan_gate_guard:I carry testimony from the old road.", "objective:speak_guard",
    "interact:vargan_gate_notice", "objective:castle_evidence_ready",
    "travel:record_hall", "objective:locate_record_hall",
  ]);
  assert.equal(checkpoints.at(-1).event, "record_hall_entered");
  assert.doesNotMatch(routeSource, /qaCommand\(|route_to|stage_gate|prepare_route/);
  assert.match(source, /if \(throughCastle\) return runOpeningThroughCastle/);
});

test("Record Hall scope requires the ledger, haunting, and Edric outcome", async () => {
  const routeSource = source.slice(source.indexOf("async function runOpeningToEdric("), source.indexOf("async function inspectRenderer("));
  const calls = [];
  let readCount = 0;
  const context = vm.createContext({
    runOpeningThroughCastle: async () => { calls.push("castle-entered"); },
    useInteraction: async (_cdp, id, _checkpoints, _dialogue, choice) => { calls.push(`interact:${id}:${choice}`); },
    fightRecordHaunting: async () => { calls.push("haunting-cleared"); },
    waitFor: async (predicate) => predicate(),
    freshTelemetry: async () => {
      readCount += 1;
      if (readCount === 1) return {
        story: { flags: { vargan_ledger_choice_made: true, vargan_ledger_taken_openly: true } },
        quests: { objectives_done: { main_blood_under_stone: ["ledger_choice", "recover_ledger"] } },
        enemies: [{ id: "wychwood_stalker", dead: false }],
      };
      if (readCount === 2) return { zone: "record_hall", player: { can_control: true }, transition_pending: false };
      if (readCount === 3) return {
        zone: "record_hall", story: { flags: { castle_haunting_cleared: true } },
        quests: { active: ["main_blood_under_stone"] },
      };
      return {
        zone: "record_hall", story: { flags: { edric_stance: "cooperate" } },
        quests: { completed: ["main_blood_under_stone"], active: ["main_last_witness"] },
      };
    },
  });
  vm.runInContext(`${routeSource}\nglobalThis.runOpeningThroughRecordHall = runOpeningThroughRecordHall;`, context);
  const checkpoints = [];
  await context.runOpeningThroughRecordHall({}, "http://local.test", checkpoints, async () => {});
  assert.deepEqual(calls, [
    "castle-entered", "interact:vargan_ledger_choice:Take the fragment openly",
    "haunting-cleared", "interact:edric_campaign:Testify under protection",
  ]);
  assert.equal(checkpoints.at(-1).event, "blood_under_stone_completed");
  assert.doesNotMatch(routeSource, /qaCommand\(|route_to|stage_gate|prepare_route/);
  assert.match(source, /if \(throughRecordHall\) return runOpeningThroughRecordHall/);
});

test("Last Witness scope requires a real parry before the peaceful dialogue choice", async () => {
  const routeSource = source.slice(source.indexOf("async function runOpeningThroughLastWitness("), source.indexOf("async function runOpeningThroughAssembly("));
  const calls = [];
  const context = vm.createContext({
    runOpeningThroughRecordHall: async () => { calls.push("record-complete"); },
    traverse: async (_cdp, zone) => { calls.push(`travel:${zone}`); },
    requireObjective: async () => ({
      zone: "undercroft", enemies: [{ id: "halvern_boss", dead: false }],
    }),
    parryHalvernGuard: async () => { calls.push("parry"); },
    useInteraction: async (_cdp, id, _checkpoints, _dialogue, choice) => { calls.push(`interact:${id}:${choice}`); },
    freshTelemetry: async () => ({
      story: { flags: {
        halvern_fate: "witness", boss_reward_sealed_testimony: true, halvern_testimony_available: true,
      } },
      quests: { completed: ["main_last_witness"], active: ["main_crowns_without_mercy"] },
    }),
  });
  vm.runInContext(`${routeSource}\nglobalThis.runOpeningThroughLastWitness = runOpeningThroughLastWitness;`, context);
  const checkpoints = [];
  await context.runOpeningThroughLastWitness({}, "http://local.test", checkpoints, async () => {});
  assert.deepEqual(calls, [
    "record-complete", "travel:undercroft", "parry", "interact:halvern:Stand as the last witness",
  ]);
  assert.equal(checkpoints.at(-1).event, "last_witness_completed");
  assert.match(source, /await tapGameplayKey\(cdp, "KeyQ", "q", 75\)/);
  assert.doesNotMatch(routeSource, /qaCommand\(|route_to|stage_gate|prepare_route/);
});

test("Assembly scope hears four witnesses and records the public choice", async () => {
  const routeSource = source.slice(source.indexOf("async function runOpeningThroughAssembly("), source.indexOf("async function inspectRenderer("));
  const calls = [];
  const context = vm.createContext({
    runOpeningThroughLastWitness: async () => { calls.push("last-witness-complete"); },
    traverse: async (_cdp, zone) => { calls.push(`travel:${zone}`); },
    requireObjective: async (_cdp, _quest, objective) => { calls.push(`objective:${objective}`); },
    useInteraction: async (_cdp, id, _checkpoints, _dialogue, choice) => {
      calls.push(`interact:${id}${choice ? `:${choice}` : ""}`);
    },
    freshTelemetry: async () => ({
      zone: "assembly", story: { flags: { confession_method: "witnesses" } },
      quests: { completed: ["main_crowns_without_mercy"], active: ["main_hart_remembers"] },
    }),
  });
  vm.runInContext(`${routeSource}\nglobalThis.runOpeningThroughAssembly = runOpeningThroughAssembly;`, context);
  const checkpoints = [];
  await context.runOpeningThroughAssembly({}, "http://local.test", checkpoints, async () => {});
  assert.deepEqual(calls, [
    "last-witness-complete", "travel:assembly", "objective:greyfen_assembly",
    "interact:witness_3", "interact:witness_-3", "interact:witness_-7", "interact:witness_7",
    "interact:witnesses_ready", "objective:gather_witnesses",
    "interact:assembly_choice:Let every witness speak",
  ]);
  assert.equal(checkpoints.at(-1).event, "assembly_completed");
  assert.doesNotMatch(routeSource, /qaCommand\(|route_to|stage_gate|prepare_route/);
});

test("Finale scope reaches Hart Glade and proves the terminal Witness epilogue", async () => {
  const routeSource = source.slice(source.indexOf("async function runOpeningThroughFinale("), source.indexOf("async function inspectRenderer("));
  const calls = [];
  const context = vm.createContext({
    runOpeningThroughAssembly: async () => { calls.push("assembly-complete"); },
    traverse: async (_cdp, zone) => { calls.push(`travel:${zone}`); },
    requireObjective: async (_cdp, _quest, objective) => { calls.push(`objective:${objective}`); },
    useInteraction: async (_cdp, id, _checkpoints, _dialogue, choice, restorePointer) => {
      calls.push(`interact:${id}:${choice}:${restorePointer}`);
    },
    waitFor: async (predicate) => predicate(),
    freshTelemetry: async () => ({
      zone: "hart_glade",
      story: { flags: { final_choice_completed: true, final_covenant: "witness", epilogue_cards: ["The road remembers."] } },
      quests: { world_flags: { ending: "expose" }, completed: ["main_hart_remembers"] },
      ui: { buttons: [{ text: "Return to Main Menu" }] },
    }),
  });
  vm.runInContext(`${routeSource}\nglobalThis.runOpeningThroughFinale = runOpeningThroughFinale;`, context);
  const checkpoints = [];
  await context.runOpeningThroughFinale({}, "http://local.test", checkpoints, async () => {});
  assert.deepEqual(calls, [
    "assembly-complete", "travel:hart_glade", "objective:enter_glade",
    "interact:white_hart:Witness: name every dead:false",
  ]);
  assert.equal(checkpoints.at(-1).event, "witness_ending_completed");
  assert.doesNotMatch(routeSource, /qaCommand\(|route_to|stage_gate|prepare_route/);
});

test("opening persistence scope saves through pause and resumes through Continue", async () => {
  const routeSource = source.slice(source.indexOf("async function runOpeningSaveContinue("), source.indexOf("async function exerciseBrowserSettings("));
  const calls = [];
  const settings = { master_volume: 1, subtitle_scale: 1.2, reduced_motion: true,
    custom_bindings: { interact: [{ key: "F9" }] } };
  const context = vm.createContext({
    runOpeningCampaign: async () => {
      calls.push("opening-complete");
      return { quests: { completed: ["main_road_of_crows"] } };
    },
    saveThroughPauseMenu: async () => { calls.push("pause-save"); },
    continueSavedOpening: async () => {
      calls.push("continue");
      return { zone: "greyfen", settings, audio: { muted: false, music_playing: true, master_db: 0 } };
    },
    exerciseBrowserSettings: async (_cdp, _checkpoints, restore) => {
      calls.push(restore ? "defaults-restored" : "settings-changed");
      return { settings, interactBinding: JSON.stringify(settings.custom_bindings.interact), original: {} };
    },
    useInteraction: async (_cdp, id, _checkpoints, _dialogue, _choice, _force, binding) => {
      calls.push(`remapped:${id}:${binding[0]}`);
    },
    freshTelemetry: async () => ({ zone: "greyfen" }),
  });
  vm.runInContext(`${routeSource}\nglobalThis.runOpeningSaveContinue = runOpeningSaveContinue;`, context);
  const result = await context.runOpeningSaveContinue({}, "http://local.test", [], async () => {});
  assert.deepEqual(calls, ["opening-complete", "settings-changed", "pause-save", "continue",
    "remapped:sister_anwen:F9", "defaults-restored"]);
  assert.equal(result.zone, "greyfen");
  assert.match(source, /if \(openingSaveContinue\) return runOpeningSaveContinue/);
  assert.doesNotMatch(routeSource, /qaCommand\(|route_to|stage_gate|prepare_route/);
});

test("ending matrix earns one Hart save and reloads it before each alternate choice", async () => {
  const routeSource = source.slice(source.indexOf("async function runOpeningEndingMatrix("), source.indexOf("async function inspectRenderer("));
  const calls = [];
  const context = vm.createContext({
    runOpeningThroughAssembly: async () => { calls.push("assembly-complete"); },
    traverse: async (_cdp, zone) => { calls.push(`travel:${zone}`); },
    requireObjective: async (_cdp, _quest, objective) => { calls.push(`objective:${objective}`); },
    saveThroughPauseMenu: async () => { calls.push("earned-save"); },
    continueSavedHart: async () => { calls.push("real-continue"); },
    resolveHartChoice: async (_cdp, choice) => {
      calls.push(`choice:${choice.covenant}:${choice.combat}`);
      return { covenant: choice.covenant };
    },
  });
  vm.runInContext(`${routeSource}\nglobalThis.runOpeningEndingMatrix = runOpeningEndingMatrix;`, context);
  const result = await context.runOpeningEndingMatrix({}, "http://local.test", [], async () => {});
  assert.deepEqual(calls, [
    "assembly-complete", "travel:hart_glade", "objective:enter_glade", "earned-save",
    "choice:witness:false", "real-continue", "choice:mercy:false", "real-continue",
    "choice:duty:true", "real-continue", "choice:ash:true",
  ]);
  assert.equal(result.covenant, "ash");
  assert.match(source, /if \(endingMatrix\) return runOpeningEndingMatrix/);
  assert.doesNotMatch(routeSource, /qaCommand\(|route_to|stage_gate|prepare_route/);
});

test("Hart Continue rejects an already resolved final covenant", async () => {
  const routeSource = source.slice(source.indexOf("async function continueSavedHart("), source.indexOf("async function fightHartEnding("));
  const cdp = {
    send: async () => {},
    evaluate: async () => true,
  };
  const context = vm.createContext({
    waitFor: async (predicate) => predicate(),
    activateBootShell: async () => {},
    freshTelemetry: async () => ({
      new_game_ready: true, zone: "hart_glade", player: { can_control: true },
      ui: { active_menu: "main", buttons: [{ text: "Continue", enabled: true }] },
      quests: { active: ["main_hart_remembers"] },
      story: { flags: { final_covenant: "mercy" } },
    }),
    chooseMenuButton: async () => {},
  });
  vm.runInContext(`${routeSource}\nglobalThis.continueSavedHart = continueSavedHart;`, context);
  await assert.rejects(context.continueSavedHart(cdp, "http://local.test/?observe=1", []),
    /unresolved Hart checkpoint/);
});

test("Shrine matrix earns one save and reloads before each alternative", async () => {
  const routeSource = source.slice(source.indexOf("async function runOpeningShrineMatrix("), source.indexOf("async function fightBellEater("));
  const calls = [];
  let outcome = "";
  const context = vm.createContext({
    runOpeningToShrine: async () => { calls.push("opening-to-shrine"); },
    saveThroughPauseMenu: async () => { calls.push("earned-save"); },
    continueSavedShrine: async () => { calls.push("real-continue"); outcome = ""; },
    useInteraction: async (_cdp, id, _checkpoints, _dialogue, label) => {
      calls.push(`interact:${id}:${label}`);
      outcome = ({ "Cleanse the shrine": "cleansed", "Disturb it for memory": "disturbed", "Bind it and leave": "bound" })[label];
    },
    freshTelemetry: async () => ({
      story: { flags: { crow_shrine_state: outcome } },
      quests: { completed: ["main_bell_beneath_greyfen"] },
    }),
  });
  vm.runInContext(`${routeSource}\nglobalThis.runOpeningShrineMatrix = runOpeningShrineMatrix;`, context);
  const checkpoints = [];
  await context.runOpeningShrineMatrix({}, "http://local.test", checkpoints, async () => {});
  assert.deepEqual(calls, [
    "opening-to-shrine", "earned-save", "interact:crow_shrine_choice:Cleanse the shrine",
    "real-continue", "interact:crow_shrine_choice:Disturb it for memory",
    "real-continue", "interact:crow_shrine_choice:Bind it and leave",
  ]);
  assert.deepEqual(checkpoints.filter((item) => item.event === "shrine_choice_completed").map((item) => item.outcome),
    ["cleansed", "disturbed", "bound"]);
  assert.match(source, /if \(shrineMatrix\) return runOpeningShrineMatrix/);
  assert.doesNotMatch(routeSource, /qaCommand\(|route_to|stage_gate|prepare_route/);
});

test("Shrine Continue rejects a resolved manual-save checkpoint", async () => {
  const routeSource = source.slice(source.indexOf("async function continueSavedShrine("), source.indexOf("async function runOpeningShrineMatrix("));
  const context = vm.createContext({
    waitFor: async (predicate) => predicate(),
    activateBootShell: async () => {},
    freshTelemetry: async () => ({
      new_game_ready: true, zone: "greyfen", player: { can_control: true },
      ui: { active_menu: "main", buttons: [{ text: "Continue", enabled: true }] },
      quests: { active: ["main_bell_beneath_greyfen"], objectives_done: { main_bell_beneath_greyfen: ["open_chapel", "crow_shrine_choice"] } },
      story: { flags: { crow_shrine_state: "cleansed" } },
    }),
    chooseMenuButton: async () => {},
  });
  vm.runInContext(`${routeSource}\nglobalThis.continueSavedShrine = continueSavedShrine;`, context);
  await assert.rejects(context.continueSavedShrine({ send: async () => {}, evaluate: async () => true },
    "http://local.test/?observe=1", []), /unresolved Crow Shrine checkpoint/);
});

test("Ledger matrix earns one unresolved Record Hall save and reloads every alternative", async () => {
  const routeSource = source.slice(source.indexOf("async function runOpeningLedgerMatrix("), source.indexOf("async function fightRecordHaunting("));
  const calls = [];
  let outcome = "";
  const context = vm.createContext({
    runOpeningThroughCastle: async () => {
      calls.push("record-hall-arrival");
      return { story: { flags: {} } };
    },
    saveThroughPauseMenu: async () => { calls.push("earned-save"); },
    continueSavedLedger: async () => { calls.push("real-continue"); outcome = ""; },
    useInteraction: async (_cdp, id, _checkpoints, _dialogue, label) => {
      calls.push(`interact:${id}:${label}`);
      outcome = ({
        "Take the fragment openly": "vargan_ledger_taken_openly",
        "Hide the fragment": "vargan_ledger_hidden",
        "Leave it and copy the seal": "vargan_ledger_left_copied",
      })[label];
    },
    waitFor: async (predicate) => predicate(),
    freshTelemetry: async () => ({
      story: { flags: { vargan_ledger_choice_made: true, [outcome]: true } },
      quests: { objectives_done: { main_blood_under_stone: ["recover_ledger", "ledger_choice"] } },
    }),
  });
  vm.runInContext(`${routeSource}\nglobalThis.runOpeningLedgerMatrix = runOpeningLedgerMatrix;`, context);
  const checkpoints = [];
  await context.runOpeningLedgerMatrix({}, "http://local.test", checkpoints, async () => {});
  assert.deepEqual(calls, [
    "record-hall-arrival", "earned-save", "interact:vargan_ledger_choice:Take the fragment openly",
    "real-continue", "interact:vargan_ledger_choice:Hide the fragment",
    "real-continue", "interact:vargan_ledger_choice:Leave it and copy the seal",
  ]);
  assert.deepEqual(checkpoints.filter((item) => item.event === "ledger_choice_completed").map((item) => item.outcome),
    ["vargan_ledger_taken_openly", "vargan_ledger_hidden", "vargan_ledger_left_copied"]);
  assert.match(source, /if \(ledgerMatrix\) return runOpeningLedgerMatrix/);
  assert.doesNotMatch(routeSource, /qaCommand\(|route_to|stage_gate|prepare_route/);
});

test("Ledger Continue rejects an already resolved checkpoint", async () => {
  const routeSource = source.slice(source.indexOf("async function continueSavedLedger("), source.indexOf("async function runOpeningLedgerMatrix("));
  const context = vm.createContext({
    waitFor: async (predicate) => predicate(),
    activateBootShell: async () => {},
    freshTelemetry: async () => ({
      new_game_ready: true, zone: "record_hall", player: { can_control: true },
      ui: { active_menu: "main", buttons: [{ text: "Continue", enabled: true }] },
      quests: { active: ["main_blood_under_stone"], objectives_done: { main_blood_under_stone: ["locate_record_hall", "ledger_choice"] } },
      story: { flags: { vargan_ledger_choice_made: true } },
    }),
    chooseMenuButton: async () => {},
  });
  vm.runInContext(`${routeSource}\nglobalThis.continueSavedLedger = continueSavedLedger;`, context);
  await assert.rejects(context.continueSavedLedger({ send: async () => {}, evaluate: async () => true },
    "http://local.test/?observe=1", []), /unresolved Record Hall ledger checkpoint/);
});

test("Edric matrix earns a post-haunting save and reloads every testimony choice", async () => {
  const routeSource = source.slice(source.indexOf("async function runOpeningEdricMatrix("), source.indexOf("async function parryHalvernGuard("));
  const calls = [];
  let stance = "";
  const context = vm.createContext({
    runOpeningToEdric: async () => { calls.push("haunting-cleared"); },
    saveThroughPauseMenu: async () => { calls.push("earned-save"); },
    continueSavedEdric: async () => { calls.push("real-continue"); stance = ""; },
    useInteraction: async (_cdp, id, _checkpoints, _dialogue, label) => {
      calls.push(`interact:${id}:${label}`);
      stance = ({
        "Testify under protection": "cooperate",
        "Expose him now": "exposed",
        "Compel a confession": "compelled",
      })[label];
    },
    freshTelemetry: async () => ({
      story: { flags: { edric_stance: stance } },
      quests: { completed: ["main_blood_under_stone"], active: ["main_last_witness"] },
    }),
  });
  vm.runInContext(`${routeSource}\nglobalThis.runOpeningEdricMatrix = runOpeningEdricMatrix;`, context);
  const checkpoints = [];
  await context.runOpeningEdricMatrix({}, "http://local.test", checkpoints, async () => {});
  assert.deepEqual(calls, [
    "haunting-cleared", "earned-save", "interact:edric_campaign:Testify under protection",
    "real-continue", "interact:edric_campaign:Expose him now",
    "real-continue", "interact:edric_campaign:Compel a confession",
  ]);
  assert.deepEqual(checkpoints.filter((item) => item.event === "edric_choice_completed").map((item) => item.outcome),
    ["cooperate", "exposed", "compelled"]);
  assert.match(source, /if \(edricMatrix\) return runOpeningEdricMatrix/);
  assert.doesNotMatch(routeSource, /qaCommand\(|route_to|stage_gate|prepare_route/);
});

test("Edric Continue rejects an already resolved testimony checkpoint", async () => {
  const routeSource = source.slice(source.indexOf("async function continueSavedEdric("), source.indexOf("async function runOpeningEdricMatrix("));
  const context = vm.createContext({
    waitFor: async (predicate) => predicate(),
    activateBootShell: async () => {},
    freshTelemetry: async () => ({
      new_game_ready: true, zone: "record_hall", player: { can_control: true },
      ui: { active_menu: "main", buttons: [{ text: "Continue", enabled: true }] },
      quests: { active: ["main_blood_under_stone"], objectives_done: { main_blood_under_stone: ["last_witness_hook"] } },
      story: { flags: { castle_haunting_cleared: true, edric_stance: "cooperate" } },
    }),
    chooseMenuButton: async () => {},
  });
  vm.runInContext(`${routeSource}\nglobalThis.continueSavedEdric = continueSavedEdric;`, context);
  await assert.rejects(context.continueSavedEdric({ send: async () => {}, evaluate: async () => true },
    "http://local.test/?observe=1", []), /unresolved Edric checkpoint/);
});

test("Miller matrix earns a post-Ashwing save and reloads every record choice", async () => {
  const routeSource = source.slice(source.indexOf("async function runOpeningMillMatrix("), source.indexOf("async function fightSennGuards("));
  const calls = [];
  let fate = "";
  const context = vm.createContext({
    runOpeningToMiller: async () => { calls.push("ashwing-defeated"); },
    saveThroughPauseMenu: async () => { calls.push("earned-save"); },
    continueSavedMiller: async () => { calls.push("real-continue"); fate = ""; },
    useInteraction: async (_cdp, id, _checkpoints, _dialogue, label) => {
      calls.push(`interact:${id}:${label}`);
      fate = ({
        "Preserve the ledger": "preserved", "Burn the ledger": "burned",
        "Post copies in Greyfen": "exposed",
      })[label];
    },
    freshTelemetry: async () => ({
      story: { flags: { mill_fate: fate } },
      quests: { completed: ["main_ash_at_the_mill"], active: ["main_soldier_without_banner"] },
    }),
  });
  vm.runInContext(`${routeSource}\nglobalThis.runOpeningMillMatrix = runOpeningMillMatrix;`, context);
  const checkpoints = [];
  await context.runOpeningMillMatrix({}, "http://local.test", checkpoints, async () => {});
  assert.deepEqual(calls, [
    "ashwing-defeated", "earned-save", "interact:miller_record:Preserve the ledger",
    "real-continue", "interact:miller_record:Burn the ledger",
    "real-continue", "interact:miller_record:Post copies in Greyfen",
  ]);
  assert.deepEqual(checkpoints.filter((item) => item.event === "miller_choice_completed").map((item) => item.outcome),
    ["preserved", "burned", "exposed"]);
  assert.match(source, /if \(millMatrix\) return runOpeningMillMatrix/);
  assert.doesNotMatch(routeSource, /qaCommand\(|route_to|stage_gate|prepare_route/);
});

test("Miller Continue rejects an already resolved mill record checkpoint", async () => {
  const routeSource = source.slice(source.indexOf("async function continueSavedMiller("), source.indexOf("async function runOpeningMillMatrix("));
  const context = vm.createContext({
    waitFor: async (predicate) => predicate(),
    activateBootShell: async () => {},
    freshTelemetry: async () => ({
      new_game_ready: true, zone: "old_mill", player: { can_control: true },
      ui: { active_menu: "main", buttons: [{ text: "Continue", enabled: true }] },
      quests: { active: ["main_ash_at_the_mill"], objectives_done: { main_ash_at_the_mill: ["mill_choice"] } },
      story: { flags: { ashwing_defeated: true, mill_fate: "burned" } },
    }),
    chooseMenuButton: async () => {},
  });
  vm.runInContext(`${routeSource}\nglobalThis.continueSavedMiller = continueSavedMiller;`, context);
  await assert.rejects(context.continueSavedMiller({ send: async () => {}, evaluate: async () => true },
    "http://local.test/?observe=1", []), /unresolved Miller checkpoint/);
});

test("Senn matrix earns a post-guard save and reloads every testimony outcome", async () => {
  const routeSource = source.slice(source.indexOf("async function runOpeningSennMatrix("), source.indexOf("async function runOpeningThroughCastle("));
  const calls = [];
  let fate = "";
  const context = vm.createContext({
    runOpeningToSenn: async () => { calls.push("guards-defeated"); },
    saveThroughPauseMenu: async () => { calls.push("earned-save"); },
    continueSavedSenn: async () => { calls.push("real-continue"); fate = ""; },
    useInteraction: async (_cdp, id, _checkpoints, _dialogue, label) => {
      calls.push(`interact:${id}:${label}`);
      fate = ({
        "Testify in Greyfen": "testimony", "Leave and never return": "exile",
        "Answer for the dead": "punished",
      })[label];
    },
    freshTelemetry: async () => ({
      story: { flags: { senn_fate: fate } },
      quests: { completed: ["main_soldier_without_banner"], active: ["main_blood_under_stone"] },
    }),
  });
  vm.runInContext(`${routeSource}\nglobalThis.runOpeningSennMatrix = runOpeningSennMatrix;`, context);
  const checkpoints = [];
  await context.runOpeningSennMatrix({}, "http://local.test", checkpoints, async () => {});
  assert.deepEqual(calls, [
    "guards-defeated", "earned-save", "interact:captain_senn:Testify in Greyfen",
    "real-continue", "interact:captain_senn:Leave and never return",
    "real-continue", "interact:captain_senn:Answer for the dead",
  ]);
  assert.deepEqual(checkpoints.filter((item) => item.event === "senn_choice_completed").map((item) => item.outcome),
    ["testimony", "exile", "punished"]);
  assert.match(source, /if \(sennMatrix\) return runOpeningSennMatrix/);
  assert.doesNotMatch(routeSource, /qaCommand\(|route_to|stage_gate|prepare_route/);
});

test("Senn Continue rejects an already resolved checkpoint", async () => {
  const routeSource = source.slice(source.indexOf("async function continueSavedSenn("), source.indexOf("async function runOpeningSennMatrix("));
  const context = vm.createContext({
    waitFor: async (predicate) => predicate(),
    activateBootShell: async () => {},
    freshTelemetry: async () => ({
      new_game_ready: true, zone: "bandit_road", player: { can_control: true },
      ui: { active_menu: "main", buttons: [{ text: "Continue", enabled: true }] },
      quests: { active: ["main_soldier_without_banner"], objectives_done: { main_soldier_without_banner: ["senn_confrontation", "senn_choice"] } },
      story: { flags: { senn_fate: "testimony" } },
    }),
    chooseMenuButton: async () => {},
  });
  vm.runInContext(`${routeSource}\nglobalThis.continueSavedSenn = continueSavedSenn;`, context);
  await assert.rejects(context.continueSavedSenn({ send: async () => {}, evaluate: async () => true },
    "http://local.test/?observe=1", []), /unresolved Senn checkpoint/);
});

test("campaign route owns a bounded deadline separate from individual waits", () => {
  const definition = source.slice(source.indexOf("const routeTimeoutMs ="), source.indexOf("if (!Number.isFinite(routeTimeoutMs)"));
  const deadline = (fullCampaign, partialCampaign) => vm.runInNewContext(`${definition}\nrouteTimeoutMs`, {
    args: {}, fullCampaign, partialCampaign, timeoutMs: 120000,
  });
  assert.equal(deadline(false, false), 120000);
  assert.equal(deadline(false, true), 20 * 60 * 1000);
  assert.equal(deadline(true, false), 45 * 60 * 1000);
  assert.match(source, /\}, `\$\{name\} player route`, routeTimeoutMs, routeScope\.revoke\)/);
});
