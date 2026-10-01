import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import vm from "node:vm";

const source = readFileSync(new URL("./verify_qa_002_browser.mjs", import.meta.url), "utf8");
const combatStart = source.indexOf("async function fightBlackDogBandits(");
const start = source.indexOf("async function runBlackDogMatrix(");
const end = source.indexOf("\nconst GREYFEN_SIDE_MATRIX", start);
assert.ok(combatStart >= 0 && start > combatStart && end > start);

function fixture(wrongOutcome = false) {
  const events = [];
  const checkpoints = [];
  let zone = "greyfen";
  let active = false;
  let sheepfold = false;
  let camp = false;
  let defeated = false;
  let outcome = "";
  const context = vm.createContext({
    runOpeningCampaign: async () => { events.push("earned_opening_route"); },
    saveThroughPauseMenu: async () => { events.push("manual_save"); },
    continueSavedOpening: async (_cdp, _url, _checkpoints, stage) => {
      assert.equal(stage, "black_dog_investigated");
      outcome = "";
      events.push("continue_investigated");
    },
    traverse: async (_cdp, target) => {
      zone = target;
      events.push(`real_travel:${target}`);
    },
    useInteraction: async (_cdp, id, _checkpoints, dialogue, label) => {
      events.push(`real_interaction:${id}:${label || ""}`);
      if (id === "side_contracts") {
        assert.equal(dialogue, true);
        assert.equal(label, "The Black Dog Contract");
        active = true;
      } else if (id === "sheepfold") {
        assert.equal(zone, "greyfen");
        sheepfold = true;
      } else if (id === "bandit_camp") {
        assert.equal(zone, "wychwood");
        camp = true;
      } else if (id === "farmer_toma") {
        assert.equal(zone, "greyfen");
        assert.equal(dialogue, true);
        outcome = wrongOutcome ? "wrong" : label === "Tell them it fled" ? "hidden" : "spared";
      }
    },
    fightBlackDogBandits: async () => {
      assert.equal(zone, "wychwood");
      assert.equal(sheepfold && camp, true);
      defeated = true;
      events.push("real_bandit_combat");
    },
    freshTelemetry: async () => ({
      zone,
      quests: {
        active: active && !outcome ? ["side_black_dog"] : [],
        completed: outcome ? ["side_black_dog"] : [],
        objectives_done: { side_black_dog: sheepfold && camp && defeated ? ["find_dog"] : [] },
      },
      story: { flags: {
        black_dog_sheepfold_inspected: sheepfold,
        black_dog_bandit_camp_inspected: camp,
        black_dog_fate: outcome,
      } },
    }),
  });
  vm.runInContext(source.slice(start, end), context);
  return { run: () => context.runBlackDogMatrix({}, "fixture", checkpoints, async () => {}), events, checkpoints };
}

test("Black Dog earns both clues and bandit victory before saving and reporting", async () => {
  const { run, events, checkpoints } = fixture();
  const finalState = await run();
  assert.equal(finalState.story.flags.black_dog_fate, "hidden");
  assert.deepEqual(events, [
    "earned_opening_route", "real_interaction:side_contracts:The Black Dog Contract",
    "real_interaction:sheepfold:", "real_travel:wychwood",
    "real_interaction:bandit_camp:", "real_bandit_combat", "real_travel:greyfen",
    "manual_save", "real_interaction:farmer_toma:The guardian protected the children",
    "continue_investigated", "real_interaction:farmer_toma:Tell them it fled",
  ]);
  assert.deepEqual(checkpoints.map((entry) => entry.outcome), ["spared", "hidden"]);
});

test("a wrong Toma outcome cannot be recorded as a completed branch", async () => {
  const { run, checkpoints } = fixture(true);
  await assert.rejects(run(), /Black Dog spared choice did not persist/);
  assert.equal(checkpoints.length, 0);
});

function combatFixture(staged = true) {
  let now = 0;
  let defeated = 0;
  let locks = 0;
  const checkpoints = [];
  const context = vm.createContext({
    Date: { now: () => now },
    sleep: async (ms) => { now += ms; },
    combatTelemetry: async () => ({
      player: { health: 100, position: { x: 0, z: 0 } },
      enemies: staged ? [0, 1].map((index) => ({
        id: "bandit", active: true, health: index < defeated ? 0 : 20,
        position: { x: 1, z: -1 },
      })) : [],
      quests: { objectives_done: { side_black_dog: defeated === 2 || !staged ? ["find_dog"] : [] } },
    }),
    tapGameplayKey: async (_cdp, key) => { if (key === "KeyT") locks += 1; },
    attackLiveTarget: async () => { defeated += 1; return { player: {} }; },
    approachMovingEnemy: async () => { throw new Error("unexpected movement fixture"); },
  });
  vm.runInContext(source.slice(combatStart, start), context);
  return { run: () => context.fightBlackDogBandits({}, checkpoints), checkpoints, get defeated() { return defeated; }, get locks() { return locks; } };
}

test("Black Dog combat drives two real attack edges before quest completion", async () => {
  const fixture = combatFixture();
  await fixture.run();
  assert.equal(fixture.defeated, 2);
  assert.equal(fixture.locks, 2);
  assert.equal(fixture.checkpoints[0].count, 2);
});

test("Black Dog combat rejects an unearned completion flag", async () => {
  const fixture = combatFixture(false);
  await assert.rejects(fixture.run(), /without two staged bandits/);
  assert.equal(fixture.checkpoints.length, 0);
});
