# PERF-001 Native Render-Timing Discriminant, 2026-09-29

Status: diagnostic complete, no performance fix accepted. Formal recovery
status remains 27/37 accepted. Production and renderer settings are unchanged.

One opt-in native 1280x720 Balanced Compatibility/ANGLE run recorded Godot's
viewport CPU and GPU timing alongside existing stage and slow-frame samples.
The owned process exited 1 on the unchanged hydration 1% low assertion. Its
source-aligned report and full log are under
`D:/Temp/AshenOath/perf_render_attribution_20260929/`; report SHA-256 is
`48352c7e588286c6c09b92e750924b265cc792d28a4ed92ccda735735551553`.

| Window | Observed result | Contract |
| --- | ---: | --- |
| Greyfen menu-covered preparation | 22,926 ms | Above the 15,000 ms cold limit |
| New Game request to ready | 27.72 ms | Below the 750 ms handoff limit |
| Post-control hydration | 34.01 average / 1.45 FPS 1% low | Fails the 30 FPS low |
| Settled Greyfen | 45.70 average / 32.88 FPS 1% low | Passes in this run only |

The largest sampled prewarm frames were 13,130 and 7,769 ms. Hydration's
largest frame was 1,342 ms around `gameplay_gate_visual`; later slow frames
occurred at unrelated stages. Viewport GPU time was **0.0 ms for every sampled
slow frame**, so this renderer does not provide useful GPU attribution through
the API. Some wall-time spikes exceeded reported viewport render CPU time by
orders of magnitude; `Performance.TIME_PROCESS` sometimes reflected the stall
in the following sample. These asynchronous counters cannot identify a shader
compiler, mesh upload, GPU queue, storage, or scheduler as the unique owner.

This run reinforces the distributed first-visible failure and confirms that
settled throughput can pass while startup and hydration fail. It is not a
causal A/B test or release acceptance. The temporary viewport-timing probe was
removed after this answer; the optional unique report path remains to prevent
future diagnostics from overwriting canonical evidence. Do not repeat WPR or
this unsupported GPU-timing probe. The next PERF-001 intervention must be
source-backed and structurally different from the already rejected warmup,
cache, shader-family, light-capacity and exact-batching candidates.
