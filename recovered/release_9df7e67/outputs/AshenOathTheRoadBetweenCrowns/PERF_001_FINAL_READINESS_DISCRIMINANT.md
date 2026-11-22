# PERF-001 Final Readiness Discriminant - 2026-09-27

## Decision

Complete covered construction alone is rejected as a sufficient performance
fix. No production change moves the complete zone into boot. The answered
diagnostic script and verifier hook are removed; logs/reports remain on D:.
PERF-001 remains pending; formal count remains 26/37. No export or deployment.

The retained independent HUD fix separates desktop menu coordinates from the
shared 3D render target. The target stays 1280x720; the 1920x1080 menu layout
uses a Control transform. Web retains its existing responsive 720p layout.
`verify_ui_002` passes authored menu dimensions, transform, target, actions,
settings pagination and nonblocking loading checks. Graphical
`access001_stable_menu_20260927.log` passes genuine Continue, keyboard pause,
Save, physical Anwen/E/dialogue pages and resume with clean shutdown (Intel
ANGLE advisory only). The fresh 1280x720 pause image was inspected: text,
buttons and visible focus fit. This is not full accessibility or FPS acceptance.

## Evidence

All profiles, logs and copied reports reside in `D:/Temp/AshenOath/`:

| Diagnostic | Additional covered cost | Constructor / frame draw wait | First-control average / 1% low | Settled average / low |
| --- | --- | --- | --- | --- |
| `perf_final_readiness_20260927` | 3827.9 ms | 613.9 / 3153.4 ms | 36.61 / 16.46 | invalid comparison: physical movement contaminated it |
| `perf_final_readiness_trace_20260927` | 3445.2 ms | 417.4 / 2989.0 ms | 39.28 / 22.50 | 39.94 / 28.82 |
| `perf_stable_target_20260927` | 2511.6 ms | 332.7 / 2148.8 ms | 47.27 / 24.76 | 40.21 / 30.25 |

These are diagnostic variants, not normal verifier passes or exact scene
equivalence acceptance. The variant has 1142-1144 nodes and 269-270 draws;
the retained baseline has 1138 nodes / 263 draws / 90,907 primitives. No
final-scene equivalence approval is inferred from the variant's completion flag.
All thresholds remain unchanged. Cache seeds copy preceding completed profiles;
driver-global cache, scheduler and temperature are not controlled. The table
does not establish a causal speedup from sequential warmer samples.

The batched timing probe partitions process-to-pre-draw, draw submission and
post-draw wait. These are CPU-side signal boundaries, not hardware GPU timers.
The traced old handoff is 69.4 ms (26.2 ms before draw, 40.7 ms submission);
stable-target handoff still takes 58.6 ms (26.3 / 28.8). Later slow playable
frames show roughly 2-6 ms before draw and 22-32 ms submission. Constructor
cost and renderer/driver cost both exist; publication scheduling is not proven
to be their sole cause. Only the river creates a custom Shader: portals use
StandardMaterial3D, so a portal custom-shader deduplication hypothesis is rejected
by source inspection, not implemented.

The directly affected pause-ownership baseline remains explicitly failed:
`perf_pause_ownership_20260927.log` records 43.525 / 7.357 hydration and
41.484 / 27.935 settled, preserving full content. Pause ownership is retained
for demonstrated behavior, not claimed as an optimization.

## Next Action

Change abstraction level: inspect existing static batching ownership and build
one conservative scene-wide merge candidate, preserving transforms, materials,
collision, actors, interactive/dynamic branches and LOD behavior. Compare final
camera/content and native render cost before retaining it. Do not resume object
warmup, make another Web artifact, or count partial native evidence as acceptance.
