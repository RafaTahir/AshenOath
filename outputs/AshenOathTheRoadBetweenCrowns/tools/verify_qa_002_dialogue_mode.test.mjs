import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import vm from "node:vm";
import test from "node:test";

const source = readFileSync(new URL("./verify_qa_002_browser.mjs", import.meta.url), "utf8");
const start = source.indexOf("async function advanceDialogueInput(");
const end = source.indexOf("\n}", start) + 2;
assert.ok(start >= 0 && end > start);
for (const mode of ["mouse", "keyboard"]) {
  test(`dialogue ${mode} uses only its real input path`, async () => {
    const calls = [];
    const transport = {};
    const context = vm.createContext({
      dialogueInput: mode,
      acceptDialogue: async (cdp) => { assert.equal(cdp, transport); calls.push("keyboard"); },
      clickDialogueAction: async (cdp) => { assert.equal(cdp, transport); calls.push("mouse"); },
    });
    vm.runInContext(source.slice(start, end), context);
    await context.advanceDialogueInput(transport);
    assert.deepEqual(calls, [mode]);
  });
}

const clickStart = source.indexOf("async function clickDialogueAction(");
const clickEnd = source.indexOf("\n}", clickStart) + 2;
for (const failPress of [false, true]) {
  test(`dialogue click preserves coordinates and release on press failure=${failPress}`, async () => {
    const events = [];
    const context = vm.createContext({ viewport: { width: 1280, height: 720 }, INPUT_TIMEOUT_MS: 10000, sleep: async () => {} });
    vm.runInContext(source.slice(clickStart, clickEnd), context);
    const cdp = { send: async (method, params) => {
      if (method !== "Input.dispatchMouseEvent") return;
      events.push(params.type);
      assert.equal(params.x, 640);
      assert.equal(params.y, 654);
      if (failPress && params.type === "mousePressed") throw new Error("press failed");
    } };
    if (failPress) await assert.rejects(context.clickDialogueAction(cdp), /press failed/);
    else await context.clickDialogueAction(cdp);
    assert.deepEqual(events, ["mousePressed", "mouseReleased"]);
  });
}

const gameplayKeyStart = source.indexOf("async function tapGameplayKey(");
const gameplayKeyEnd = source.indexOf("\n}", gameplayKeyStart) + 2;
test("gameplay interaction tolerates only a paused-frame keyup timeout", async () => {
  const events = [];
  const context = vm.createContext({
    sleep: async () => {},
    dispatchKey: async (_cdp, code, _key, down) => {
      events.push([code, down]);
      if (!down) throw new Error("CDP Input.dispatchKeyEvent timed out");
    },
  });
  vm.runInContext(source.slice(gameplayKeyStart, gameplayKeyEnd), context);
  await context.tapGameplayKey({ send: async () => {} }, "KeyE", "e");
  assert.deepEqual(events, [["KeyE", true], ["KeyE", false]]);
});

test("gameplay interaction still rejects keydown and non-timeout keyup failures", async () => {
  for (const failureEdge of ["down", "up"]) {
    const context = vm.createContext({
      sleep: async () => {},
      dispatchKey: async (_cdp, _code, _key, down) => {
        if ((down ? "down" : "up") === failureEdge) throw new Error(`${failureEdge} rejected`);
      },
    });
    vm.runInContext(source.slice(gameplayKeyStart, gameplayKeyEnd), context);
    await assert.rejects(context.tapGameplayKey({ send: async () => {} }, "KeyE", "e"), new RegExp(`${failureEdge} rejected`));
  }
});
