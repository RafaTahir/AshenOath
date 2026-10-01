import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import vm from "node:vm";

const source = readFileSync(new URL("./verify_qa_002_browser.mjs", import.meta.url), "utf8");
const start = source.indexOf("async function runOpeningWidowMatrix(");
const end = source.indexOf("\nasync function runOpeningSaveContinue(", start);
assert.ok(start >= 0 && end > start);

function fixture({ wrongOutcome = false, missingClue = false } = {}) {
  const events = [];
  const checkpoints = [];
  let clueFound = false;
  let outcome = "";
  const state = () => ({
    zone: "greyfen",
    quests: {
      active: outcome ? [] : ["side_widows_bell"],
      completed: outcome ? ["side_widows_bell"] : [],
      objectives_done: { side_widows_bell: clueFound && !missingClue ? ["find_bell"] : [] },
    },
    story: { flags: { widow_truth: outcome } },
  });
  const context = vm.createContext({
    runOpeningCampaign: async () => { events.push("earned_opening_route"); },
    saveThroughPauseMenu: async () => { events.push("manual_save"); },
    continueSavedOpening: async (_cdp, _url, _checkpoints, stage) => {
      assert.equal(stage, "widow_active");
      clueFound = false;
      outcome = "";
      events.push("continue_pre_clue");
    },
    useInteraction: async (_cdp, id, _checkpoints, dialogue, label) => {
      events.push(`real_interaction:${id}:${label || ""}`);
      if (id === "widow_elna") {
        assert.equal(dialogue, true);
        if (label !== "Accept A Widow's Bell") {
          outcome = wrongOutcome ? "wrong" : label === "He was calling for a witness." ? "told" : "comforted";
        }
      } else if (id === "grave_bell") {
        assert.equal(dialogue, undefined);
        clueFound = true;
      }
    },
    freshTelemetry: async () => state(),
  });
  vm.runInContext(source.slice(start, end), context);
  return { run: () => context.runOpeningWidowMatrix({}, "fixture", checkpoints, async () => {}), events, checkpoints };
}

test("both Widow outcomes use one earned pre-clue save and real interactions", async () => {
  const { run, events, checkpoints } = fixture();
  const finalState = await run();
  assert.equal(finalState.story.flags.widow_truth, "comforted");
  assert.deepEqual(events, [
    "earned_opening_route", "real_interaction:widow_elna:Accept A Widow's Bell", "manual_save",
    "real_interaction:grave_bell:", "real_interaction:widow_elna:He was calling for a witness.",
    "continue_pre_clue", "real_interaction:grave_bell:",
    "real_interaction:widow_elna:The wind caught an old cord.",
  ]);
  assert.deepEqual(checkpoints.map((entry) => entry.outcome), ["told", "comforted"]);
});

test("a missing clue or wrong outcome fails before recording branch evidence", async () => {
  const missing = fixture({ missingClue: true });
  await assert.rejects(missing.run(), /grave bell interaction did not reveal/);
  assert.equal(missing.checkpoints.length, 0);
  const wrong = fixture({ wrongOutcome: true });
  await assert.rejects(wrong.run(), /Widow's Bell told choice did not persist/);
  assert.equal(wrong.checkpoints.length, 0);
});
