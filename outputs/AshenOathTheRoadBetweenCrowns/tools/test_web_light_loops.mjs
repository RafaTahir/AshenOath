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
const lightStruct = `struct LightData {
 highp vec3 position; highp float inv_radius;
 mediump vec3 direction; highp float size;
 mediump vec3 color; mediump float attenuation;
 mediump float cone_attenuation; mediump float cone_angle;
 mediump float specular_amount; mediump float shadow_opacity;
 lowp vec3 pad; lowp uint bake_mode;
};`;
const lightBlock = 'layout(std140) uniform OmniLightData { LightData omni_lights[MAX_LIGHT_DATA_STRUCTS]; };';
const read = 'vec3 test(uint i) { return omni_lights[i].position; }';
const known = prefix + lightStruct + lightBlock + read;
gl.shaderSource(shader, known);
assert(received.source.includes('highp uvec4 ashen_omni_lights_words[MAX_LIGHT_DATA_STRUCTS * 5]'));
assert(received.source.includes('return ashen_omni_lights_position(uint(i));'));
assert(!/\bomni_lights\b/.test(received.source));
for (const source of [
  known.replace('highp vec3 position', 'mediump vec3 position'),
  known.replace('lowp uint bake_mode;', 'lowp uint bake_mode; highp float extra;'),
  known.replace('omni_lights[i].position', 'omni_lights[i + 1u].position'),
  known.replace('omni_lights[i].position', 'unknown(omni_lights[i])'),
  known.replace('MAX_LIGHT_DATA_STRUCTS', 'UNKNOWN_CAPACITY'),
]) {
  gl.shaderSource(shader, source);
  assert.equal(received.source, source, 'Unknown layout or access must retain the whole original block');
}
gl.shaderSource(shader, prefix + '#define USE_INSTANCING\nvoid main() {}');
assert.equal(received.source, prefix + 'void main() {}');
const usedInstancing = prefix + '#define USE_INSTANCING\n#ifdef USE_INSTANCING\nvoid main() {}\n#endif';
gl.shaderSource(shader, usedInstancing);
assert.equal(received.source, usedInstancing, 'Used instancing must remain intact');
for (const flag of ['DISABLE_REFLECTION_PROBE', 'USE_RADIANCE_MAP', 'APPLY_TONEMAPPING',
  'VERTEX_CODE_USED', 'FRAGMENT_CODE_USED', 'DIFFUSE_BURLEY', 'SPECULAR_SCHLICK_GGX',
  'DISABLE_FOG', 'DO_SIDE_CHECK', 'USE_OPAQUE_PREPASS']) {
  gl.shaderSource(shader, prefix + `#define ${flag}\nvoid main() {}`);
  assert.equal(received.source, prefix + 'void main() {}');
  for (const remainder of [`#ifdef ${flag}\nvoid main() {}\n#endif`, `#define OTHER_FLAG ${flag}\nvoid main() {}`]) {
    const used = prefix + `#define ${flag}\n` + remainder;
    gl.shaderSource(shader, used);
    assert.equal(received.source, used, 'Referenced stage features must remain intact');
  }
  const valued = prefix + `#define ${flag} 1\nvoid main() {}`;
  gl.shaderSource(shader, valued);
  assert.equal(received.source, valued, 'Unknown valued definitions remain intact');
}
console.log('WEB LIGHT LOOPS/BUFFERS: PASS (ordered lights, known layout, conservative fallback, unused-define equivalence, idempotent install)');
