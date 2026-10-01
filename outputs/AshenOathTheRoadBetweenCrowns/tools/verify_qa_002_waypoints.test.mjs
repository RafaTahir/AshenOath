import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import vm from "node:vm";

const source = readFileSync(new URL("./verify_qa_002_browser.mjs", import.meta.url), "utf8");
const routeSource = source.slice(source.indexOf("async function driveToInteraction("));
const block = routeSource.slice(routeSource.indexOf("    let waypoint ="), routeSource.indexOf("    const dx = waypoint.x"));
const select = vm.runInNewContext(`(route, routeIndex, player) => {
  const interaction = {position: route.at(-1)};
  ${block}
  return routeIndex;
}`);
const route = [{x:0,z:9.8}, {x:0,z:7.7}, {x:0,z:4.5}, {x:0,z:1.3}, {x:0,z:-5}, {x:2,z:-5}];

test("sparse observation advances every passed collinear waypoint", () => {
  assert.equal(select(route, 1, {x:0,z:1.745}), 4);
});
test("next unpassed waypoint is retained", () => {
  assert.equal(select(route, 1, {x:0,z:9}), 1);
});
test("final waypoint remains the destination", () => {
  assert.equal(select(route, 5, {x:2,z:-5}), 5);
});
