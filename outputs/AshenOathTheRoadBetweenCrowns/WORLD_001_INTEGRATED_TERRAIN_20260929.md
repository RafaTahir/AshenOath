# WORLD-001 Wychwood Integrated Ground (2026-09-29)

Status: retained scene-level improvement; WORLD-001 remains unaccepted and
Recovery-004 remains **27/37**.

The fixed arena camera showed three pale planes pasted over the Wychwood
forest floor: the road, clearing, and east layby. Their prior color and taper
trials failed visual review. `WychwoodTerrainPresentation` now authors route,
clearing, and layby wear into the six existing textured split-ground visuals.
The six original colliders, bridge gap, river recovery, actor positions, clue
route, and quest states are unchanged. No new shader or external asset is used.
The three overlaid ground meshes are no longer spawned.

Affected files: `scripts/wychwood_terrain_presentation.gd`, `scripts/game.gd`,
`scripts/zones/wychwood_section.gd`, `tools/verify_world_013.gd`, and
`tools/verify_wychwood_path_render.gd`.

Direct evidence:

- Parser checks for the new presentation, game, and affected verifiers pass.
- Graphical `verify_world_013.gd` passes with 474 nodes, 106 meshes, and 20
  MultiMeshes versus the preceding 477/109/20. It checks the integrated
  textured ground, road/forest tint difference, absent overlay slabs, and route
  clearance.
- Graphical `verify_wychwood_path_render.gd` passes at 1280x720, with
  `road_delta=165629` against the same ground without route tint.
- Four changed-view captures and a paired frozen day/night arena capture pass.
  The day/night arena images were actually inspected at 1280x720:
  `.release-gate/world001_integrated_ground_arena_20260929/`.
  Day SHA-256: `2a62f03a2b359182a878a1043621eb8dc6beab848f7280de788bd7096cc8588c`.
  Night SHA-256: `471a271bf36863cb9555851c1d78ad6b8e56122635268687d76087dc876f0060`.
- The affected runs have no active parser, material, resource, renderer, or
  shutdown error. ANGLE emits its existing Intel-driver advisory only.
- Full logs: `D:/Temp/AshenOath/world001_integrated_ground_{verify,render,capture,arena}_20260929.log`.

Review decision: retain the ground integration. The long pale path and
clearing band are gone in the same camera. This is visual and structural
evidence only, not a real-input encounter or PERF-001 acceptance. One cold
Wychwood transition in the structural verifier was 1116 ms and remains an
explicit performance failure.

The occupied arena is **still visually rejected**. The rendered Ghoulkin
appears as a hovering skull and hands, without a convincing connected lower
body. That is a character presentation defect, not ground color. The next
action is to identify its active source/model pose and correct the assembly
without changing enemy count, AI, combat, or quest behavior. Greyfen street
and cemetery backdrop cells also remain open. No Web export, commit, push,
merge, or deployment occurred.

Running steps from `D:/Projects/AshenOath/outputs/AshenOathTheRoadBetweenCrowns`:
run Godot 4.6.3 Compatibility graphically with `--script
res://tools/verify_world_013.gd` and `--script
res://tools/verify_wychwood_path_render.gd`; capture with `--script
res://tools/capture_world_013.gd --
--output-dir=res://.release-gate/<run> --arena-review`.
