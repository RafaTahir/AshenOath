# PERF-001: ANGLE timer and opaque material discriminants

Status: diagnostic evidence, not ticket acceptance. No gameplay source, export, or production bytes changed by these probes.

## ANGLE frame timing

An isolated Godot 4.6.3 Compatibility build added asynchronous `GL_EXT_disjoint_timer_query` samples. It retained upstream eager shader initialization and used the unchanged Greyfen scene. The diagnostic run is in `D:/Temp/AshenOath/perf_gpu_query_20260930/greyfen.log` and its JSON report. Its cold frames included CPU draw times of 24,922 ms and 6,962 ms and corresponding ANGLE query intervals of 22,109 ms and 6,962 ms. A hydration frame spent 2,758 ms in CPU draw while its query interval was 1,202 ms. There were 27 slow samples, no disjoint results, and no skipped queries. The native gate remained red: hydration 24.34 FPS average / 0.88 FPS 1% low; settled 39.62 / 27.49.

These intervals do **not** prove that the GPU executed for that duration. ANGLE's D3D11 timer-query implementation timestamps queued work at begin and end; CPU shader-link or submission waits between those points can inflate elapsed time. The custom instrumented binary also reported static memory as zero, so this run cannot establish the memory budget. Its startup `vformat` error came from the diagnostic extension's setup message, not from project source. The normal Godot binary is used for acceptance.

## Reversible same-scene material comparison

The ignored `.release-gate/perf_opaque_material_probe_20260930.gd` sampled one fully dressed Greyfen at native 1280x720 Balanced with actors, geometry, camera, lighting, alpha surfaces, and gameplay unchanged. In each middle sample it temporarily assigned one neutral opaque material to 165 visible `MeshInstance3D` nodes, then restored the exact original overrides. Full logs are in `D:/Temp/AshenOath/perf_material_20260930.log` and `D:/Temp/AshenOath/perf_material_repeat_20260930.log`.

| Run/sample | Average FPS | 1% low FPS | Draw calls |
|---|---:|---:|---:|
| First: authored before | 42.32 | 24.96 | 256 |
| First: neutral | 49.93 | 37.50 | 252 |
| First: authored after | 46.80 | 32.30 | 252 |
| Repeat: authored before | 37.73 | 28.41 | 252 |
| Repeat: neutral | 43.29 | 26.27 | 252 |
| Repeat: authored after | 42.06 | 28.09 | 252 |
| Repeat: neutral again | 41.79 | 27.61 | 252 |
| Repeat: authored again | 43.72 | 30.38 | 252 |

The first run is warm-up confounded. The repeat did not show a reversible 1% low improvement; its final authored average exceeded the second neutral sample. Opaque-material replacement is therefore **rejected as the primary PERF-001 remedy**. The slight primitive-count changes and moving world state make these diagnostics, not acceptance-grade A/B performance results. Preserve the authored materials and the separately verified visual mipmap correction.

## Closure decision

PERF-001 is **implementation incomplete, parked with investigation budget exhausted, not accepted**. The stable comparison does not justify neutral material substitution; earlier source-backed covered readiness, exact static batching, publication scheduling, cache relocation, and demand-only shader compilation likewise moved or preserved the stalls. The cause remains unresolved: cold draw time spans shader linking and other submission work, and failed interventions do not establish a hardware, driver or engine ceiling. No further source-level change in those exhausted families has a credible measured path to removing the dominant first-visible stall while preserving the exact authored scene, so the finite investigation budget stops here rather than spending two more speculative implementations.

The unchanged native gate still reports **24.34 average / 0.88 FPS 1% low** during hydration and **39.62 / 27.49** when settled. Cold preparation has reached approximately **34 seconds** in the recorded profile. Warm/cold transition and total runtime-memory acceptance are still unproven. These values cannot be presented as a passing 32/30 FPS, 450 MB, or transition result. The precise hardware-versus-driver contribution is unresolved, not proven to be a fixed hardware limit.

The smallest next decision is whether to authorize a materially different renderer/content-ownership redesign with a Web counterpart and visual-equivalence proof. A changed target driver/machine may supply new evidence, but is not a diagnosis or automatic acceptance. Changing the target hardware or lowering the published thresholds would require a separate product decision and is **not** part of this recovery. No Web export or release acceptance follows from this diagnostic.
