# PERF-001 Final Mesh Residency Discriminant

## Scope

2026-09-27 native graphical Compatibility/ANGLE on Intel HD 620, 1280x720,
Balanced native 1.0, VSync disabled after applying settings, 60 FPS cap.
This is diagnostic evidence, not ticket acceptance or a cold-browser benchmark.
Driver-global caching, scheduling and temperature are not controlled.

The complete source scene was serialized outside the repository as a 2,363,562
byte static snapshot. Its 157 eligible nodes exclude actors, scripts, skinned
meshes, dynamic river and night-only branches. Arrays, embedded LODs, materials,
transforms, instance buffers and visibility contracts were checked against source.
Original physics and actor population were not replaced or removed.

## Discriminating Results

All eight isolated trials render 118 draws, use approximately 39.8 MB static
memory, and pass equivalence checks with clean process exit. Instantiation takes
10.2-12.7 ms; tree attachment takes 0.35-0.77 ms.

| Final graph used for first draw | A draw wait | B draw wait |
| --- | ---: | ---: |
| New meshes and materials | 374.453 ms | 257.035 ms |
| New meshes, resident materials | 214.152 ms | 202.068 ms |
| Resident meshes, new materials | 14.954 ms | 13.604 ms |
| Resident meshes and materials | 6.874 ms | 7.083 ms |

Resident-mesh trials retain the new MultiMesh instance buffer while sharing the
already-rendered mesh. Surface material references are temporarily replaced and
restored; equivalent values are asserted. The hidden primary is never destroyed.
These are CPU-side first-post-draw waits, not GPU hardware timers.

Earlier whole-graph A/B/A/B waits were 441.200/223.151 ms for new graphs and
5.435/5.151 ms for resident graphs. The factored test identifies mesh first-use
work as a dominant contributor in this static scene. It does not establish that
all full-game stalls are mesh uploads, or that shader/material cost is absent.

The full-game serialized-static trial instantiates in 12.42 ms, loads in 30.24 ms,
and publishes in 68.4 ms. Short warmed samples retain 261 draws and all original
actors, but their p99 times are not the authoritative 1% low. The first trial
accidentally sampled VSync reenabled by settings and remains invalid evidence;
the corrected trial explicitly disables it afterward.

## Source Synthesis And Candidate

`_validate_zone_render_resources` repairs absent base materials; it does not
duplicate an already valid scene graph. House resources are shared; overrides
are instance-owned. Asset repair copies protect per-actor overrides and must not
be indiscriminately replaced with shared mutable character materials.

The remaining opening stages create new mesh graphs after control. Existing
prewarm draws only the gameplay camera's visible subset. Building a complete
scene under the menu without rendering culled final meshes was already rejected
as sufficient. New candidate: prepare the complete scene once, explicitly draw
its final static mesh references in bounded preview batches, then hand off that
same root without rebuilding. Mutable actors, physics, materials and final
content must remain intact. No production implementation is accepted yet.

Candidate and all detailed logs/reports live under:
`D:/Temp/AshenOath/static_scene_ownership_20260927/`.
The diagnostic inheritance layer does not change the production game script,
export preset, verifier thresholds or Web bytes. Its native first-control and
settled samples use the existing strict 32/30 FPS thresholds; startup and warm
New Game are measured separately. Exact static-scene equivalence must also pass.

Formal count remains 27/37. No Web export, commit, push, merge or deployment.

## Candidate Results

The separate preview-viewport candidate is rejected: 70.233 seconds complete
preparation, including a 35.858 second first draw. Exact static equivalence
passes (157/157 nodes), but the different rendering context creates expensive
first-use work. Its harness hit a readiness timeout and sampled before actual
control; those samples cannot be labeled gameplay acceptance.

The first same-context run is invalid for residency: the helper incorrectly
looked for a Camera3D child although the active camera is not such a child.
The null-camera script error is preserved. The corrected helper obtains the
viewport's active camera and requires actual warmed meshes before sampling.

`readiness_same_context_v2` draws 218 final nonskinned geometry references in
the gameplay context. No resource duplication, script, material, renderer or
shutdown error occurs. Exact static equivalence passes; all original actors and
colliders remain. Additional constructor CPU is 188.991 ms. The sampled first
eight controllable seconds pass at 59.651 average / 31.040 1% low (including
the 67.264 ms first frame); the following eight seconds pass at 59.614/42.061.
New Game is 137.586 ms, static memory approximately 84.2 MB.

**The combined candidate still fails**: menu/preparation takes 28,093.316 ms,
above the unchanged 15-second hard ceiling. Inherited initial prewarm already
takes 17,829 ms. The diagnostic is not integrated into production and does not
approve other zones, routes, visual quality or browser performance. It cannot
ship by moving all work ahead of control. Source-state camera-independent static
equivalence does not prove all dynamic lighting/actor states identical.

Cache inventory from this genuinely fresh diagnostic profile contains 124 EGL
entries and fifteen SceneShaderGLES3 binaries, some about 1 MB each. Those files
are evidence of first-use compilation/cache work, not proof that disk I/O alone
owns the delay. The stronger next abstraction is the final material/mesh shader
family and its startup preparation, not another scene object or backend shuffle.

One material-family candidate was also rejected outside production source:
sampled boot 39,402.246 ms, New Game 351.725 ms, first-control low 4.739 FPS,
and failed effective static parity at unchanged 157-node count. Adding a white
texture for missing albedo and enabling zero emission seemed render-neutral,
but `game.gd:_mesh_surface_material` and imported-material repair use texture
presence as a semantic selector. Global early normalization is therefore not
safe. No shader/material normalization is integrated into runtime. Shader-family
deduplication must preserve those source-role decisions rather than relabel a
changed graph as equivalent. Detailed report: `neutral_material_performance_report.json`.

The engine's Compatibility guidance requires actual in-frustum drawing and
does not provide Forward+/Mobile ubershader guarantees:
https://docs.godotengine.org/en/4.6/tutorials/performance/pipeline_compilations.html
This is a platform constraint, not permission to relax startup or FPS budgets.

The current WORLD-001 closure continues with unresolved scene-level visual
acceptance. These experiments clarify the shared performance dependency but do
not close it. Do not repeat the preview-context warmup or global neutral-input
rewrite; do not create a Web artifact while native acceptance remains red.

## Single Final Publication Rejected

`single_publication_trial_20260927` is a different native-only preparation
ownership candidate: construct all stages without intermediate scene draws or
temporary boot materials, publish final lighting, and draw final references in
16-instance batches in the existing gameplay context. Parse checks pass; no
runtime/resource/renderer/shutdown error occurs. It remains outside production.

Measured boot is 20,573.742 ms, construction 352.124 ms, New Game 218.814 ms,
223 warmed meshes, 870 zone descendants. First control is 43.093 average / 7.643
FPS 1% low; following sample 42.847 / 19.489. Startup and both lows fail. The
report's equivalence field explicitly says **not evaluated**; its assertion is
deliberately red, not a demonstrated geometry mismatch or content-parity pass.
The candidate is rejected cheaply before further parity/image acceptance runs.
Sequential cache/thermal conditions prevent a causal comparison to earlier runs.

Both complete same-root residency and single-final-publication scheduling fail
the complete startup/frame contract. End this family of scheduling/warmup edits.
The factored static mesh/material evidence still identifies actual first-use
resource work, but cannot by itself certify a smaller shader-family solution or
every full-game spike. Next discriminant must operate on that resource contract,
preserve source-role material semantics, and reject unsupported features rather
than repeat an early global texture/emission normalization or object warmup.

## Renderer-Only Shader Family: Parity Pass, Full Contract Rejected

The source material remains unchanged; renderer adapters preserve its texture,
colour, emission, UV, roughness, metallic, cull, filtering and cutout state.
Unsupported features fail explicitly. A first fixture error on shared meshes
was corrected by recognizing the adapter's own materials idempotently; that
failed result remains preserved. The isolated graphical second run retains
157 nodes, 118 draws and 39,241 primitives. Inspected 1280x720 before/after
frames differ by at most 0.003921583 (one 8-bit colour step), mean 0.000001294.
This proves that static fixture's rendered equivalence, not performance gain:
baseline/candidate draw times have uncontrolled ordering/cache conditions.

`shared_static_family_game_trial_20260927` then binds 168 static instances,
112 material adapters, two renderer-only mesh copies and four shader families
without unsupported features. Boot is 20,717.619 ms, New Game 333.438 ms,
construction 240.755 ms. First control is 39.064 average / 2.457 FPS 1% low,
including 1448.750 and 108.491 ms frames. Settled is 50.933/35.615 at 272 draws,
105,819 primitives, 1121 nodes and 85,076,864 static-memory bytes. Runtime and
shutdown are clean; assertions correctly fail startup/first control. Full-game
geometry equivalence was **not evaluated**, not demonstrated unequal or passed.

The candidate is rejected as an end-to-end solution and remains outside source.
Isolated parity and settled FPS cannot waive the failed windows. PERF-001 stays
pending/parked; no further equivalent warmup, global normalization or shared
static shader experiment follows. Next independent closure objective is PRES-001
scene-level presentation. Any later performance intervention must distinguish a
different source-backed mechanism and still meet the complete startup/frame
contract before a Web export. Formal count remains 27/37.
