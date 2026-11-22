import assert from 'node:assert/strict';
import { readFileSync, writeFileSync, mkdirSync, mkdtempSync, existsSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { dirname, resolve } from 'node:path';
import puppeteer from 'puppeteer-core';

const reportPath = resolve(process.argv[2] || 'D:/Temp/AshenOath/startup-half/light-buffers.json');
const probePath = process.argv[3];
assert(probePath, 'Usage: node tools/test_web_light_buffers.mjs <report.json> <captured-webgl.json> [baseline-ref-or-shell]');
const baselineRef = process.argv[4] || '3c05bdf';
const captured = readFileSync(probePath);
const probe = JSON.parse(captured);
const programs = probe.records.filter(r => r.method === 'getProgramParameter' && r.sources.length === 2 && r.elapsed > 500).slice(0, 4);
assert.equal(programs.length, 4, 'Four captured slow shader pairs are required');
const reference = programs[0].sources.find(s => s.includes('struct LightData'));
const declarations = ['DirectionalLightData', 'LightData', 'PositionalShadowData', 'DirectionalShadowData'].map(name =>
  reference.match(new RegExp('struct ' + name + '\\s*\\{[^}]+\\};'))[0]).join('\n');
const blockNames = ['OmniLightData', 'SpotLightData', 'DirectionalLights', 'PositionalShadows', 'DirectionalShadows'];
const blocks = blockNames.map(name => reference.match(new RegExp('layout\\(std140\\) uniform ' + name + '\\s*\\{[^}]+\\};'))[0]).join('\n');
const source = readFileSync(new URL('../web_boot_shell.html', import.meta.url), 'utf8');
const adapter = source.match(/<script id="ashen-bounded-light-loops">([\s\S]*?)<\/script>/)[1];
const previous = (existsSync(baselineRef) ? readFileSync(baselineRef, 'utf8')
  : execFileSync('git', ['show', `${baselineRef}:outputs/AshenOathTheRoadBetweenCrowns/web_boot_shell.html`], { encoding: 'utf8' }))
  .match(/<script id="ashen-bounded-light-loops">([\s\S]*?)<\/script>/)[1];
mkdirSync(dirname(reportPath), { recursive: true });
const profile = mkdtempSync(resolve(dirname(reportPath), 'light-buffer-profile-'));
const browser = await puppeteer.launch({ executablePath: 'C:/Program Files/Google/Chrome/Application/chrome.exe',
  headless: false, userDataDir: profile,
  args: ['--no-sandbox', '--disable-extensions', '--disable-background-networking', '--no-first-run'] });
try {
  const page = await browser.newPage();
  const result = await page.evaluate(async ({ adapter, previous, declarations, blocks, blockNames, programs }) => {
    const canvas = document.createElement('canvas');
    canvas.width = 32;
    canvas.height = 64;
    document.body.append(canvas);
    const gl = canvas.getContext('webgl2');
    if (!gl) throw new Error('WebGL2 unavailable');
    const original = WebGL2RenderingContext.prototype.shaderSource;
    const install = code => {
      WebGL2RenderingContext.prototype.shaderSource = original;
      delete window.__ashenBoundedLightLoops;
      (0, eval)(code);
    };
    const compile = (vertex, fragment) => {
      const start = performance.now();
      const shaders = [[gl.VERTEX_SHADER, vertex], [gl.FRAGMENT_SHADER, fragment]].map(([type, code]) => {
        const shader = gl.createShader(type);
        gl.shaderSource(shader, code);
        gl.compileShader(shader);
        if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) throw new Error(gl.getShaderInfoLog(shader));
        return shader;
      });
      const program = gl.createProgram();
      for (const shader of shaders) gl.attachShader(program, shader);
      gl.linkProgram(program);
      if (!gl.getProgramParameter(program, gl.LINK_STATUS)) throw new Error(gl.getProgramInfoLog(program));
      for (const shader of shaders) { gl.detachShader(program, shader); gl.deleteShader(shader); }
      return { program, ms: performance.now() - start };
    };
    const fields = [
      ['position', 0, 3], ['inv_radius', 3, 1], ['direction', 4, 3], ['size', 7, 1],
      ['color', 8, 3], ['attenuation', 11, 1], ['cone_attenuation', 12, 1],
      ['cone_angle', 13, 1], ['specular_amount', 14, 1], ['shadow_opacity', 15, 1],
      ['pad', 16, 3], ['bake_mode', 19, 1, true],
    ];
    const directional = [['direction', 0, 3], ['energy', 3, 1], ['color', 4, 3], ['size', 7, 1],
      ['enabled_bake_mode', 8, 1, true], ['shadow_opacity', 9, 1], ['specular', 10, 1], ['mask', 11, 1, true]];
    const families = [
      { array: 'omni_lights', fields, stride: 20, count: 32 },
      { array: 'spot_lights', fields, stride: 20, count: 32 },
      { array: 'directional_lights', fields: directional, stride: 12, count: 8 },
      { array: 'positional_shadows', fields: [['shadow_matrix', 0, 16], ['light_position', 16, 3],
        ['shadow_normal_bias', 19, 1], ['pad', 20, 3], ['shadow_atlas_pixel_size', 23, 1]], stride: 24, count: 32 },
      { array: 'directional_shadows', fields: [['direction', 0, 3], ['shadow_atlas_pixel_size', 3, 1],
        ['shadow_normal_bias', 4, 4], ['shadow_split_offsets', 8, 4], ['shadow_matrix1', 12, 16],
        ['shadow_matrix2', 28, 16], ['shadow_matrix3', 44, 16], ['shadow_matrix4', 60, 16],
        ['fade_from', 76, 1], ['fade_to', 77, 1], ['pad', 78, 2]], stride: 80, count: 8 },
    ];
    for (const family of families) family.fields = family.fields.flatMap(([name, offset, width, integer]) =>
      width === 16 ? [0, 1, 2, 3].map(column => [`${name}[${column}]`, offset + column * 4, 4])
        : [[name, offset, width, integer]]);
    let row = 0;
    const cases = families.flatMap(f => f.fields.map(([name, offset, width, integer]) => {
      const access = `${f.array}[i].${name}`;
      const value = integer ? access : `floatBitsToUint(${access})`;
      const padding = Array(4 - width).fill('0u');
      return `case ${row++}: if (i < ${f.count}u) value = uvec4(${[value, ...padding].join(', ')}); break;`;
    })).join('\n');
    const vertex = '#version 300 es\nvoid main() { vec2 p = vec2((gl_VertexID << 1) & 2, gl_VertexID & 2); gl_Position = vec4(p * 2.0 - 1.0, 0.0, 1.0); }';
    const fragment = `#version 300 es
precision highp float;
precision highp int;
#define MAX_FORWARD_LIGHTS 8u
#define MAX_LIGHT_DATA_STRUCTS 32
#define MAX_DIRECTIONAL_LIGHT_DATA_STRUCTS 8
${declarations}
${blocks}
layout(location=0) out uvec4 value;
void main() { uint i = uint(gl_FragCoord.x); value = uvec4(0u); switch(int(gl_FragCoord.y)) { ${cases} } }
`;
    const expected = new Uint32Array(32 * 64 * 4);
    row = 0;
    const buffers = families.map((f, family) => {
      const data = new ArrayBuffer(f.stride * f.count * 4);
      const floats = new Float32Array(data), words = new Uint32Array(data);
      for (let i = 0; i < f.count; i++) for (const [name, offset, width, integer] of f.fields) {
        for (let lane = 0; lane < width; lane++) {
          const index = i * f.stride + offset + lane;
          if (integer) words[index] = (0xf1234567 ^ (family * 0x1000 + index)) >>> 0;
          else floats[index] = (family + 1) * 0.125 + index * 0.03125;
        }
      }
      for (const [, offset, width] of f.fields) {
        for (let i = 0; i < f.count; i++) for (let lane = 0; lane < width; lane++)
          expected[(row * 32 + i) * 4 + lane] = words[i * f.stride + offset + lane];
        row++;
      }
      const buffer = gl.createBuffer();
      gl.bindBuffer(gl.UNIFORM_BUFFER, buffer);
      gl.bufferData(gl.UNIFORM_BUFFER, words, gl.STATIC_DRAW);
      return { buffer, bytes: words.byteLength };
    });
    const texture = gl.createTexture();
    gl.bindTexture(gl.TEXTURE_2D, texture);
    gl.texStorage2D(gl.TEXTURE_2D, 1, gl.RGBA32UI, 32, 64);
    const framebuffer = gl.createFramebuffer();
    gl.bindFramebuffer(gl.FRAMEBUFFER, framebuffer);
    gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, texture, 0);
    if (gl.checkFramebufferStatus(gl.FRAMEBUFFER) !== gl.FRAMEBUFFER_COMPLETE) throw new Error('Incomplete integer framebuffer');
    const layout = [];
    for (const [label, code] of [['baseline', previous], ['packed', adapter]]) {
      install(code);
      const { program, ms } = compile(vertex, fragment);
      gl.useProgram(program);
      for (let index = 0; index < blockNames.length; index++) {
        const block = gl.getUniformBlockIndex(program, blockNames[index]);
        const size = gl.getActiveUniformBlockParameter(program, block, gl.UNIFORM_BLOCK_DATA_SIZE);
        if (size !== buffers[index].bytes) throw new Error(`${label}: ${blockNames[index]} changed size ${size}`);
        gl.uniformBlockBinding(program, block, index);
        gl.bindBufferBase(gl.UNIFORM_BUFFER, index, buffers[index].buffer);
      }
      gl.viewport(0, 0, 32, 64);
      gl.drawArrays(gl.TRIANGLES, 0, 3);
      const pixels = new Uint32Array(expected.length);
      gl.readPixels(0, 0, 32, 64, gl.RGBA_INTEGER, gl.UNSIGNED_INT, pixels);
      const mismatch = pixels.findIndex((value, i) => value !== expected[i]);
      if (mismatch !== -1) throw new Error(`${label}: changed light word ${mismatch}: ${pixels[mismatch]} != ${expected[mismatch]}`);
      const error = gl.getError();
      if (error !== gl.NO_ERROR) throw new Error(`${label}: GL error ${error}`);
      layout.push({ label, ms, words_checked: pixels.length, adapter: { ...window.__ashenBoundedLightLoops } });
      gl.deleteProgram(program);
    }
    gl.bindFramebuffer(gl.FRAMEBUFFER, null);
    const timings = [];
    for (const [index, item] of programs.entries()) {
      const vertex = item.sources.find(s => /gl_Position\s*=/.test(s));
      const fragment = item.sources.find(s => s !== vertex);
      for (const [label, code] of [['baseline', previous], ['packed', adapter]]) {
        install(code);
        const { program, ms } = compile(vertex, fragment);
        timings.push({ index, label, ms, adapter: { ...window.__ashenBoundedLightLoops } });
        gl.deleteProgram(program);
      }
    }
    const info = gl.getExtension('WEBGL_debug_renderer_info');
    return { status: 'pass', renderer: info && gl.getParameter(info.UNMASKED_RENDERER_WEBGL), layout, timings };
  }, { adapter, previous, declarations, blocks, blockNames, programs });
  assert.equal(result.status, 'pass');
  result.inputs = { baseline_ref: baselineRef, captured_shader_path: resolve(probePath),
    captured_sha256: createHash('sha256').update(captured).digest('hex'),
    adapter_sha256: createHash('sha256').update(adapter).digest('hex'), profile,
    limitation: 'Compile timings are diagnostic, not a controlled browser startup benchmark.' };
  writeFileSync(reportPath, JSON.stringify(result, null, 2));
  console.log(JSON.stringify(result, null, 2));
} finally { await browser.close(); }
