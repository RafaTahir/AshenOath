# ENGINE-002 Complete Zone-Builder Extraction

## Files Changed

- `scripts/game.gd`
- `scripts/zone_build_context.gd`
- `scripts/zone_composition_router.gd`
- `scripts/zones/greyfen_section.gd`
- `scripts/zones/wychwood_section.gd`
- `scripts/zones/cemetery_section.gd`
- `scripts/zones/river_section.gd`
- `scripts/zones/ruins_section.gd`
- `scripts/zones/campaign_section.gd`
- `scripts/zones/castle_vargan_section.gd`
- `tools/verify_engine_002.gd`
- `ENGINE_002_COMPLETE_ZONE_BUILDER_EXTRACTION.md`

## Implementation

- `ZoneBuildContext` is now a named typed contract used by every released zone builder and embedded cemetery/river helper.
- Greyfen, Wychwood, and Ruins top-level construction moved out of `game.gd`; the router now owns their explicit compile-visible builder dispatch.
- Campaign and Castle builders now accept the typed context directly.
- Cemetery and river helpers no longer accept dictionaries or invoke host methods by string.
- Every build records a `zone_build_contract` containing ground, bounds, gate, root-identity, and error evidence.
- Gate IDs, authored marker names, quest conditions, enemy staging, Greyfen life routines, river recovery, save-facing zone IDs, and campaign arrival hooks were preserved.
- A static scan found no `host.call()`, `h.call()`, private string dispatch, `callv()`, or dictionary build context in released builders.

## Verification

Passed:

- Godot 4.6.3 parser/startup smoke.
- `verify_engine_001.gd`
- `verify_engine_002.gd`
- `verify_zone_builder_integrity.gd`
- `verify_runtime.gd`
- `verify_world_001.gd`

`verify_engine_002.gd` loaded and validated all 14 router-registered zones, including Greyfen, Wychwood, Ruins, the campaign road, Castle Vargan, Assembly, and Hart Glade.

Not completed after the user requested an immediate stop:

- `verify_world_002.gd` was interrupted while running.
- `verify_world_003.gd`
- `verify_gate_transitions.gd`
- `verify_river_swimming.gd`
- `verify_navigation_001.gd`

No failure was reported by those tests; their final result is unknown. The all-zone verifier emitted existing navigation edge-merge warnings and dummy-renderer teardown warnings involving null materials/RID cleanup. These remain visible diagnostics and were not broadened into this architecture ticket.

## Remaining `game.gd` Construction Debt

Top-level zone selection and gameplay content no longer live in `game.gd`, but low-level procedural rendering APIs remain there because moving them would couple this ticket to batching, materials, navigation, and gameplay managers:

- Greyfen terrain and dressing: `_make_greyfen_terrain_layers`, `_make_greyfen_path_edges`, `_make_spawn_composition`, `_make_greyfen_first_impression_dressing`, `_make_quality_greyfen_overhaul`, `_make_village_story_clusters`, `_make_village_house_dressed`, `_make_village_dressing`, `_make_greyfen_road_of_crows_story_beats`, `_make_village_place`.
- Wychwood terrain and dressing: `_make_wychwood_terrain_layers`, `_make_wychwood_path_edges`, `_make_wychwood_gate_scene`, `_make_wychwood_route_dressing`, `_make_quality_wychwood_overhaul`, `_make_wychwood_corridor`, `_make_wychwood_road_of_crows_story_beats`, `_make_monster_clearing`.
- Shared procedural primitives and batching: ground, split ground, roads, bounds, trees, props, lights, torches, fog, interactables, clues, gates, materials, collision, and environment batch flushes.
- Zone lifecycle remains correctly owned by `game.gd`: cache/prewarm, transitions, arrival recovery, navigation activation, manager hooks, audio/lighting activation, player spawning, and save-state restoration.

Further extraction should move cohesive low-level rendering families behind dedicated services only after ENGINE-003 defines resource lifecycle and cache ownership.

## Release

No export, commit, push, `web/` synchronization, or deployment was performed.
