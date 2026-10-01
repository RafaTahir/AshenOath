# WORLD-001 Greyfen Framing - 2026-09-27

## Decision

Retain the coherent horizon/bridge-texture improvement as partial evidence,
not WORLD-001, PRES-001 or PERF-001 acceptance. Formal count remains 27/37.
No export, commit, push, merge or deployment.

## Implementation

- Two offset distant-tree rings use the existing licensed TwistedTree_2 source,
  one shared two-surface MultiMesh, no shadows or collisions, grounded origins,
  normalized 8.8-11.28 m heights and an open north-road sightline.
- The first inner ellipse failed actual body-height vertex bounds. The corrected
  36x31 m inner ellipse passes with zero playable-bound intrusions. Balanced has
  38 instances; Potato 23. Full source geometry is 347,092/210,082 triangles;
  this is not the culled/LOD-adjusted frame primitive count.
- Ridge geometry, seams and collision are unchanged; muted ridge colour reduces
  the bare green-wall appearance behind houses.
- Bridge timber retains its source texture, roughness, geometry and UV density,
  but uses world-space triplanar coordinates across scaled batch instances.
- Added focused actual-renderer geometry/material verification and a bridge-only
  capture option. No actors, routines, interactions, saves or quest state change.

## Verification And Actual Image Review

Logs and isolated profiles: `D:/Temp/AshenOath/`.

- `greyfen_framing_contract_final_20260927`: PASS. Actual synchronized MultiMesh
  transforms, grounded heights, all body-height vertices outside bounds, north
  sightline, shared valid materials, density, idempotence, shadow budget and no
  collision introduced. First immediate-read fixture returned zero transforms;
  that failed evidence is preserved. The fixture now waits for a real draw.
- `world001_greyfen_framing_capture_20260927`: four fresh 1280x720 views, clean
  native graphical run. All four were actually inspected against the preserved
  identical-camera `.release-gate/world001_landscape_joined/` views. Trees fill
  the blank horizon; timber grain is continuous instead of tiled checkerboards.
- `world001_wychwood_bridge_uv_capture_20260927`: clean changed-bridge capture,
  actually inspected. The deck texture improves without obscuring the path.
- These are staged art fixtures, not new player-route proofs. Existing genuine
  opening/bridge/Anwen/clue/five-enemy/return evidence remains scoped to unchanged
  gameplay and collision; no browser acceptance is inferred.
- `world001_greyfen_framing_perf_20260927.report.json`: FAIL. Settled native
  720p sample 40.658 average / 27.042 FPS 1% low, 263 draws, 105,851 primitives,
  1,109 nodes, 83,677,904 static memory bytes. Hydration 19.184 / 1.188 FPS,
  worst frame 1,188.992 ms. No frames discarded or thresholds changed. No causal
  performance improvement or regression attribution follows from sequential
  runs with uncontrolled driver-global caches/scheduling/temperature.

Full visual approval remains rejected: pale river-edge seams, coarse foreground
dressing, repeated trees, weak lighting depth and remaining cemetery/forest
presentation. These frames are not complete-gallery approvals.

## Image Identity

Greyfen directory: `.release-gate/world001_greyfen_framing/`.

| Image | SHA-256 |
|---|---|
| WORLD_001_Social_Spawn.png | ed4653cc32d4b3c3ccd5a92ba35c69408df2d9a6c636dd99cd56019c9cf2a74f |
| WORLD_001_Social_Table.png | b1b574599918e7f6d8a7f08bc467eb04ebf3a9233cdaf33648e34daaad47beaa |
| WORLD_001_Social_Apothecary.png | 6f4c720264fe5647fab765a36e5bbf5af4ec93e9a06f64d061e67c389f9f8323 |
| WORLD_012_04_Greyfen_River_Bridge.png | 541a69b1bf65eed26a08cc5f9992421bed525e14fd7d08ae6b8be33dd4cdc99f |

Wychwood: `.release-gate/world001_wychwood_bridge_uv/WORLD-013_03_Wychwood_Bridge_Canopy_20260927_215216.png`,
SHA-256 `1f49ca15587a6bddd0fa442d65f6a28c72e603e5c750e016dfa5c2501067ecd0`.

## Running Steps And Next Dependency

From `D:/Projects/AshenOath/outputs/AshenOathTheRoadBetweenCrowns`, with a QA
profile under `D:/Temp/AshenOath/`:

```powershell
$godot = 'C:\Temp\AshenOathGodot4.6.3\Godot_v4.6.3-stable_win64_console.exe'
& $godot --path . --rendering-driver opengl3_angle --script res://tools/verify_greyfen_framing.gd
& $godot --path . --rendering-driver opengl3_angle --script res://tools/capture_world_012.gd -- --landscape-only --output-dir=res://.release-gate/world001_greyfen_framing
& $godot --path . --rendering-driver opengl3_angle --script res://tools/capture_world_013.gd -- --bridge-only --output-dir=res://.release-gate/world001_wychwood_bridge_uv
& $godot --path . --rendering-driver opengl3_angle --script res://tools/verify_perf_001.gd -- --zone=greyfen
```

All owned runs exited. Current shared blocker is first-use construction/render
cost, not collision. Next: use the retained mesh-residency/material-selection
discriminant to resolve preparation ownership without repeated per-object warmup,
then require strict native startup and first-control proof before Web certification.
