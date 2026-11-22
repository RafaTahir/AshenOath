# PERF-001 isolated engine comparison (2026-09-29)

Formal recovery acceptance remains **27/37**. PERF-001 remains red. No game
source, export, tracked Web artifact, or production build was changed.

## Controlled change

- Official Godot 4.6.3 source: `35e80b3a8822a9df9be390814b62f44c0a9c69e8`.
- Both native binaries used identical Windows Compatibility build options,
  LLVM MinGW 20240619, and ANGLE `chromium/6601.2`. The matching toolchain
  fixed the initial link failure. The diagnostic builds use the fallback text
  server, so they are not drop-in production engines.
- The candidate removes only eager default-specialization compilation and its
  initial cache write from `ShaderGLES3::_initialize_version`. Requested
  specializations still compile and cache on first bind. Shader source, scene
  content, game logic, renderer settings, and thresholds were unchanged.
- Each run used a fresh isolated profile under
  `D:/Temp/AshenOath/perf_lazy_shader_build_20260929/runs/` and the same game
  bytes. The pristine engine SHA-256 is
  `e63488254264e38e977a8af87d4dab0d705d261757f04251ce8760199ca08c0e`;
  the demand-compilation engine SHA-256 is
  `f415bfb74bc5535a3981303a5ca685b49d9c965bd11d7053cf385dad21f7aff0`.

## Native results

| Run | New Game | Hydration average / 1% low | Worst hydration frame | Settled average / 1% low | Result |
|---|---:|---:|---:|---:|---|
| Pristine cold 2 | 811 ms | 24.24 / 1.09 FPS | 1556 ms | 39.12 / 25.05 FPS | Red |
| Demand cold 1 | 110 ms | 42.36 / 2.73 FPS | 795 ms | 43.80 / 33.12 FPS | Red |
| Pristine cold 3 | 84 ms | Timed out at 45 seconds | Not available | Not available | Red |
| Demand cold 2 | 122 ms | 10.05 / 0.52 FPS | 2074 ms | 47.76 / 36.38 FPS | Red |

The first candidate run supports eager default compilation as one contributor.
It does not establish it as the exclusive cause: both candidate runs violate
the 30 FPS hydration 1% low, and cold-run variability is large. The second
candidate has 43 slow hydration frames, distributed across unrelated gameplay
and village stages. Its largest two frames occur near `opening_spawn` and
`gameplay_gate_visual`; those labels are correlation, not physical ownership.
No runtime renderer error appears in the candidate stderr; the verifier reports
the unchanged FPS failure. This comparison does not prove visual parity,
target-hardware release performance, browser behavior, or full startup limits.

## Decision and next action

**Reject demand-only shader compilation as a standalone PERF-001 fix.** Keep
the isolated engine source and run logs for diagnosis; do not adopt it in the
project or start a Web export. Prior cache-toggle, one-object prewarm, and
publication-scheduler failures remain rejected at their recorded scopes.

Park PERF-001 while advancing the independent WORLD-001 scene-level visual
cells. Revisit performance after the final art is stable, using the existing
timing and stack evidence to choose a systemic compile/publication solution;
do not move another individual object or stage merely because its name appears
beside one slow frame. The next recovery action is a bounded WORLD-001
same-camera review of the remaining Greyfen/cemetery/Wychwood composition
cells, followed by one coherent authored pass on a selected scene.
