# Runtime Ownership Boundaries

## Coordinator and Worlds

`game.gd` coordinates. `runtime_service_registry.gd` constructs/injects existing
services; `systems/game_bindings.gd` supplies the established facade. No duplicate
quest, save, relationship, input or streaming authority.

`zone_build_context.gd` and its construction host own destination construction.
Builders write to that context, retain generation/cursors and report cancellation
or failure. Preparation cannot borrow live-world fields, commit choices or attach
stale callbacks to replacement destinations. Publication attaches one ready context;
cancellation frees only that context.

`world_sector_manifest.gd` and JSON own sector/connector identity. Runtime,
residency and lifecycle owners handle activation, cached returns and renderer-safe
retirement. Preserve source ground until destination collision, navigation, actors,
interactions, audio and camera are ready. Active-tree publication stays main-thread.

## Facts, Presentation and Saves

`quest_manager.gd` owns objectives/completion; existing progression and inventory
owners issue once-only rewards. `story_state.gd` owns durable choices, knowledge,
Honor and memory. Completed quests do not invent skipped optional facts. Legacy
migration cannot fabricate kills, supplies, choices or consent.

Story activity/scene/world owners and cast schedules project facts into work,
dialogue, props and aftermath; they do not select outcomes. Dialogue uses existing
decision transactions. Important conversations suspend combat; ambient scenes
cannot consume Use or gate essential evidence.

Existing save ownership preserves the exact selected journey, recovery copies,
settings, inventory and unfinished encounters. Pending is not durable success.
Never silently load another journey to conceal selected-save failure.

## Actors, Input and Audio

One animation driver/presence priority owns each actor. Dialogue, combat, work and
ambient posture cannot fight over playback. Preserve clips, AnimationTree blending,
skins, materials, equipment and resumption after suspension.

Motion stays in physics; camera follow uses interpolated rendered motion. Preserve
unrestricted yaw, forward movement, first-person/bow transitions, collision and
dialogue restoration. A HUD is not proof of an enabled 3D viewport/current camera.

The interaction index supplies nearby candidates; Use validates the displayed
target and obstruction. Pointer/touch handoff cannot duplicate actions. HUD,
journal, atlas and compass present existing facts/routes, not change decisions.
The existing audio service owns routing, stream lifetime, unlock and transitions.

## Assets and Checks

`asset_database.gd` reads curated/runtime/visual catalogs. `asset_manifest.json` is
an inventory, not permission to export every model. Prepared actors/geometry keep
regeneration and recovery dependencies. Presets and pack manifests own inclusion.

Reuse `tools/` checks. Headless results are not visual/audio approval, browser
operation or FPS compliance. Separate implementation, compilation, observations,
publication and acceptance. Keep raw logs outside the source root and never weaken
assertions simply to make unrelated cleanup look green.
