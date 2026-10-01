import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import vm from "node:vm";

const source = readFileSync(new URL("./verify_qa_002_browser.mjs", import.meta.url), "utf8");
const approach = source.slice(source.indexOf("async function approachMovingEnemy("), source.indexOf("async function clickDialogueAction("));
const select = source.slice(source.indexOf("function selectActiveEnemy("), source.indexOf("async function approachMovingEnemy("));
const steering = source.slice(source.indexOf("function movementKeyToward("), source.indexOf("async function attackLiveTarget("));
const hold = source.slice(source.indexOf("async function holdAxisTowardPoint("), source.indexOf("async function holdTowardPoint("));

test("live enemy approach passes the complete player record to steering", async () => {
  const far = { player: {position:{x:0,y:0,z:0}}, camera:{yaw:0}, enemies:[{active:true,health:10,position:{x:0,y:0,z:-5}}] };
  const near = {...far, player:{position:{x:0,y:0,z:-3}}};
  let state = far;
  const inputs = [];
  const context = vm.createContext({
    combatTelemetry: async () => state,
    sleep: async () => {},
    clamp: (v, lo, hi) => Math.max(lo, Math.min(hi,v)),
    noRearm: true,
    releaseMovementKeys: async () => {},
    startMovementHeartbeat: () => async () => {},
    dispatchMovementKey: async (_cdp, code, _key, down) => {
      if (down) { inputs.push(code); state = near; }
    },
  });
  const run = vm.runInContext(`${steering}\n${hold}\n${select}\n${approach}\napproachMovingEnemy`, context);
  assert.equal(await run({send:async () => {}}, 2.84), near);
  assert.deepEqual(inputs, ["KeyW"]);
});
