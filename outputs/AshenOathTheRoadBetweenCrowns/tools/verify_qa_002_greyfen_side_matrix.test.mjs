import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import vm from "node:vm";

const source = readFileSync(new URL("./verify_qa_002_browser.mjs", import.meta.url), "utf8");
const start = source.indexOf("async function runGreyfenSideMatrix(");
const end = source.indexOf("\nasync function runOpeningSaveContinue(", start);
assert.ok(start >= 0 && end > start);

function fixture(kind, wrongOutcome = false) {
  const events = [];
  const checkpoints = [];
  let spec;
  let clueFound = false;
  let outcome = "";
  const context = vm.createContext({
    runOpeningCampaign: async () => { events.push("earned_opening_route"); },
    saveThroughPauseMenu: async () => { events.push("manual_save"); },
    continueSavedOpening: async (_cdp, _url, _checkpoints, stage) => {
      assert.equal(stage, spec.checkpointStage);
      clueFound = false;
      outcome = "";
      events.push("continue_pre_clue");
    },
    useInteraction: async (_cdp, id, _checkpoints, dialogue, label) => {
      events.push(`real_interaction:${id}:${label || ""}`);
      if (id === spec.clueInteraction) {
        assert.equal(dialogue, undefined);
        clueFound = true;
      } else if (id === spec.resolutionInteraction) {
        assert.equal(dialogue, true);
        outcome = wrongOutcome ? "wrong" : spec.choices.find((choice) => choice.label === label)?.outcome || "";
      }
    },
    freshTelemetry: async () => ({
      zone: "greyfen",
      quests: {
        active: outcome ? [] : [spec.quest],
        completed: outcome ? [spec.quest] : [],
        objectives_done: { [spec.quest]: clueFound ? [spec.clueObjective] : [] },
      },
      story: { flags: { [spec.outcomeFlag]: outcome } },
    }),
  });
  vm.runInContext(`${source.slice(start, end)}\nglobalThis.fixtureSpec = GREYFEN_SIDE_MATRIX[${JSON.stringify(kind)}];`, context);
  spec = context.fixtureSpec;
  return { run: () => context.runGreyfenSideMatrix({}, "fixture", checkpoints, async () => {}, spec), events, checkpoints, spec };
}

for (const kind of ["iron", "returned_soldier"]) {
  test(`${kind} matrix earns and reloads one pre-clue save for both outcomes`, async () => {
    const { run, events, checkpoints, spec } = fixture(kind);
    const finalState = await run();
    assert.equal(finalState.story.flags[spec.outcomeFlag], spec.choices[1].outcome);
    assert.deepEqual(events, [
      "earned_opening_route", `real_interaction:${spec.contractInteraction}:${spec.contractLabel}`,
      "manual_save", `real_interaction:${spec.clueInteraction}:`,
      `real_interaction:${spec.resolutionInteraction}:${spec.choices[0].label}`,
      "continue_pre_clue", `real_interaction:${spec.clueInteraction}:`,
      `real_interaction:${spec.resolutionInteraction}:${spec.choices[1].label}`,
    ]);
    assert.deepEqual(checkpoints.map((entry) => entry.outcome), Array.from(spec.choices, (choice) => choice.outcome));
  });

  test(`${kind} matrix rejects wrong outcome before recording branch evidence`, async () => {
    const { run, checkpoints } = fixture(kind, true);
    await assert.rejects(run(), /did not persist/);
    assert.equal(checkpoints.length, 0);
  });
}
