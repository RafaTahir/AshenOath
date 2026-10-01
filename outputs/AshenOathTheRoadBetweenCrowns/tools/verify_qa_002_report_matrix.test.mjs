import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import vm from "node:vm";

const source = readFileSync(new URL("./verify_qa_002_browser.mjs", import.meta.url), "utf8");
const start = source.indexOf("async function runOpeningReportMatrix(");
const end = source.indexOf("\nasync function runOpeningSaveContinue(", start);
assert.ok(start >= 0 && end > start);

function fixture(wrongOutcome = "") {
  const events = [];
  const checkpoints = [];
  let selected = "";
  const outcomes = {
    sister_anwen: "private",
    notice_board: "public",
    retain_evidence: "retained",
  };
  const context = vm.createContext({
    runOpeningCampaign: async (_cdp, _url, _checkpoints, _ready, reportInteraction) => {
      assert.equal(reportInteraction, "");
      events.push("earned_unresolved_report");
    },
    saveThroughPauseMenu: async () => { events.push("manual_save"); },
    continueSavedOpening: async (_cdp, _url, _checkpoints, stage) => {
      assert.equal(stage, "unresolved");
      events.push("continue_unresolved");
    },
    useInteraction: async (_cdp, interaction, _checkpoints, dialogue) => {
      assert.equal(dialogue, true);
      selected = interaction;
      events.push(`real_interaction:${interaction}`);
    },
    freshTelemetry: async () => ({
      zone: "greyfen",
      story: { flags: { evidence_report: wrongOutcome || outcomes[selected] } },
      quests: { completed: ["main_road_of_crows"], active: ["main_bell_beneath_greyfen"] },
    }),
  });
  vm.runInContext(source.slice(start, end), context);
  return { run: () => context.runOpeningReportMatrix({}, "fixture", checkpoints, async () => {}), events, checkpoints };
}

test("all report outcomes use the same earned save and visible interactions", async () => {
  const { run, events, checkpoints } = fixture();
  const finalState = await run();
  assert.equal(finalState.story.flags.evidence_report, "retained");
  assert.deepEqual(events, [
    "earned_unresolved_report", "manual_save",
    "real_interaction:sister_anwen", "continue_unresolved",
    "real_interaction:notice_board", "continue_unresolved",
    "real_interaction:retain_evidence",
  ]);
  assert.deepEqual(checkpoints.map((entry) => entry.outcome), ["private", "public", "retained"]);
});

test("a wrong report outcome fails before recording branch evidence", async () => {
  const { run, checkpoints } = fixture("public");
  await assert.rejects(run(), /Real private report did not advance/);
  assert.equal(checkpoints.length, 0);
});
