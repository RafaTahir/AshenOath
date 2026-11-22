# PERF-001 Backend and Cache Discriminant - 2026-09-27

## Decision

PERF-001 remains pending. Backend selection or a warmed resource cache alone is
not a sufficient fix. No runtime change is retained from this experiment.
The owned temporary `override.cfg` is removed and all owned processes exited.
No Web export, commit, push, merge or deployment occurred.

The distributed publication hypothesis remains plausible, not established as
the sole cause. Constructor/resource work remains a competing owner: the prior
draw-disabled run also failed. Prior publication scheduling and offline packed
sections are separately rejected in the registry. Do not repeat them or move
individual props between prewarm stages.

## Controlled Scope

The existing graphical `verify_perf_001.gd -- --zone=greyfen` ran unchanged at
native 1280x720 Balanced on Intel HD 620. Each process had an isolated D: profile.
The source, scene content and thresholds were unchanged. Settled snapshots
retained 263 draws, 90,907 primitives and 1,138 nodes, approximately 83.5 MB
reported static memory. Full browser-process memory is not measured here.

Original profile seed: `D:/Temp/AshenOath/perf_backend_20260927/seed`.
Backend-matched warm profiles copy the completed preceding process's Roaming
cache. Intel global driver caches were not cleared or controlled; these are
not true hardware-cold comparisons or browser certification.

| Actual backend/profile | Hydration average / 1% low | Worst frame | Settled average / 1% low |
| --- | --- | --- | --- |
| ANGLE `gl_a` (requested GL, auto-fallback) | 47.291 / 5.149 | 314.313 ms | 41.717 / 32.126 |
| Native GL `native_gl_a` | 37.781 / 1.470 | 1672.500 ms | 60.021 / 50.104 |
| ANGLE `angle_b` | 43.427 / 2.145 | 682.407 ms | 58.988 / 33.651 |
| Native GL backend-matched warm | 59.768 / 27.201 | 50.071 ms | 60.004 / 51.458 |
| ANGLE backend-matched warm | 45.303 / 9.946 | 135.254 ms | 53.997 / 44.461 |

Every run failed the unchanged hydration floor. No active material/resource or
renderer error was recorded; the Intel ANGLE advisory is classified separately.
`gl_a` cannot be called a GL comparison: Godot's Intel fallback was active.
Native GL was confirmed only while a diagnostic override disabled that fallback.

## Evidence and Next Dependency

Full logs and copied reports are in
`D:/Temp/AshenOath/perf_backend_20260927/`. Stage names are frame-boundary
observations, not proven physical owners. Warm native GL still stalls at
`gameplay_visual_1` (50.071 ms) and base/place handoff (38.680 ms); warm ANGLE
still stalls at gate publication (135.254/118.388 ms) and several other stages.

Godot 4.6 documentation explicitly requires actual in-frustum rendering to
prepare Compatibility shaders; `load`/`preload` is not GPU readiness. See
https://docs.godotengine.org/en/4.6/tutorials/performance/pipeline_compilations.html.
That constraint must inform a scene-wide solution, while retaining startup,
population, input, visual and transition acceptance. Existing whole-zone
offscreen and packed-section failures cannot be ignored.

PERF-001 is parked on the unresolved first-use/activation budgets after those
distinct failed hypotheses. The independent ACCESS-001 pause-movement defect
is next; fix and prove it through visible pause/save menus and actual input.
No performance or full ACCESS acceptance follows from that scoped repair.
