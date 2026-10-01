import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import vm from "node:vm";

const source = readFileSync(new URL("./verify_qa_002_browser.mjs", import.meta.url), "utf8");
const start = source.indexOf("async function runBitterRootsMatrix(");
const end = source.indexOf("\nconst GREYFEN_SIDE_MATRIX", start);
assert.ok(start >= 0 && end > start);

function fixture(wrongOutcome = false) {
  const events = [];
  const checkpoints = [];
  let zone = "greyfen";
  let active = false;
  let collected = false;
  let outcome = "";
  const context = vm.createContext({
    runOpeningCampaign: async () => { events.push("earned_opening_route"); },
    saveThroughPauseMenu: async () => { events.push("manual_save"); },
    continueSavedOpening: async (_cdp, _url, _checkpoints, stage) => {
      assert.equal(stage, "bitter_roots_collected");
      outcome = "";
      events.push("continue_collected_roots");
    },
    traverse: async (_cdp, target) => {
      zone = target;
      events.push(`real_travel:${target}`);
    },
    useInteraction: async (_cdp, id, _checkpoints, dialogue, label) => {
      events.push(`real_interaction:${id}:${label || ""}`);
      if (id === "side_contracts") {
        assert.equal(dialogue, true);
        assert.equal(label, "Bitter Roots");
        active = true;
      } else if (id === "bitter_roots") {
        assert.equal(zone, "wychwood");
        collected = true;
      } else if (id === "mira") {
        assert.equal(zone, "greyfen");
        assert.equal(dialogue, true);
        outcome = wrongOutcome ? "wrong" : label === "Greyfen deserves the truth" ? "confessed" : "kept";
      }
    },
    freshTelemetry: async () => ({
      zone,
      quests: {
        active: active && !outcome ? ["side_bitter_roots"] : [],
        completed: outcome ? ["side_bitter_roots"] : [],
        objectives_done: { side_bitter_roots: collected ? ["collect_roots"] : [] },
      },
      story: { flags: { mira_truth: outcome } },
    }),
  });
  vm.runInContext(source.slice(start, end), context);
  return { run: () => context.runBitterRootsMatrix({}, "fixture", checkpoints, async () => {}), events, checkpoints };
}

test("Bitter Roots traverses Wychwood and reloads collected evidence before both choices", async () => {
  const { run, events, checkpoints } = fixture();
  const finalState = await run();
  assert.equal(finalState.story.flags.mira_truth, "kept");
  assert.deepEqual(events, [
    "earned_opening_route", "real_interaction:side_contracts:Bitter Roots",
    "real_travel:wychwood", "real_interaction:bitter_roots:", "real_travel:greyfen",
    "manual_save", "real_interaction:mira:Greyfen deserves the truth",
    "continue_collected_roots", "real_interaction:mira:Keep the truth between us",
  ]);
  assert.deepEqual(checkpoints.map((entry) => entry.outcome), ["confessed", "kept"]);
});

test("a wrong Mira outcome fails before choice evidence is recorded", async () => {
  const { run, checkpoints } = fixture(true);
  await assert.rejects(run(), /Bitter Roots confessed choice did not persist/);
  assert.equal(checkpoints.length, 0);
});
