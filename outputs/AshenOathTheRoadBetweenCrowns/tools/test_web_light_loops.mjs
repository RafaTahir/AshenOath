import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { runInNewContext } from 'node:vm';

const shell = readFileSync(new URL('../web_boot_shell.html', import.meta.url), 'utf8');
const installer = shell.match(/<script id="ashen-bounded-light-loops">([\s\S]*?)<\/script>/)[1];
let received;
class WebGL2RenderingContext {
  shaderSource(shader, source) { received = { receiver: this, shader, source }; }
}
const context = { WebGL2RenderingContext };
context.window = context;
runInNewContext(installer, context);
const installed = WebGL2RenderingContext.prototype.shaderSource;
runInNewContext(installer, context);
assert.equal(WebGL2RenderingContext.prototype.shaderSource, installed);
const gl = new WebGL2RenderingContext();
const shader = {};
const prefix = '#version 300 es\n#define MAX_FORWARD_LIGHTS 8u\n';
const body = ['omni', 'spot'].map(kind => `for (uint i = 0u; i < MAX_FORWARD_LIGHTS; i++) {
  if (i >= ${kind}_light_count) {
    break;
  }
  light_process_${kind}(i);
}`).join('\n');
gl.shaderSource(shader, prefix + body);
assert.equal(received.receiver, gl);
assert.equal(received.shader, shader);
assert.equal(context.__ashenBoundedLightLoops.loops, 2);
assert(received.source.includes('i < min(MAX_FORWARD_LIGHTS, omni_light_count)'));
assert(received.source.includes('i < min(MAX_FORWARD_LIGHTS, spot_light_count)'));
assert(received.source.includes('light_process_omni(i);'));
assert(received.source.includes('light_process_spot(i);'));
for (const source of [body, '#version 100\n' + body, prefix + 'void main() {}', prefix.replace('8u', '16u') + body]) {
  gl.shaderSource(shader, source);
  assert.equal(received.source, source, 'Unrecognized shader must remain untouched');
}
for (let count = 0; count < 64; count++) {
  const before = [], after = [];
  for (let i = 0; i < 8; i++) { if (i >= count) break; before.push(i); }
  for (let i = 0; i < Math.min(8, count); i++) after.push(i);
  assert.deepEqual(after, before, `Light order/count changed at ${count}`);
}
console.log('WEB LIGHT LOOPS: PASS (same ordered lights, unchanged unknown shaders, idempotent install)');
