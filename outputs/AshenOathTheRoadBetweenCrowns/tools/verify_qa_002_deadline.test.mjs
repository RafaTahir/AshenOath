import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import vm from "node:vm";

const source = readFileSync(new URL("./verify_qa_002_browser.mjs", import.meta.url), "utf8");
const context = vm.createContext({ setTimeout, clearTimeout, fatal: (message) => new Error(message) });
vm.runInContext(`${source.slice(source.indexOf("async function withDeadline("), source.indexOf("class Cdp {"))}\nglobalThis.subject = {withDeadline, routeTransport};`, context);
const { withDeadline, routeTransport } = context.subject;

test("expired route cannot send later commands; owner diagnostics still work", async () => {
  const sent = [];
  const owner = { send: async (command) => { sent.push(command); } };
  const scope = routeTransport(owner);
  let resume;
  const paused = new Promise((resolve) => { resume = resolve; });
  let late;
  await assert.rejects(withDeadline(async () => {
    await paused;
    late = scope.cdp.send("Input.dispatchKeyEvent");
    return late;
  }, "test route", 5, scope.revoke), /timed out/);
  resume();
  await new Promise((resolve) => setImmediate(resolve));
  await assert.rejects(late, /expired/);
  await owner.send("Page.captureScreenshot");
  assert.deepEqual(sent, ["Page.captureScreenshot"]);
});

test("queued input checks revocation at dispatch, not only at enqueue", async () => {
  let run;
  const owner = {
    send() { return new Promise((resolve, reject) => { run = () => this._sendNow().then(resolve, reject); }); },
    async _sendNow() { throw new Error("should not dispatch"); },
  };
  const scope = routeTransport(owner);
  const pending = scope.cdp.send();
  scope.revoke();
  run();
  await assert.rejects(pending, /expired/);
});
