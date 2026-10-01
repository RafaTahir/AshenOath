# PERF-001 Static Surface Discriminant - 2026-09-27

## Decision

Exact-material static ArrayMesh batching is **not a sufficient PERF-001 fix**.
No production builder, asset, actor, collision, material or LOD changed. The
answered diagnostic sources are archived under
`D:/Temp/AshenOath/static_batch_candidate_source_20260927`, outside export/Git.
PERF-001 remains pending; formal acceptance remains **26/37**. No Web export.

Two distinct scene-wide hypotheses now fail the unchanged acceptance floor:
complete covered final-scene readiness and exact-material static batching.
The latter reduces submission count but does not eliminate low-frame variance.
Publication scheduling alone remains unproven. Do not repeat per-object prewarm,
per-stage MultiMesh append, or another identical merge/cache-timing experiment.
Park PERF-001 on the recorded first-control/activation and sustained-low failures;
advance independent QA-003 evidence authority while retaining every green contract.

## Scope and Equivalence

The candidate excludes skeletal/animated meshes, controller-owned props, night
lights, transparent/custom shaders, object-space material features, embedded
LODs, individual distance culling, and nonuniform/mirrored transforms. Exact
material references and render layers/shadow modes are retained. Transformed
vertex positions, normals, tangents, UVs, colors, triangle indices/winding and
static collision identities are compared independently before rendering.

- Final unit contract: PASS, including embedded LOD, motion, bell, night-state,
  transform, material, collision and restoration assertions.
- `static_batch_geometry_final_20260927.log`: PASS with clean shutdown.
- Actual scene: 73 eligible mesh nodes, 103 source surfaces, 56 batch surfaces;
  zero geometry/attribute mismatches. Actors and gameplay remain active.
- Headless final construction/validation cost: 294.689 ms. Graphical cost:
  156.846 ms. This cost is not silently excluded from an implementation budget:
  there is no production implementation or first-control acceptance.

## Graphical A/B/A/B

One process, native 1280x720 Balanced, 60-Hz cap, eight-second samples, unchanged
actual gameplay camera and active simulation. Only adjacent equivalence captures
pause simulation; throughput samples do not. All logs/images/report are under
`D:/Temp/AshenOath/static_batch_graphical_20260927*`.

| Sample | Average FPS | 1% low FPS | Worst frame | Visible draws |
| --- | ---: | ---: | ---: | ---: |
| A1 original | 42.557 | 28.317 | 36.108 ms | 263 |
| B1 batch | 49.922 | 29.334 | 45.177 ms | 237 |
| A2 original | 40.841 | 25.507 | 41.056 ms | 263 |
| B2 batch | 42.136 | 26.271 | 39.890 ms | 232 |

Both candidate lows fail **30 FPS**. Average improvement varies substantially;
driver cache, temperature and scheduler are not independently controlled. A/B
isolates this settled scene, not cold publication or complete campaign performance.
Static memory is about 84.2 MB in all samples, including diagnostic geometry.

The graphical fixture exits 1 because its original final restoration assertion
also compared naturally moving NPC/Area collider transforms over 32 seconds.
That assertion is a harness error, not an observed scenery mutation. The corrected
fixture scopes static-scenery collision; its cheap headless full-scene proof passes.
The graphical run remains classified as **diagnostic with failed final assertion**,
not retrospectively relabeled a passing verifier or ticket acceptance. No broad
graphical rerun is necessary to reject the insufficient FPS result.

## Camera Review

Codex inspected both genuine 1280x720 gameplay images: identical scene composition,
actors, road, houses, river and bridge remain visible. Mean absolute channel
difference is 0.0500/0.0538/0.0556 on the 0-255 scale; 7931 pixels differ, maximum
channel delta 38. Animated water/sky and raster edges remain in the comparison.
This supports candidate scene equivalence, not general artistic approval.

## Remaining Blocker / Next Dependency

No current full performance evidence clears first-control hydration, every zone's
32/30 average/low contract and 350/900-ms transition budgets. Existing native
GL/ANGLE, viewport-disabled, constructor and submission traces stay authoritative
at their scopes. Reopen performance only with a discriminating source-backed
intervention beyond the rejected classes, not another displaced first-use stall.

Independent next closure objective: QA-003 semantic/current-revision evidence
authority. Existing Codex mode relies on source mtimes, omits runtime asset/role
changes and lets dry-run return a passing approval before freshness/pixel checks.
Fix those demonstrated release-integrity holes without approving stale imagery.
