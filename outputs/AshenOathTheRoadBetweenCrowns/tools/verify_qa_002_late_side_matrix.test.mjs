import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import vm from "node:vm";

const source = readFileSync(new URL("./verify_qa_002_browser.mjs", import.meta.url), "utf8");
const earlyStart = source.indexOf("async function runRooksMapMatrix(");
const earlyEnd = source.indexOf("\nconst GREYFEN_SIDE_MATRIX", earlyStart);
const bannerStart = source.indexOf("async function runBannerlessMatrix(");
const bannerEnd = source.indexOf("\nasync function runOpeningThroughCastle(", bannerStart);
const recordStart = source.indexOf("async function recordAssemblySideOutcome(");
const recordEnd = source.indexOf("\nasync function runOpeningThroughAssembly(", recordStart);
assert.ok(earlyStart >= 0 && earlyEnd > earlyStart && bannerStart > earlyEnd && bannerEnd > bannerStart
  && recordStart > bannerEnd && recordEnd > recordStart);

function earlyFixture(kind, wrongOutcome = false) {
  const events = [];
  const checkpoints = [];
  const quest = kind === "rook" ? "side_rooks_map" : "side_millers_measure";
  const clue = kind === "rook" ? "walk_false_road" : "weigh_ash";
  const flag = kind === "rook" ? "rook_map_fate" : "ash_measure_fate";
  const stage = kind === "rook" ? "rooks_map_compared" : "millers_measure_recovered";
  let zone = "greyfen";
  let active = false;
  let clueDone = false;
  let outcome = "";
  const context = vm.createContext({
    runOpeningCampaign: async () => events.push("earned_opening"),
    traverse: async (_cdp, target) => { zone = target; events.push(`travel:${target}`); },
    useInteraction: async (_cdp, id, _checkpoints, dialogue, label) => {
      events.push(`interact:${id}:${label || ""}`);
      if (id === "side_contracts") {
        assert.equal(zone, "greyfen");
        assert.equal(dialogue, true);
        active = true;
      } else if (["rooks_false_road", "hidden_ash_measure"].includes(id)) {
        assert.equal(zone, kind === "rook" ? "deep_wood" : "old_mill");
        clueDone = true;
      } else {
        assert.equal(zone, "greyfen");
        assert.equal(clueDone, true);
        outcome = wrongOutcome ? "wrong" : kind === "rook"
          ? label.startsWith("Keep") ? "preserved" : "destroyed"
          : id === "farmer_toma" ? "farmer" : "healer";
      }
    },
    saveThroughPauseMenu: async () => { assert.equal(zone, "greyfen"); events.push("manual_save"); },
    continueSavedOpening: async (_cdp, _url, _checkpoints, value) => {
      assert.equal(value, stage);
      outcome = "";
      events.push("continue_unresolved");
    },
    recordAssemblySideOutcome: async (_cdp, _url, _checkpoints, _startup, spec) => {
      assert.equal(spec.resumeAt, "greyfen_measure");
      assert.equal(spec.quest, quest);
      assert.equal(spec.clue, clue);
      assert.equal(spec.flag, flag);
      assert.match(spec.label, /assembly/);
      outcome = "assembly";
      events.push("record_assembly");
      return { story: { flags: { [flag]: outcome } } };
    },
    freshTelemetry: async () => ({
      zone,
      quests: {
        active: active && !outcome ? [quest] : [],
        completed: outcome ? [quest] : [],
        objectives_done: { [quest]: clueDone ? [clue] : [] },
      },
      story: { flags: { [flag]: outcome, ash_measure_recovered: kind === "miller" && clueDone } },
    }),
  });
  vm.runInContext(source.slice(earlyStart, earlyEnd), context);
  return {
    run: () => kind === "rook"
      ? context.runRooksMapMatrix({}, "fixture", checkpoints, async () => {})
      : context.runMillersMeasureMatrix({}, "fixture", checkpoints, async () => {}),
    events, checkpoints,
  };
}

test("Rook's map requires the Deep Wood waystone and two saved Greyfen decisions", async () => {
  const fixture = earlyFixture("rook");
  const finalState = await fixture.run();
  assert.equal(finalState.story.flags.rook_map_fate, "destroyed");
  assert.deepEqual(fixture.events, [
    "earned_opening", "interact:side_contracts:The Road That Bends",
    "travel:wychwood", "travel:deep_wood", "interact:rooks_false_road:",
    "travel:wychwood", "travel:greyfen", "manual_save",
    "interact:rook:Keep the older road on the map", "continue_unresolved",
    "interact:rook:Destroy the map before Vargan can use it",
  ]);
  assert.deepEqual(fixture.checkpoints.map((entry) => entry.outcome), ["preserved", "destroyed"]);
});

test("the miller's measure requires the Old Mill clue before farmer and healer outcomes", async () => {
  const fixture = earlyFixture("miller");
  const finalState = await fixture.run();
  assert.equal(finalState.story.flags.ash_measure_fate, "assembly");
  assert.deepEqual(fixture.events, [
    "earned_opening", "interact:side_contracts:A Measure of Ash",
    "travel:wychwood", "travel:deep_wood", "travel:old_mill",
    "interact:hidden_ash_measure:", "travel:deep_wood", "travel:wychwood",
    "travel:greyfen", "manual_save",
    "interact:farmer_toma:Show the farmer what the mill weighed",
    "continue_unresolved", "interact:mira:Use the miller's measure to treat the sick",
    "continue_unresolved", "record_assembly",
  ]);
  assert.deepEqual(fixture.checkpoints.map((entry) => entry.outcome), ["farmer", "healer"]);
});

for (const kind of ["rook", "miller"]) {
  test(`${kind} rejects an incorrect decision before recording branch success`, async () => {
    const fixture = earlyFixture(kind, true);
    await assert.rejects(fixture.run(), /choice did not persist/);
    assert.equal(fixture.checkpoints.length, 0);
  });
}

function bannerFixture(wrongOutcome = false) {
  const events = [];
  const checkpoints = [];
  let active = false;
  let musterRead = false;
  let outcome = "";
  const context = vm.createContext({
    runOpeningThroughSoldier: async () => events.push("earned_senn_testimony"),
    useInteraction: async (_cdp, id, _checkpoints, dialogue, label) => {
      events.push(`interact:${id}:${label || ""}`);
      if (id === "deserters_muster") musterRead = true;
      else if (label?.startsWith("Find the soldiers")) {
        assert.equal(dialogue, true);
        active = true;
      } else {
        assert.equal(musterRead, true);
        outcome = wrongOutcome ? "wrong" : label.startsWith("Carry") ? "testimony" : "shielded";
      }
    },
    saveThroughPauseMenu: async () => events.push("manual_save"),
    continueSavedSenn: async (_cdp, _url, _checkpoints, stage) => {
      assert.equal(stage, "bannerless_muster");
      outcome = "";
      events.push("continue_muster");
    },
    recordAssemblySideOutcome: async (_cdp, _url, _checkpoints, _startup, spec) => {
      assert.equal(spec.resumeAt, "bandit_muster");
      assert.equal(spec.quest, "side_soldiers_debt");
      assert.equal(spec.clue, "find_deserters");
      assert.equal(spec.flag, "bannerless_fate");
      assert.match(spec.label, /refusal/);
      outcome = "assembly";
      events.push("record_assembly");
      return { story: { flags: { bannerless_fate: outcome } } };
    },
    freshTelemetry: async () => ({
      zone: "bandit_road",
      quests: {
        active: active && !outcome ? ["side_soldiers_debt"] : [],
        completed: outcome ? ["side_soldiers_debt"] : [],
        objectives_done: { side_soldiers_debt: musterRead ? ["find_deserters"] : [] },
      },
      story: { flags: { deserters_muster_read: musterRead, bannerless_fate: outcome } },
    }),
  });
  vm.runInContext(source.slice(bannerStart, bannerEnd), context);
  return { run: () => context.runBannerlessMatrix({}, "fixture", checkpoints, async () => {}), events, checkpoints };
}

test("Bannerless requires Senn's earned testimony and focused muster before save replay", async () => {
  const fixture = bannerFixture();
  const finalState = await fixture.run();
  assert.equal(finalState.story.flags.bannerless_fate, "assembly");
  assert.deepEqual(fixture.events, [
    "earned_senn_testimony", "interact:captain_senn:Find the soldiers who left your banner",
    "interact:deserters_muster:", "manual_save",
    "interact:captain_senn:Carry the deserters' signed refusal to Greyfen",
    "continue_muster", "interact:captain_senn:Shield the deserters' names from Vargan",
    "continue_muster", "record_assembly",
  ]);
  assert.deepEqual(fixture.checkpoints.map((entry) => entry.outcome), ["testimony", "shielded"]);
});

test("Bannerless rejects a wrong Senn outcome", async () => {
  const fixture = bannerFixture(true);
  await assert.rejects(fixture.run(), /choice did not persist/);
  assert.equal(fixture.checkpoints.length, 0);
});

function assemblyFixture(missingEvidence = false, wrongOutcome = false) {
  const events = [];
  const checkpoints = [];
  const spec = {
    resumeAt: "bandit_muster", quest: "side_soldiers_debt", clue: "find_deserters",
    flag: "bannerless_fate", label: "Read the deserters' refusal into the record",
  };
  let zone = "undercroft";
  let outcome = "";
  const context = vm.createContext({
    runOpeningThroughLastWitness: async (_cdp, _url, _checkpoints, _ready, resumeAt) => {
      assert.equal(resumeAt, spec.resumeAt);
      events.push("earned_last_witness");
    },
    freshTelemetry: async () => ({
      zone,
      quests: {
        active: ["main_crowns_without_mercy", spec.quest],
        completed: outcome ? [spec.quest] : [],
        objectives_done: { [spec.quest]: missingEvidence ? [] : [spec.clue] },
      },
      story: { flags: { [spec.flag]: outcome } },
    }),
    traverse: async (_cdp, target) => { zone = target; events.push(`travel:${target}`); },
    requireObjective: async (_cdp, quest, objective) => {
      assert.equal(quest, "main_crowns_without_mercy");
      events.push(`objective:${objective}`);
    },
    useInteraction: async (_cdp, id, _checkpoints, _dialogue, label) => {
      events.push(`interact:${id}`);
      if (id === "assembly_choice") {
        assert.equal(label, spec.label);
        outcome = wrongOutcome ? "wrong" : "assembly";
      }
    },
    saveThroughPauseMenu: async (_cdp, _checkpoints, allowExisting) => {
      assert.equal(allowExisting, true);
      assert.equal(outcome, "assembly");
      events.push("manual_save_overwritten");
    },
    continueSavedAssemblySideOutcome: async (_cdp, _url, _checkpoints, quest, flag) => {
      assert.equal(quest, spec.quest);
      assert.equal(flag, spec.flag);
      events.push("continue_assembly");
      return { story: { flags: { [flag]: outcome } } };
    },
  });
  vm.runInContext(source.slice(recordStart, recordEnd), context);
  return { run: () => context.recordAssemblySideOutcome({}, "fixture", checkpoints, async () => {}, spec), events };
}

test("assembly public record carries earned evidence through witnesses, Save, and Continue", async () => {
  const fixture = assemblyFixture();
  const state = await fixture.run();
  assert.equal(state.story.flags.bannerless_fate, "assembly");
  assert.deepEqual(fixture.events, [
    "earned_last_witness", "travel:assembly", "objective:greyfen_assembly",
    "interact:witness_3", "interact:witness_-3", "interact:witness_-7", "interact:witness_7",
    "interact:witnesses_ready", "objective:gather_witnesses", "interact:assembly_choice",
    "manual_save_overwritten", "continue_assembly",
  ]);
});

test("assembly public record rejects missing evidence before travel", async () => {
  const fixture = assemblyFixture(true);
  await assert.rejects(fixture.run(), /lost unresolved/);
  assert.deepEqual(fixture.events, ["earned_last_witness"]);
});

test("assembly public record rejects an incorrect dialogue outcome before save", async () => {
  const fixture = assemblyFixture(false, true);
  await assert.rejects(fixture.run(), /did not record/);
  assert.ok(fixture.events.includes("interact:assembly_choice"));
  assert.ok(!fixture.events.includes("manual_save_overwritten"));
});

test("saved-route marker propagates through every main-path wrapper without a second New Game", () => {
  const wrappers = [
    ["runOpeningThroughLastWitness", "runOpeningThroughRecordHall"],
    ["runOpeningThroughRecordHall", "runOpeningToEdric"],
    ["runOpeningToEdric", "runOpeningThroughCastle"],
    ["runOpeningThroughSoldier", "runOpeningToSenn"],
    ["runOpeningToSenn", "runOpeningThroughAsh"],
    ["runOpeningThroughAsh", "runOpeningToMiller"],
    ["runOpeningToMiller", "runOpeningThroughAshPreparation"],
    ["runOpeningThroughAshPreparation", "runOpeningThroughNames"],
    ["runOpeningThroughNames", "runOpeningThroughRootbound"],
    ["runOpeningThroughRootbound", "runOpeningThroughRegister"],
    ["runOpeningThroughRegister", "runOpeningThroughTeeth"],
    ["runOpeningThroughTeeth", "runOpeningThroughBellEater"],
    ["runOpeningThroughBellEater", "runOpeningAndCemetery"],
    ["runOpeningAndCemetery", "runOpeningToShrine"],
  ];
  for (const [wrapper, child] of wrappers) {
    assert.match(source, new RegExp(
      `async function ${wrapper}\\(cdp, url, checkpoints, onStartupReady, resumeAt = "new_game"\\) \\{\\s*await ${child}\\(cdp, url, checkpoints, onStartupReady, resumeAt\\);`
    ));
  }
  assert.match(source, /if \(resumeAt === "bandit_muster"\)/);
  assert.match(source, /if \(resumeAt === "greyfen_measure"\)/);
});
