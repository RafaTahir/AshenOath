import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import vm from "node:vm";

const source = readFileSync(new URL("./verify_qa_002_browser.mjs", import.meta.url), "utf8");
const block = source.slice(source.indexOf("function startMovementHeartbeat("), source.indexOf("const MOVEMENT_KEYS ="));
const policy = source.match(/const noRearm = .*;/)[0];

test("ordinary sustained movement schedules no key-repeat traffic", async () => {
  const context = vm.createContext({ args: {}, setInterval() { throw new Error("unexpected repeat timer"); } });
  const start = vm.runInContext(`${policy}\n${block}\nstartMovementHeartbeat`, context);
  await start({}, [["KeyW", "w"]], () => true)();
});
test("legacy reassertion requires explicit diagnostic opt-in", () => {
  assert.equal(vm.runInNewContext(`${policy}\nnoRearm`, {args:{"reassert-movement":true}}), false);
  assert.equal(vm.runInNewContext(`${policy}\nnoRearm`, {args:{"reassert-movement":true,"no-rearm":true}}), true);
});
