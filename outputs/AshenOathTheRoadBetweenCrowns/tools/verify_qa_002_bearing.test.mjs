import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import vm from "node:vm";
import test from "node:test";
const source = readFileSync(new URL("./verify_qa_002_browser.mjs", import.meta.url), "utf8");
const start = source.indexOf("  const yaw =", source.indexOf("async function holdTowardPoint("));
const end = source.indexOf("  const dx =", start);
const select = vm.runInNewContext(`(forcedYaw, cameraYaw) => {
  const initialState = {camera:{yaw:cameraYaw}};
  ${source.slice(start,end)}
  return yaw;
}`);
test("omitted override retains observed south-facing camera", () => assert.equal(select(null, Math.PI), Math.PI));
test("explicit north override remains valid", () => assert.equal(select(0, Math.PI), 0));
