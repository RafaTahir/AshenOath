(() => {
  if (window !== window.top) return;
  const timeline = [];
  let nextId = 0;
  const publish = (context, id) => {
    timeline.push({
      context_id: id,
      type: "realtime",
      state: String(context.state),
      timestamp_ms: performance.now(),
    });
  };
  const native = window.AudioContext || window.webkitAudioContext;
  if (typeof native === "function") {
    const wrapped = new Proxy(native, {
      construct(target, argumentsList, newTarget) {
        const context = Reflect.construct(target, argumentsList, newTarget);
        const id = `firefox-audio-${++nextId}`;
        publish(context, id);
        context.addEventListener("statechange", () => publish(context, id));
        return context;
      },
    });
    if (window.AudioContext) window.AudioContext = wrapped;
    if (window.webkitAudioContext) window.webkitAudioContext = wrapped;
  }
  Object.defineProperty(window, "__ASHEN_QA_AUDIO_TIMELINE__", {
    value: timeline,
    configurable: false,
    writable: false,
  });
})();
