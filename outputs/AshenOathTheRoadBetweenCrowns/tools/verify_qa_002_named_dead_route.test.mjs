import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import vm from "node:vm";

const source = readFileSync(new URL("./verify_qa_002_browser.mjs", import.meta.url), "utf8");
const start = source.indexOf("async function runNamedDeadSideRoute(");
const end = source.indexOf("\nconst GREYFEN_SIDE_MATRIX", start);
assert.ok(start >= 0 && end > start);

function fixture(missingChapel = false) {
  const events = [];
  const checkpoints = [];
  let zone = "greyfen";
  let chapel = false;
  let named = false;
  let threadActive = false;
  let charm = false;
  let candlesActive = false;
  const lit = new Set();
  const snapshot = () => ({
    zone,
    story: { flags: {
      chapel_names_read: chapel && !missingChapel,
      road_evidence_bram: true, road_evidence_sella: true,
      oren_name_spoken: named, oren_charm_returned: charm,
      three_candles_lit: lit.size === 3,
      ...Object.fromEntries(["bram", "sella", "oren"].map((victim) => [`candle_${victim}_lit`, lit.has(victim)])),
    } },
    quests: {
      active: [threadActive && !charm ? "side_childs_charm" : "", candlesActive && lit.size < 3 ? "side_three_candles" : ""].filter(Boolean),
      completed: [charm ? "side_childs_charm" : "", lit.size === 3 ? "side_three_candles" : ""].filter(Boolean),
      objectives_done: {
        side_childs_charm: threadActive ? ["trace_thread"] : [],
        side_three_candles: [...lit].map((victim) => `light_${victim}`),
      },
    },
  });
  const context = vm.createContext({
    runOpeningThroughBellEater: async () => { events.push("earned_bell_route"); },
    traverse: async (_cdp, target) => { zone = target; events.push(`real_travel:${target}`); },
    useInteraction: async (_cdp, id, _checkpoints, dialogue, label) => {
      events.push(`real_interaction:${id}:${label || ""}`);
      if (id === "chapel_names") chapel = true;
      if (id === "ritual_stones") named = true;
      if (id === "side_contracts" && label === "Oren's Red Thread") threadActive = true;
      if (id === "oren_charm_shrine") charm = true;
      if (id === "side_contracts" && label === "Three Candles Unlit") candlesActive = true;
      if (id.startsWith("memorial_candle_")) lit.add(id.slice("memorial_candle_".length));
      if (id === "mira" || id === "side_contracts") assert.equal(dialogue, true);
    },
    freshTelemetry: async () => snapshot(),
    saveThroughPauseMenu: async () => { events.push("manual_save"); },
    continueSavedOpening: async (_cdp, _url, _checkpoints, stage) => {
      assert.equal(stage, "named_dead_complete");
      events.push("continue_named_dead");
      return snapshot();
    },
  });
  vm.runInContext(source.slice(start, end), context);
  return { run: () => context.runNamedDeadSideRoute({}, "fixture", checkpoints, async () => {}), events, checkpoints };
}

test("named-dead route earns both quests through real inputs and saves one result", async () => {
  const { run, events, checkpoints } = fixture();
  const finalState = await run();
  assert.equal(finalState.story.flags.three_candles_lit, true);
  assert.deepEqual(events, [
    "earned_bell_route", "real_interaction:mira:I will read the chapel register",
    "real_interaction:chapel_names:", "real_travel:wychwood",
    "real_interaction:ritual_stones:", "real_travel:greyfen",
    "real_interaction:side_contracts:Oren's Red Thread", "real_interaction:oren_charm_shrine:",
    "real_interaction:side_contracts:Three Candles Unlit",
    "real_interaction:memorial_candle_bram:", "real_interaction:memorial_candle_sella:",
    "real_interaction:memorial_candle_oren:", "manual_save", "continue_named_dead",
  ]);
  assert.deepEqual(checkpoints.filter((item) => item.event === "named_candle_lit").map((item) => item.victim), ["bram", "sella", "oren"]);
});

test("missing chapel evidence fails before creating side-quest evidence", async () => {
  const { run, events, checkpoints } = fixture(true);
  await assert.rejects(run(), /lacks the player-earned chapel/);
  assert.equal(events.includes("manual_save"), false);
  assert.equal(checkpoints.length, 0);
});
