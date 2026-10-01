# ARCH-001 Runtime Ownership Extraction

Status: accepted 2026-09-27 for bounded runtime ownership and unchanged player-facing behavior. Overall recovery/release remains NO-GO.

## Ownership

- DialogueRuntimeCoordinator: pair staging, validated separation, speaker facing, camera framing, animation locks and close/retirement cleanup.
- CombatVfxCoordinator: beam and arrow geometry, registered beam cancellation and effect-bound tween lifetime. Appearance, endpoints and timing remain unchanged.
- InteractionFocusService: camera/body line of sight, intended gate range and existing ground/vendor exceptions. Focus scoring and gameplay thresholds remain unchanged.
- QuestHudCoordinator: tracker, contextual guidance, compass distance and cache invalidation, consuming the existing authoritative ObjectiveViewModel.
- ZoneRuntimeCoordinator: ordered zone build, publication, grounding completion and failure rollback.
- ZoneResidencyService: one inactive zone, collision state restoration, eight-frame retirement, material/skinned anchors and explicit disposal.

Game wrappers and cache properties preserve callers without retaining duplicate state. Existing managers, quests, assets, spatial rules and builder order are not rewritten.

## Evidence

All logs below are under `D:/Temp/AshenOath`.

- `dialogue_coordinator_native_v1.log`: staging, blocked position, paused page, retired speaker and idempotent cleanup pass.
- `combat_vfx_coordinator_native_v3.log`: beam geometry, quality variants, cancellation isolation, natural expiry and parent disposal pass.
- `combat_vfx_oath_render_v1.log`: existing graphical Oathfire contract passes; not a real-input campaign route or FPS result.
- `interaction_visibility_native_v1.log`: physical wall occlusion, gate range, vendor fallback and speaker collider pass.
- `architecture_anwen_focus_v2.log`: real New Game, bridge walk, Anwen focus, E dialogue and release pass before the final lifecycle extraction.
- `quest_hud_coordinator_native_v1.log` and `architecture_objective_runtime_v1.log`: cache, tracker/compass/objective and save-summary identity pass.
- `architecture_residency_unit_v1.log`: actual collision/resource/cache replacement, grace period and duplicate retirement pass.
- `architecture_transition_parse_v2.log`: final extraction parser clean.
- `architecture_lifecycle_v1.log` / `.stderr.log`: graphical five-zone activation/material/retirement/shutdown passes; ANGLE driver advisory only.
- `architecture_rollback_before_v1.log`: deliberate failure regression exposes stale zone services. `architecture_rollback_after_v2.log` passes original root/service/transform and camera/sector/objective restoration.
- `architecture_opening_final_v1.log` / `.stderr.log`: current-source graphical real keyboard New Game, bridge, Anwen dialogue/release, Wychwood clues/combat/return/report, cemetery investigation/ambush/chapel and shrine choice pass, exit 0, ANGLE driver advisory only. No teleport, story flag preparation or direct interaction invocation is used for this route.

## Limits

Performance, authored world acceptance, current visual gallery, browser parity, full campaign permutations and production remain separately unaccepted. The graphical lifecycle run still measures Record Hall at 3234.6 ms and Greyfen return at 1084.9 ms. No Web export or Git/release operation occurs for diagnosis.

## Run

From `D:/Projects/AshenOath/outputs/AshenOathTheRoadBetweenCrowns`, use Godot 4.6.3 with `--headless --path . --script res://tools/verify_zone_residency.gd` for isolated ownership and `--rendering-method gl_compatibility --resolution 1280x720 --path . --script res://tools/verify_engine_004.gd` for graphical lifecycle. Real-input opening: `--script res://tools/verify_opening_real_input_native.gd` with the same graphical options. Set child-only APPDATA/LOCALAPPDATA to an isolated `D:/Temp/AshenOath` fixture; leave Windows global settings and player saves untouched.

Development checkpoint: preserved cumulative uncommitted work on `codex/masterpiece-rebuild`, HEAD `5b530361a5aae8612626532287b5bd27d7b244b8`. Production unchanged.
