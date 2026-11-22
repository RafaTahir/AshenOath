(() => {
  const sources = new WeakMap();
  const attached = new WeakMap();
  const records = [];
  const totals = {};
  window.__ASHEN_WEBGL_PROFILE__ = { records, totals };
  for (const type of [window.WebGLRenderingContext, window.WebGL2RenderingContext]) {
    if (!type) continue;
    const proto = type.prototype;
    for (const method of ['shaderSource', 'attachShader', 'compileShader', 'linkProgram',
      'getProgramParameter', 'getShaderParameter', 'texImage2D', 'texSubImage2D',
      'compressedTexImage2D', 'bufferData', 'blitFramebuffer', 'drawElements', 'drawArrays']) {
      const original = proto[method];
      if (typeof original !== 'function') continue;
      proto[method] = function (...args) {
        if (method === 'shaderSource') sources.set(args[0], String(args[1]));
        if (method === 'attachShader') {
          const shaders = attached.get(args[0]) || [];
          shaders.push(args[1]);
          attached.set(args[0], shaders);
        }
        const started = performance.now();
        try {
          return Reflect.apply(original, this, args);
        } finally {
          const elapsed = performance.now() - started;
          const total = totals[method] ||= { calls: 0, ms: 0, max_ms: 0 };
          total.calls++;
          total.ms += elapsed;
          total.max_ms = Math.max(total.max_ms, elapsed);
          if (elapsed >= 20 && records.length < 100) {
            const shaders = attached.get(args[0]);
            records.push({ method, started, elapsed, parameter: typeof args[1] === 'number' ? args[1] : null,
              sources: shaders ? shaders.map(shader => sources.get(shader) || '') :
                sources.has(args[0]) ? [sources.get(args[0])] : [] });
          }
        }
      };
    }
  }
})();
