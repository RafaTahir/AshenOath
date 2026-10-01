import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import vm from "node:vm";

const source = readFileSync(new URL("./verify_qa_002_browser.mjs", import.meta.url), "utf8");
const start = source.indexOf("async function chooseDialogueAction(");
const end = source.indexOf("\n}", start) + 2;
assert.ok(start >= 0 && end > start);

function fixture(actions, focusedAction = 0) {
  const events = [];
  const state = { visible: true, page: 2, pages: 3, actions, focused_action: focusedAction };
  const context = vm.createContext({
    freshDialogueState: async () => ({ ...state }),
    waitFor: async (predicate, label) => {
      const result = await predicate();
      if (!result) throw new Error(`Timed out: ${label}`);
      return result;
    },
    tapKey: async (_cdp, code) => {
      events.push(code);
      state.focused_action = (state.focused_action + (code === "ArrowDown" ? 1 : -1) + actions.length) % actions.length;
    },
    acceptDialogue: async () => { events.push("Enter"); },
  });
  vm.runInContext(source.slice(start, end), context);
  return { choose: (label) => context.chooseDialogueAction({}, label, 2), events };
}

test("named dialogue choice uses real focus navigation and Enter", async () => {
  const { choose, events } = fixture(["Witness", "Mercy"]);
  assert.equal(await choose("Mercy"), "Mercy");
  assert.deepEqual(events, ["ArrowDown", "Enter"]);
});

test("already focused choice needs only Enter", async () => {
  const { choose, events } = fixture(["Witness", "Mercy"]);
  assert.equal(await choose("Witness"), "Witness");
  assert.deepEqual(events, ["Enter"]);
});

test("absent or ambiguous action fails before accepting dialogue", async () => {
  for (const actions of [["Witness", "Mercy"], ["Cleanse", "Cleanse the shrine"]]) {
    const { choose, events } = fixture(actions);
    await assert.rejects(choose(actions[0] === "Witness" ? "Ash" : "Cleanse"), /absent or ambiguous/);
    assert.deepEqual(events, []);
  }
});
