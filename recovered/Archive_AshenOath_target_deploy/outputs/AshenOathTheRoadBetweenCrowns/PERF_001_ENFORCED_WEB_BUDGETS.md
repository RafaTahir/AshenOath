# PERF-001 — Enforced Web Budgets

## Changes

- Added `ZoneBudget` limits for nodes, meshes, MultiMeshes, skeletons, lights, material surfaces, transparency, and null materials.
- Added a graphical native-1280x720 verifier for average FPS, 1% low, static memory, New Game, cold transitions, and warm return.
- Limited inactive route caching to one adjacent zone and retired older render resources.
- Batched Greyfen cottage details and river geometry while retaining authored collision and semantic nodes.
- Reserved directional shadows for Quality; Balanced keeps native 720p authored lighting.
- Enabled generated mesh LOD selection and bounded presentation distance for skeletal actors.
- Reduced cloud overdraw from four cards per cluster to one irregular generated cloud card.
- Removed accidental character-presentation geometry from non-character dialogue objects.

## Enforced Limits

| Metric | Limit |
| --- | ---: |
| Average FPS | at least 28 |
| 1% low FPS | at least 24 |
| Static memory | below 450 MB |
| New Game | at most 750 ms |
| Cold transition | at most 900 ms |
| Warm transition | at most 350 ms |
| Web payload | below 100 MB |

## Measured Result

| Zone | Average FPS | 1% Low | Draws | Static Memory |
| --- | ---: | ---: | ---: | ---: |
| Greyfen | 34.6 | 26.3 | 218 | 65.8 MB |
| Wychwood | 40.8 | 34.5 | 110 | 68.9 MB |
| Castle Courtyard | 33.6 | 29.7 | 69 | 65.3 MB |
| Record Hall | 40.0 | 34.8 | 62 | 63.5 MB |
| Hart Glade | 45.9 | 39.2 | 56 | 63.1 MB |

New Game measured 250 ms, the slowest representative cold transition measured 482 ms, and warm return measured 168 ms. Measurements were taken by the final compact gate with the graphical Compatibility renderer after background import scanning settled.

## Verification

- `verify_runtime.gd`: pass
- `verify_river_swimming.gd`: pass
- `verify_visible_quality.gd`: pass
- `verify_world_001.gd`: pass after batched-facade contract update
- `verify_world_003.gd`: pass
- `verify_zone_budgets.gd`: pass across 15 released configurations
- `verify_perf_001.gd`: pass
- Local Web export and packed startup: pass at 64.0 MB total / 27.7 MB PCK

Godot still emits post-pass renderer teardown diagnostics when verifier scenes exit. Active rendered surfaces pass the null-material budget; shutdown cleanup remains technical debt for the milestone gate.

## Running

1. Open the project folder in Godot 4.6.3.
2. Press `F6` or `F5`.
3. Click **Enter**, then **New Game**.
4. Open **Settings** and leave **Visual Preset** on **Balanced** for the enforced native-720p target.

Production is not deployed by this ordinary WORKFLOW-002 ticket. The checkpoint is pushed to the roadmap development branch; production deploys after `MOBILE-001`.
