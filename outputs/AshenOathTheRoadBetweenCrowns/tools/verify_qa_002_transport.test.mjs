import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import vm from "node:vm";

const source = readFileSync(new URL("./verify_qa_002_browser.mjs", import.meta.url), "utf8");
const context = vm.createContext({ WebSocket: class {}, structuredClone });
vm.runInContext(`${source.slice(source.indexOf("class Cdp {"), source.indexOf("function consoleMessages(cdp)"))}\nglobalThis.Cdp = Cdp;`, context);
const tick = () => new Promise((resolve) => setImmediate(resolve));

test("pending Runtime acknowledgement cannot prevent delivery of key release", async () => {
  const cdp = new context.Cdp("unused");
  const sent = [];
  let releaseRead;
  cdp._sendNow = (method) => {
    sent.push(method);
    return method === "Runtime.evaluate"
      ? new Promise((resolve) => { releaseRead = resolve; }) : Promise.resolve({});
  };
  const read = cdp.send("Runtime.evaluate");
  await tick();
  const input = cdp.send("Input.dispatchKeyEvent", { type: "keyUp" });
  await tick();
  const deliveredBeforeRead = sent.includes("Input.dispatchKeyEvent");
  releaseRead({});
  await Promise.all([read, input]);
  assert.equal(deliveredBeforeRead, true);
});

test("key edges stay ordered while unrelated commands proceed", async () => {
  const cdp = new context.Cdp("unused");
  const sent = [];
  let releaseDown;
  cdp._sendNow = (method, params) => {
    sent.push(params.type || method);
    return params.type === "keyDown"
      ? new Promise((resolve) => { releaseDown = resolve; }) : Promise.resolve({});
  };
  const down = cdp.send("Input.dispatchKeyEvent", { type: "keyDown" });
  const up = cdp.send("Input.dispatchKeyEvent", { type: "keyUp" });
  const read = cdp.send("Runtime.evaluate");
  await tick();
  const before = [...sent];
  releaseDown({});
  await Promise.all([down, up, read]);
  assert.ok(before.includes("Runtime.evaluate"));
  assert.ok(!before.includes("keyUp"));
  assert.ok(sent.indexOf("keyDown") < sent.indexOf("keyUp"));
});

test("transport report retains success, failure and observation counts", async () => {
  const cdp = new context.Cdp("unused");
  cdp._sendPacket = async (method) => {
    if (method === "Runtime.evaluate") throw new Error("test timeout");
    return {};
  };
  await cdp.send("Page.enable");
  await assert.rejects(cdp.sendObservation("Runtime.evaluate"), /test timeout/);
  cdp._publishObservation({ ready: true });
  cdp._publishObservation({ ready: true });
  const report = cdp.transportSummary();
  assert.equal(report.methods["Page.enable"].completed, 1);
  assert.equal(report.methods["Runtime.evaluate"].failed, 1);
  assert.equal(report.observations.count, 2);
  assert.equal(report.pending_requests, 0);
  report.methods["Page.enable"].sent = 99;
  assert.equal(cdp.transportSummary().methods["Page.enable"].sent, 1);
});
