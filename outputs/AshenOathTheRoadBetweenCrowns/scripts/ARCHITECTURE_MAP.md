# Live Architecture Baseline

Phase 0 only. Source: `main` at `3707be3e87aee3fb51aa42a931ebe55d6a4a90b0`.
This includes the travel fixes after the brief's `95359293` snapshot.
Counts are physical `splitlines()` counts, including blank/comment lines.
The scanned tree contains **242 GDScript files and 82,388 lines**.
This is static ownership analysis, not gameplay or performance certification.

## Existing Composition

`game.gd` (95 lines) already creates/injects `systems/*` and delegates callbacks.
`hud.gd` (2 lines) already delegates to `hud/hud_root.gd` and its panels.
`runtime_service_registry.gd` retains service construction and initialization.
`systems/game_state.gd` owns shared state; `systems/game_bindings.gd` aliases it.
Do not recreate motion, animation-graph, palette, silhouette, routine or camera helpers.

## Fifteen Largest Owners

Paths below are relative to `scripts/`; counts are exact for the source above.

| File | Lines | Current Responsibilities |
| --- | ---: | --- |
| `zone_construction_host.gd` | 4,283 | Scene/prop/actor factories, geometry/material batches, environment helpers and `_get`/`_set` coordinator proxy. |
| `player_controller.gd` | 2,760 | Physics locomotion, stamina, sword/bow/cast state, action poses and recovery. |
| `greyfen_life_controller.gd` | 2,430 | Opening staging, everyday work, interruptions, local scenes, props and reactions. |
| `enemy_ai.gd` | 2,216 | Perception, navigation, tactics, attack phases, animation, health and death. |
| `audio_manager.gd` | 1,907 | Buses, cues, music/ambience ownership, transitions, browser unlock and pause recovery. |
| `asset_spawn_helper.gd` | 1,548 | Resource preparation/cache, role spawning, rig assembly, material recovery and asset normalization. |
| `input_router.gd` | 1,526 | Device/remap state, contexts, buffered actions, mouse capture, gamepad and touch routing. |
| `character_animation_driver.gd` | 1,504 | Imported clip mapping, AnimationTree playback, locomotion cadence and action/pose ownership. |
| `save_manager.gd` | 1,395 | Journey/slot selection, atomic files, version recovery, summaries and browser durability. |
| `saga_activities.gd` | 1,287 | Regional quest work, branches, once-only rewards and saved activity consequences. |
| `systems/game_bindings.gd` | 1,245 | Typed shared-state aliases and explicit service forwarding; compatibility facade, not new behavior. |
| `camera_controller.gd` | 1,168 | Orbit/follow, obstruction, first-person/bow view, dialogue composition and view restoration. |
| `systems/zone_lifecycle_service.gd` | 1,098 | Destination requests, verified pack waits, cancellation/recovery, spawning and activation handoff. |
| `story_activity_director.gd` | 1,044 | Authored activities, travel/work offers, friendship/personal scenes and regional presentation. |
| `seamless_world_service.gd` | 1,042 | Shared road policy, neighbor scheduling, preparation/cache contexts, crossings and residency handoff. |

## Current Debt Inventory

The generated baseline records per-file ceilings, not permission to grow debt.
Current totals: **687 incompletely annotated functions/lambdas; 1,728 reflection/
metadata calls; 40 global RNG calls; 178 `Time.get_ticks_*` calls**.
The only existing `_get`/`_set` owner is `zone_construction_host.gd`.
Wall clocks include legitimate UI/resource deadlines; this count does not classify
every call as simulation nondeterminism. Owned RNG methods are not global RNG calls.
Scene-coupled `RefCounted` helpers remain scene adapters until extracted; an
`extends RefCounted` declaration alone is not evidence of a scene-free model.

## Target Dependency Direction

Composition/services -> typed builders/views -> model transitions -> value data.
Models may consume scene-free core values, never scene services or scene handles.
Builders own scene creation/publication; views project state and emit player intent.
QuestManager, StoryState, inventory, saves and encounter owners remain authoritative.
Extraction must not create competing quest, reward, relationship or streaming owners.

## Phase 1: Ownership and Deterministic Inputs

`scripts/core/` targets (future files; none are implemented by Phase 0):
- `seeded_rng.gd`: explicit per-journey/encounter seeds and owned random draws.
- `sim_clock.gd`: accumulated fixed-step time supplied by physics, not wall time.
- `input_frame.gd`: typed action/movement/aim values captured once per physics tick.
- `sim_event_bus.gd`: typed fact/result events, no reflective dispatch or hidden decisions.
- `replay_runner.gd`: replay supplied input frames, seed and step sequence; no scene driving.
- `zone_instance_scope.gd`: explicit scene/resource/callback ownership and cancellation.

The scope may hold typed scene handles; it is not a scene-free model or another
dynamic facade. Reuse `ZoneBuildContext`, registry and current lifecycle contracts.
Keep resource decoding separate from bounded main-thread scene publication.
Introduce each core boundary only when its existing owner is being extracted.

## Phase 2: Scene-Free Economy and Persistence

`scripts/models/` contains data-only `RefCounted` models:
- `ammo_loadout_model.gd`: ammunition selection, quantities, cancellation/restoration.
- `vendor_economy_model.gd`: stock, prices, purchases and once-only transaction results.
- `save_payload_codec.gd`: validated payload encode/decode/migration, not files or IDB.

Existing inventory/vendor/save adapters retain signals, UI, atomic I/O and durable
receipt ownership. Preserve IDs, versions, supplies and selected-journey semantics.

## Phase 3: Player and Enemy Decisions

Additional `scripts/models/` targets:
- `player_combat_locomotion_model.gd`: movement/action arbitration and resource costs.
- `bow_aim_release_model.gd`: draw/cancel/release decisions from supplied aim/obstruction facts.
- `enemy_tactics_model.gd`: intent and attack reservations from supplied perception facts.

Keep collisions/raycasts, CharacterBody motion, AnimationTree and equipment in
typed scene adapters. Reuse `character_motion_step.gd`, `character_animation_graph.gd`
and the existing animation driver; do not replace them or change combat balance.
Physics owns simulation time; rendered camera/animation views consume its results.

## Phase 4: World and Cast Separation

Final `scripts/models/` targets:
- `world_transition_model.gd`: request/generation/ready/cancel/failure decisions as values.
- `living_cast_model.gd`: schedules, reservations, knowledge and interruption decisions.

`scripts/builders/`: typed actor, prop, terrain and zone construction extracted
from `zone_construction_host.gd`; eliminate its reflective coordinator proxy gradually.
`scripts/views/`: player/enemy pose/equipment, cast performance and world presentation
extracted from player, enemy and Greyfen-life controllers, with explicit typed owners.
Neither layer may reacquire dependencies through parent lookups, metadata or duck calls.
Preserve safe ground, complete destination readiness, renderer-safe retirement,
story gates, interruptible work, material bindings, saves and existing interfaces.
Decrease old-owner metrics as responsibilities move; do not merely relocate a god-object.

## Gate Semantics and Operation

Run from any working directory: the checker resolves its project from its own path.
`--write-baseline` explicitly writes `tools/architecture_baseline.json`; CI never does.
Default mode compares each existing file with its recorded ceiling for five counts.
The dynamic-proxy inventory additionally prevents adding `_set` to an existing `_get`
owner (or introducing another proxy in an inner class). Deletions/reductions are allowed.
Unbaselined files outside the four target directories fail rather than escape the gate.
All files in those directories obey the new-module law, even if later baselined.
Code tokens exclude comments/string contents; parent-path string arguments are inspected.
Debt-marker substrings are forbidden in comments and strings as well as executable code.
`untyped_funcs` counts each named function/lambda once if any parameter or return lacks
an explicit annotation; inferred defaults do not satisfy parameter annotations.
Global RNG counts exclude receiver calls; models forbid even receiver RNG calls.
The checker is deliberately not a Godot parser, type checker or whole-program purity proof.
Models also forbid obvious `Node2D`/`SceneTree` scene dependencies.
Built-in tests use in-memory snippets; no Godot, browser, fixtures or game execution.

CI runs on push/PR with read-only permissions, a pinned
[official checkout action](https://github.com/actions/checkout), static self-tests,
the ratchet and authored `data/*.json` syntax validation. No export/deploy job is added.
This phase adds exactly the map, checker, generated baseline and CI workflow;
no gameplay, production bundles, deploy scripts or later-phase modules are changed.
