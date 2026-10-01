# WORLD-001 Wychwood Path and Bridge Approach

Status: retained partial visual improvement, not WORLD-001 acceptance. Recovery remains 27/37 accepted.

The large dark road slab in the clue and bridge views belonged to `WychwoodWindingPath`. A local graphical owner comparison removed it when that node was hidden; hiding the other nearby ground nodes did not. The replacement uses a narrower wet-mud core with irregular width, forest-ground shoulders, and the same river gap and bridge-only collision. No gate, clue, NPC, enemy, quest, or save behavior changed.

The first render probe was invalid: it captured the main menu before the queued New Game reached Greyfen. It was corrected to wait for playable Greyfen and Wychwood. The controlled material/mesh comparison then showed that reversed triangle winding culled the path; restoring the renderer-facing order made the textured mesh visible. The final fail-closed probe checks a 1280x720 gameplay frame and requires a substantial pixel change in the near-road region when the path is hidden.

Verification: clean Godot parser/import; graphical `verify_world_013.gd` PASS (477 nodes, 109 meshes, 20 MultiMeshes, preserved route queries); `verify_wychwood_path_render.gd` PASS (`road_delta=311265`); four 1280x720 same-camera views captured cleanly in `.release-gate/world001_wychwood_path_accept_20260929/`. Logs are under `D:/Temp/AshenOath/world001_path_core_20260929/`. Visual review retains the narrower road and softened approach as a bounded improvement. This staged art fixture is not a real-input route, night-combat, Web, or performance acceptance.

A stale cached spatial-service reference also caused a typed assignment error during the first probe's shutdown. The cache lookup now checks validity before using the reference; subsequent graphical runs exit without that script error.

Remaining WORLD-001 cells: occupied Wychwood encounter depth and night readability, Greyfen street/support composition, and cemetery horizon/glazing. Do not promote this result to whole-ticket acceptance or export Web while native PERF-001 is red.

The subsequent paired day/night scene pass retained the existing two-light budget but placed both pools at the clearing, replacing the unused green bounce with a warmer threat-side light. A Wychwood-only moon/ambient/fog profile reduced the cyan cast. Eight of the existing 32 distant-tree instances now mask the exposed north boundary; no new tree batch or collision was added. Graphical WORLD-013 passes again at 477 nodes, 109 meshes, and 20 MultiMeshes. Same-camera 1280x720 evidence is in `.release-gate/world001_wychwood_day_candidate_20260929/` and `.release-gate/world001_wychwood_night_candidate_20260929/`; both captures exit cleanly. The first Ghoulkin and Kael are distinguishable at night, but the pale clearing/path surface and occupied-combat composition are still visually unaccepted. This is not a real-input or performance pass.

A combined path/clearing vertex-color trial produced a broad dark oval in the same day/night camera. The trial was removed; rejected frames remain in `.release-gate/world001_wychwood_surface_candidate_20260929/` for comparison. The remaining surface defect needs an authored mesh/composition solution, not another color-only adjustment.

A second terrain-shape trial varied the clearing edge and tapered the path without extra draw calls. A stable, frozen day/night arena camera showed that the path still read as a pasted-on light band; that source trial was also removed. Its diagnostic-only frames are in `.release-gate/world001_wychwood_arena_review_20260929/` and are not combat proof. Stop local vertex-color/width experiments; the next Wychwood surface intervention requires a different authored terrain method.

Local running steps: from `D:/Projects/AshenOath/outputs/AshenOathTheRoadBetweenCrowns`, run Godot 4.6.3 Compatibility graphically with `--script res://tools/verify_wychwood_path_render.gd`, then `--script res://tools/verify_world_013.gd`; use `--script res://tools/capture_world_013.gd -- --output-dir=res://.release-gate/<run>` for the four visual views.
