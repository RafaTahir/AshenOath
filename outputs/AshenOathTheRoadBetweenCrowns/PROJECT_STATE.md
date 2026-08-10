# Ashen Oath Project State

## Current Product Status

Ashen Oath is a **pre-alpha prototype**. It is not a commercial Alpha, Early Access build, finished campaign, photoreal game, or AAA production. The approved target is a polished 90-minute Web Act One followed by a 4-6 hour grounded-stylized campaign. See `PRODUCT_SCOPE_LOCK.md` and `ASHEN_OATH_MASTER_STUDIO_REVIEW.md`.

RECOVERY-003 replaces reflective campaign-zone construction with a validated `ZoneBuildContext`, removes the blocking travel overlay, and requires player-triggered gate verification. Deep Woods, the Long Road, Castle Approach, Courtyard, and Record Hall are implemented playable sections; later campaign content remains pre-alpha and must not be described as finished until its player-driven route and visual gates pass.

ANIM-001 release acceptance passed the complete functional suite, graphical route and animation captures, Web export, and packed startup. On the Dell 7280/Intel HD 620 ANGLE path, the final native-720p sample measured 37.5 FPS average, 35.6 FPS minimum, and a 129 ms warm transition.

PERF-REPAIR-001 supersedes the earlier provisional performance result with an enforced native-720p graphical gate. The repaired Dell 7280/Intel HD 620/ANGLE sample measured Greyfen at 46.73 FPS average / 30.25 FPS 1% low; every other required zone passed above the 32/30 FPS thresholds. Warm return measured 318.7 ms and all cold transitions stayed below 458 ms. Balanced now uses bounded routine ticking, distance-suspended animation, shadowless authored lighting, generated mesh LODs, bounded NPC presentation distance, batched cottage/river geometry, and at most one inactive cached route zone.

WEB-001 establishes the public Act One candidate gate. The development export
is 64.0 MB total with a 27.7 MB PCK, uses a native 1280x720 WebGL2 canvas, and
reaches Greyfen through real launch/menu input in both Chrome and Edge without
browser console errors. Cold headless software-WebGL runs require about 17
seconds to initialize the engine and another 14-15 seconds to reach Greyfen
after New Game; this remains known loading-performance debt. Production remains
unchanged during RECOVERY-003; the original roadmap candidate is not being
treated as recovery-approved.

INPUT-001 centralizes gameplay and menu input behind `InputRouter`. Keyboard
and mouse controls remain intact; Xbox-style gamepad movement, camera, combat,
interaction, menus, prompts, rumble, sensitivity, and future virtual-input
hooks now share the same semantic actions. The 64.0 MB development candidate
again reached Greyfen in Chrome and Edge at 1280x720 WebGL2 with no console
errors. Physical-controller testing remains required before public controller
support is considered final. The original roadmap is complete; RECOVERY-003
remains a separate repair milestone and has not been deployed.

MOBILE-001 completes the original roadmap with a Web-safe landscape touch
layout, multi-touch combat and exploration controls, touch-specific prompts and
settings, mobile-safe mouse behavior, and deterministic Chrome/Edge mobile
emulation. The 64.0 MB candidate reached Greyfen at 960x540 WebGL2 in both
browsers without console errors. This is mobile Web feasibility, not evidence
for a native store release or sustained physical-phone performance.

## COMBAT-001 Update

- Kael's light and heavy attacks resolve from the animated sword's measured hilt-to-tip sweep rather than a delayed radius/facing query.
- Kael visibly carries a steel Oathblade whose hilt follows the right-hand bone while its controlled equipment pivot prevents imported wrist axes from producing an upright pole. Light attacks use a lateral sweep; heavy attacks use an overhead cut.
- Sword damage, oil bonuses, impact position, sparks, audio, camera response, hit-stop, and HUD feedback share one authoritative contact result.
- The restrained slash trail follows one-frame blade motion while collision retains the full authoritative sweep, preventing screen-filling trail sheets.
- Enemy strikes report their weapon-space contact position so parry feedback and attacker stagger occur at the same moment and place.
- `verify_combat_001.gd` rejects the old imported weapon path, upward ready poses, undersized lateral/vertical blade travel, invisible/dark swords, non-wrist attachments, identical light/heavy clips, static attack arms, off-target radius hits, duplicate contacts, detached blade markers, and parries without contact/stagger.

## WORLD-001 Update

- Greyfen environment construction is owned by `scripts/zones/greyfen_section.gd`; quests, managers, transitions, and interactions remain under `game.gd`.
- Four opening-route houses use grounded modular tile roofs, closed plaster gables, deterministic wall/timber palettes, rear-facing windows, and zone-batched facade/chimney geometry. Quality mode retains the additional imported facade modules.
- The main road uses one 215-instance textured staggered paving batch instead of sparse checkerboard slabs. Selected full-tree meshes strengthen the boundary silhouette while navigation corridors remain reserved.
- `verify_world_001.gd` enforces structure ownership, modules, paving density, route clearance, retained landmarks, and per-zone budgets. `capture_world_001.gd` produces four mandatory native-720p gallery views.
- The visual target remains grounded low-poly dark fantasy. Current assets still do not support a photoreal or AAA claim.

## ART-001 Update

- The grounded-stylized visual bible and identical-camera asset audition are complete.
- The Warrior, Cleric, and OrcSkull candidates were rejected for runtime replacement after graphical review; they do not solve facial identity, role silhouette, or horror credibility.
- Existing Kael, Anwen, and Ghoulkin mappings remain temporary and explicitly require replacement in `CHAR-001` and `MON-001`.
- Selected village OBJ modules can instantiate through `AssetSpawnHelper`, but the audition street composition was rejected. `ASSET-001` may curate the components; `WORLD-001` must author the actual Greyfen composition.
- ART-001 is a development milestone and does not change or deploy the production game.

## ASSET-001 Update

- Runtime asset lookup now uses `curated_runtime_assets.json` instead of loading the 1.94 MB full-library manifest and the generated suggestion map.
- The curated contract contains 36 roles backed by 27 unique, locally verified CC0 files. Character and enemy entries remain explicitly marked temporary where they did not pass ART-001's final visual standard.
- Failed Warrior, Cleric and OrcSkull auditions plus three unused generated Ghoul GLBs are quarantined from Web export.
- Every retained asset records its source pack and local license file. Missing Wolf license coverage was added from the existing Quaternius Animated Animals source record.
- A preview Web export passed startup at 63.1 MB total / 26.8 MB PCK, down from the current production package's 69.52 MB / 33.23 MB. Production was not replaced or deployed by this development ticket.

## NAV-001 Update

- Greyfen and Wychwood now build deterministic authored `NavigationRegion3D` polygons without runtime baking.
- WORLD-002 moves Wychwood environment construction into `scripts/zones/wychwood_section.gd`, with an authored gate threshold, river crossing, investigation route, forest frame, and bounded combat clearing.
- `ZoneSpatialService` owns bridge anchors, gate corridors, exclusions, complete-segment validation, bank identity, occupancy checks, route construction, and same-bank recovery.
- All seven retained Greyfen routine actors use `NavigationAgent3D`; cross-bank routes are forced through the bridge and invalid routes stop safely.
- All five Wychwood encounter enemies use navigation-aware pursuit and flanking while preserving leash, staging, attack timing, and combat balance.
- Cached route zones retain their navigation region. The Dell 7280 graphical gate measured 38.2 FPS average, 36.7 FPS minimum, and a 246 ms warm transition.
- A development Web preview passed startup at the unchanged 63.1 MB total / 26.8 MB PCK. Production remains unchanged until ticket 10.

## CHAR-001 Update

- Kael, Sister Anwen, retained villagers, and the Wychwood pack now receive mesh-native deterministic identity palettes instead of skeletal-body-wide tints or detached face/proxy geometry.
- Kael uses dark hunter cloth, leather, linen, brass, and weathered skin; Anwen uses an older complexion, grey hair, midnight clerical cloth, ivory, and antique gold. Villager palettes vary deterministically by role.
- Anwen's invalid `Idle_Weapon` mapping was replaced with the imported body's real `Idle` clip.
- The skeletal Ghoulkin body is grounded to its animated leg endpoints and Wychwood variants receive distinct connected-body proportions.
- `verify_char_001.gd` checks skeletons, active clips, identity materials, distinct palettes, rendered height, animated foot grounding, and forbidden proxy anatomy.
- Graphical portraits and before/after sheets are stored in `Development_Gallery/screenshots/CHAR_001_*`.
- Dell 7280 graphical verification measured 37.9 FPS average and 35.1 FPS minimum. A development Web preview passed at the unchanged 63.1 MB total / 26.8 MB PCK. Production remains unchanged until ticket 10.

## ANIM-001 Update

- Major route-visible actors now share a semantic animation contract that resolves imported clip-name differences for locomotion, attacks, reactions, dodge/parry, Oathfire, and death.
- Walk and run playback cadence follows physical movement speed within bounded ranges, reducing routine-NPC foot sliding without changing controller physics.
- Kael's drawn and sheathed imported swords use bone sockets with inverse rig-scale spaces. This removes the oversized floating equipment caused by inherited source-rig scale while preserving hand/back motion.
- The graphical ANIM-001 gate captures idle, walk, attack, and Oathfire poses at 1280x720, rejects blank ANGLE readbacks, and creates a four-frame contact sheet.
- The current bodies remain intentionally low-poly; ANIM-001 improves motion consistency and equipment attachment, not mesh or facial fidelity.

## BUILD-RECOVERY-001 Update

- Release verification is centralized in `tools/run_release_gate.ps1`; graphical 720p and fresh screenshot gates may not be skipped.
- Imported character transforms follow one normalized-height contract and are multiplied rather than overwritten.
- Sister Anwen now turns toward Kael. Greyfen ambient routes are grounded and bridge-safe.
- The Wychwood five-enemy encounter is staged in three waves and retains five-kill progression. RECOVERY-002 is currently repairing traversal, actor scale, renderer integrity, and performance before the next deployment.
- Quest tracking persists an explicit tracked quest and selects zone-relevant main objectives.
- Repeated world boxes/details use shared meshes and MultiMesh batches. RECOVERY-002 measured 37.2 FPS average, 35.6 FPS minimum, and 294 ms warm route transition on Intel HD 620/ANGLE.
- The world remains intentionally stylized and low-poly; current assets do not support a photoreal/AAA claim.

## QA-REPAIR-001 Update

- The complete 1280x720 route capture was regenerated on 2026-08-11 at source revision `0f3114f`. It covers Greyfen, both bridge/recovery proofs, Wychwood combat, Castle Vargan, Record Hall, and Hart Glade.
- `verify_screenshot_qa_003.py --mode ticket` passes all 11 required views, and the five-test regression suite passes. The manifest remains `pending` because automated image checks cannot approve facial identity, composition, grounding, or art quality without human review.
- River recovery now prefers authored same-bank road anchors, and the bridge deck is excluded from emergency river recovery when its spatial service validates the bridge corridor. The full capture completes without the earlier false bridge/roof failures.
- Active gameplay no longer emits the previous null-material errors during capture. Godot still reports renderer/RID/ObjectDB cleanup diagnostics while the multi-zone capture process exits; these remain lifecycle debt and are not being marked as a clean release result.
- Current visual blockers remain honest: route-visible characters and buildings are low-poly/temporary, Anwen is not framed at portrait distance, Castle/Record Hall are blockout-grade, and the White Hart remains an underdeveloped procedural presentation. Production stays unchanged until those blockers receive an approved visual pass.

## QA-REPAIR-001 Verification Evidence

- Fresh gallery source: `Development_Gallery/screenshots/*2026-08-11_001909.png`
- Machine screenshot report: `.release-gate/qa_003_ticket_report.json`
- Performance report: `.release-gate/perf_001_report.json`
- Full route capture command and targeted gate commands are recorded in `QA_REPAIR_001_SCREENSHOT_VISUAL_APPROVAL.md`.

Last updated: 2026-08-11

## Summary

Ashen Oath: The Road Between Crowns is a Godot 4.6.3 browser-first dark-fantasy action RPG. The current Web build includes the Greyfen and Wychwood opening, campaign sections, Castle Vargan, river-safe bridge routes, day/night presentation, skeletal characters, and the five-enemy Oathfire encounter.

The project uses The Witcher 3 as an inspiration benchmark for atmosphere, quest clarity, dark-fantasy staging, and authored route design. It is not a finished AAA game, and it does not currently have Witcher-grade art, animation, facial fidelity, terrain, audio, or production QA.

## Project Shape

| Area | Current State |
| --- | --- |
| Source project | `outputs/AshenOathTheRoadBetweenCrowns` |
| Release output | `outputs/AshenOath_Web` |
| Engine | Godot 4.6.3 |
| Renderer | Compatibility / GL Compatibility |
| Main scene | `res://scenes/main.tscn` |
| Main controller | `res://scripts/game.gd` |
| Export preset | `Web Browser` |
| Web output | `../AshenOath_Web/index.html` |
| Release target | Browser/WebGL first, Windows only as an editor/dev fallback |

The Web export is single-threaded and does not require COOP/COEP headers for the current release. The export folder contains the standard Godot files:

- `index.html`
- `index.js`
- `index.wasm`
- `index.pck`
- `index.png`
- `index.audio.worklet.js`
- `index.audio.position.worklet.js`

The current Web `.pck` is large because the export still includes broad runtime asset folders.

## How To Run

From PowerShell:

```powershell
cd "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOath_Web"
& "C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" -m http.server 8787 --bind 127.0.0.1
```

Then open:

```text
http://127.0.0.1:8787/index.html?v=perf1
```

If port `8787` is already running, leave the existing server open and only reload the browser page. Use a cache-busting query string after new exports.

## Playable Flow

The intended first playable flow is:

1. Open Web build.
2. Click the browser launch screen to enable audio and mouse capture.
3. Start a new game from the main menu.
4. Spawn in Greyfen.
5. Speak to Sister Anwen near the shrine.
6. Follow the Wychwood road.
7. Inspect clues along the old road.
8. Fight the first Ghoulkin encounter.
9. Return/update the `Road of Crows` contract.

The broader quest data exists, but the current release target is the first 3-10 minute route, not the full game.

## Implemented Systems

### Startup, Menus, And Input Mode

- Browser launch screen asks for one click before showing the main menu.
- Main menu uses a 1920x1080 responsive UI canvas and supports New Game, Continue, Controls, Settings, Credits/Licenses, and browser-safe Exit Game.
- Pause menu supports resume, save/load, checkpoint load, settings, controls, and main-menu style navigation.
- Settings expose resolution scale, shadows, fullscreen, VSync, mouse and controller sensitivity, controller vibration, invert Y, master volume, and Potato Mode.
- Gameplay captures the mouse.
- Dialogue, inventory, settings, and menus release the mouse pointer so buttons remain clickable.
- Keyboard camera fallback is available with arrow keys.
- `InputRouter` owns semantic actions and active-device detection for keyboard/mouse, Xbox-style gamepads, and future virtual touch controls.
- Menus, dialogue choices, inventory, and minigames establish controller focus and support `A` to accept and `B` to cancel.
- HUD prompts, guidance, equipment shortcuts, and the controls screen update when the active input device changes.
- Gamepad gameplay uses left stick movement, right stick camera, `A` interact, `B` dodge, `Y` jump, `RB` light attack, `RT` heavy attack, `LB` block/parry, `LT` Oathfire, D-pad items/zoom, View inventory, and Menu pause.
- Touch gameplay uses left-thumb movement, right-side camera drag, and
  multi-touch buttons for combat, Oathfire, interaction, items, journal, and
  pause. It is landscape-only and never requests pointer lock.

### Player Controller

Implemented in `scripts/player_controller.gd`.

- WASD movement relative to camera.
- Shift run.
- Space dodge with stamina cost.
- Gravity and ground movement through `CharacterBody3D`.
- Light and heavy attacks.
- Q block/parry window.
- Potion and bomb request signals.
- Health and stamina components.
- Footstep signal.
- Death signal.
- Runtime visual construction with mapped player GLB when available.
- Fallback primitive body if asset spawning fails.
- Sword and hilt visuals retained even when imported GLB body is used.
- Simple procedural movement, attack, hurt, and weapon animation.

### Camera

Implemented in `scripts/camera_controller.gd`.

- Third-person follow camera.
- Mouse look with configurable sensitivity and invert Y.
- Keyboard fallback rotation.
- Camera collision raycast.
- Camera shake for impacts.
- Tuned distance, height, pitch, and FOV for a clearer low-spec third-person frame.

### Combat

Implemented across `scripts/combat_manager.gd`, `scripts/player_controller.gd`, and `scripts/enemy_ai.gd`.

- Player light/heavy attack resolution from measured sword sweeps.
- One authoritative blade-contact event for damage, VFX, audio, camera response, and HUD feedback.
- Bone-attached hilt/tip markers and a matching animated slash trail.
- Oil bonus support by enemy tag.
- Bomb damage in an area around the nearest living enemy.
- Iron trap slow effect.
- Enemy hit feedback, impact signal, and kill signal.
- Hit-stop on impacts.
- Camera shake and hit spark effects.
- Parry/block behavior with weapon-space contact feedback and attacker stagger.
- Enemy windup, pending attack timing, stagger, hit flash, and death handling.

### Enemy AI

Implemented in `scripts/enemy_ai.gd`.

- Enemy definitions load from `data/enemies.json`.
- Supported enemy IDs include Ghoulkin, Bog Wretch, Gravebound Knight, Wychwood Stalker, White Hart Avatar, and Bandit.
- Enemies sense and chase the player within range.
- Enemies leash back to home if pulled too far.
- Attack range and cooldowns are data-driven.
- Windup telegraph and delayed damage resolution.
- Stagger and slow states.
- Death signal and visual death behavior.
- Mapped enemy body support through `AssetSpawnHelper`, with primitive fallback if no asset is available.

### Health And Stamina

Implemented in `scripts/health_component.gd` and `scripts/stamina_component.gd`.

- Health supports configure, damage, heal, save, load, changed signal, and died signal.
- Stamina supports spend, restore, regeneration after delay, save, load, and changed signal.

### Quests

Implemented in `scripts/quest_manager.gd` with content in `data/quests.json`.

Quest state supports:

- Quest definitions.
- Active quests.
- Completed quests.
- Unlocked quests.
- Objective completion.
- Journal/tracker text.
- Rewards and unlock chains.
- Save/load state.

Quest data includes:

| Quest | Type | Current Status |
| --- | --- | --- |
| `main_road_of_crows` | Main | First playable route; primary implemented slice |
| `main_teeth_in_rain` | Main | Data/content present, partial world support |
| `main_blood_under_stone` | Main | Data/content present, ruins are partial/blocked |
| `main_hart_remembers` | Main | Data/content present, ending choices exist |
| `side_widows_bell` | Side | Data/content present, cemetery support partial |
| `side_black_dog` | Side | Data/content present, not fully authored |
| `side_bitter_roots` | Side | Data/content present, not fully authored |

### Dialogue And Interactions

Implemented in `scripts/dialogue_manager.gd`, `scripts/interactable.gd`, `scripts/hud.gd`, and `scripts/game.gd`.

- Dialogue data loads from `data/dialogue.json`.
- Interactable areas use collision volumes and prompts.
- Interaction types include dialogue, clues, herbs, zone gates, and blocked zones.
- Dialogue actions can start quests, complete objectives, grant ingredients, and trigger endings.
- In-world labels are added for most named interactables.
- Ambient NPC idle motion is attached to dialogue NPCs.

Dialogue entries currently include:

- Greyfen Notice Board
- Sister Anwen
- Mira Fen
- Lord Edric Vargan
- Rook
- Widow Elna
- Blacksmith Tor
- Farmer Toma
- The White Hart

### Inventory And Crafting

Implemented in `scripts/inventory_manager.gd` and `scripts/crafting_manager.gd`, with data in `data/items.json`.

Inventory supports:

- Coins.
- Item counts.
- Ingredient counts.
- Quest rewards.
- Crafting checks.
- Item consumption.
- Active oil selection.
- Save/load state.

Craftable/usable items:

| Item | Type | Current Effect |
| --- | --- | --- |
| Redroot Potion | Potion | Restores health |
| Bitterleaf Tonic | Potion | Restores stamina |
| Ash Bomb | Bomb | Damages nearby enemies |
| Moon Oil | Oil | Bonus versus spirit-tagged enemies |
| Rot Oil | Oil | Bonus versus undead-tagged enemies |
| Iron Trap | Trap | Slows nearby enemy |

### Oath Mark Progression

Implemented in `scripts/progression_manager.gd`, `scripts/player_controller.gd`, and `scripts/hud.gd`, with definitions in `data/upgrades.json`.

- Completing a main quest awards one Oath Mark once; side quests and repeat completion do not award marks.
- The journal offers three linear branches with three upgrades each: Blade, Survival, and Oathfire.
- Effects cover blade and heavy damage, parry stamina, maximum health, dodge cost, potion healing, and Oathfire cost, range, and cooldown.
- Unlocks, remaining marks, and rewarded quest IDs persist in saves. Missing legacy data defaults to neutral progression.

### Save, Load, Autosave, And Checkpoint

Implemented in `scripts/save_manager.gd`.

Save files:

- `user://ashen_oath_save.json`
- `user://ashen_oath_autosave.json`
- `user://ashen_oath_checkpoint.json`

Save payload includes:

- Save version.
- Current zone.
- Player position.
- Inventory state.
- Quest state.
- World state.
- Player health.
- Player stamina.
- Oath Mark progression.

Autosave occurs during play on a cooldown and after zone load. Checkpoint is used for death recovery.

### HUD And UI

Implemented in `scripts/hud.gd`.

HUD/UI includes:

- Health bar.
- Stamina bar.
- Enemy health display.
- Interaction prompt.
- Quest tracker.
- Compass/nearest-interactable text.
- Toast messages.
- Launch screen.
- Main menu.
- Pause menu.
- Settings menu.
- Controls menu.
- Credits/licenses menu.
- Dialogue panel.
- Inventory/journal/crafting panel.
- Ending screen.
- Death screen.

The UI is dark-fantasy themed but still code-generated and lightweight.

### Audio

Implemented in `scripts/audio_manager.gd`.

- Procedural/generated event tones and noise.
- Event names include UI, quest, hit, step, reveal, and similar feedback cues.
- Ambient loop generation per zone.
- Master volume setting.
- Recorded SFX variants are preferred when present; transient combat and footstep cues use a small cooldown to avoid stacking.
- Surface-aware footsteps cover road, forest, mud, stone, and wood callers; cemetery, Castle, record hall, undercroft, and Hart ambience have local accents.
- Dialogue, inventory, pause, and death states pause world ambience/music while preserving subtitle-authoritative voice playback.

Current audio is functional feedback with scratch voice performances, not final mastered game audio.

### Visual Direction

Implemented in `scripts/visual_director.gd` and `scripts/game.gd`.

- Zone-specific environment settings.
- Fog color/density.
- Ambient light color.
- Directional sun color/energy.
- Sun disc.
- Cloud planes.
- Sky/background color.
- Tone mapping and contrast/saturation adjustment.
- Zone-specific lighting setups.

The visual benchmark is Witcher-inspired dark fantasy, but current assets and rendering remain low-poly/stylized.

### Web Performance Tiers

Implemented in `scripts/settings_manager.gd`, `scripts/game.gd`, and `scripts/asset_spawn_helper.gd`.

Current Balanced defaults:

- `potato_mode`: false
- `resolution_scale`: 1.0
- `target_fps`: 30
- `shadow_quality`: 0
- `foliage_density`: 1

Balanced also:

- Keeps native 1280x720 rendering while reserving directional shadows for Quality.
- Uses generated mesh LODs and bounded presentation distance for skinned actors.
- Batches repeated cottage, river, terrain, road, tree, and prop geometry.
- Retains authored clouds as one irregular textured card per cluster to limit transparent overdraw.
- Keeps at most one inactive route zone cached and retires older render resources.
- Enforces node, mesh, surface, skeleton, light, transparency, memory, transition, and FPS budgets.

Potato remains an explicit fallback with reduced foliage and visual density. Gameplay objects, routes, interactions, and navigation remain unchanged.

## Scenes And Zones

### `scenes/main.tscn`

The only authored scene file. It instantiates `scripts/game.gd` as the gameplay orchestrator. Runtime services are owned by `RuntimeServiceRegistry`, player/camera construction is owned by `RuntimeActorFactory`, and zone validation/classification plus campaign construction is owned by `ZoneCompositionRouter`. Core builder calls remain explicit for Godot Web compatibility.

### Greyfen

Environment construction is owned by `scripts/zones/greyfen_section.gd`, routed through `ZoneCompositionRouter`; `game.gd` retains lifecycle and gameplay orchestration.

Implemented elements:

- Ground and terrain layers.
- Bounded play area.
- Paved road and side path.
- Path edges and stones.
- Spawn composition.
- Village houses and collision.
- Shrine scene.
- Blacksmith area.
- Authored Greyfen Cemetery and Ruined Crow Chapel quarter, including its grave court, bell frame, Crow Shrine, sealed ossuary, and existing investigation interactions.
- Notice board.
- Sister Anwen, Mira, Rook, Widow Elna, Blacksmith Tor, Farmer Toma.
- Wychwood gate.
- An accessible, navigation-reserved Greyfen road to Castle Vargan; the former collapsed-road obstruction has been removed.
- Props, torches, fences, lanterns, rubble, carts.

In performance mode, many imported environmental assets are replaced/skipped to reduce draw calls.

### Wychwood

Environment construction is owned by `scripts/zones/wychwood_section.gd`, routed through `ZoneCompositionRouter`; `game.gd` retains lifecycle and gameplay orchestration.

Implemented elements:

- Ground and terrain layers.
- Bounded forest corridor.
- Mud road.
- Forest gate staging.
- Wychwood route dressing.
- Monster clearing.
- First Ghoulkin encounter.
- Clues for the main quest.
- Fog and colder lighting.
- Return gate/route support.

### Ruins / Castle Vargan

Built procedurally in `game.gd` by `_build_ruins()`, but not a release-quality area.

Current state:

- Partial/blocked content exists.
- Broader Castle Vargan access is intentionally de-emphasized for the current slice.
- Main route should not depend on this area for the first impression.

## Script Inventory

| Script | Responsibility |
| --- | --- |
| `scripts/game.gd` | Main gameplay orchestration, interaction routing, quest flow, combat hooks, save hooks, runtime environment, and fall recovery |
| `scripts/input_router.gd` | Semantic keyboard/mouse, gamepad, and virtual-input routing; active-device prompts, controller settings, and rumble |
| `scripts/runtime_service_registry.gd` | Owns and configures the seventeen runtime manager, UI, input, touch, content, audio, and world services |
| `scripts/mobile_touch_controls.gd` | Responsive landscape touch overlay, multi-touch action dispatch, camera/movement pads, and portrait guidance |
| `scripts/runtime_actor_factory.gd` | Creates and connects the active player and third-person camera pair |
| `scripts/zone_composition_router.gd` | Validates zone IDs and routes construction to directly preloaded core or campaign builders |
| `scripts/zone_build_context.gd` | Typed public construction boundary and result validation for campaign zones |
| `scripts/player_controller.gd` | Player movement, combat input, health/stamina composition, parry/block, dodge, visuals, procedural animation |
| `scripts/camera_controller.gd` | Third-person camera, mouse/keyboard look, camera collision, shake, sensitivity/invert settings |
| `scripts/enemy_ai.gd` | Enemy setup, chase/attack AI, leash, windup, stagger, slow, death, visuals |
| `scripts/combat_manager.gd` | Player attack resolution, bomb/trap logic, hit/impact/kill signals |
| `scripts/health_component.gd` | Health, damage, heal, death, save/load |
| `scripts/stamina_component.gd` | Stamina spend/restore/regeneration, save/load |
| `scripts/hud.gd` | All HUD, menus, dialogue, inventory, crafting UI, ending/death screens |
| `scripts/quest_manager.gd` | Quest definitions, active/completed/unlocked state, objective progression, tracker/journal, save/load |
| `scripts/progression_manager.gd` | Nine-upgrade definitions, main-quest Oath Mark rewards, prerequisites, effects, and save/load |
| `scripts/dialogue_manager.gd` | Loads dialogue JSON and returns dialogue entries |
| `scripts/inventory_manager.gd` | Items, ingredients, coin, rewards, crafting/consume helpers, active oil, save/load |
| `scripts/crafting_manager.gd` | Craft request handling against inventory and item recipes |
| `scripts/save_manager.gd` | Save, load, autosave, checkpoint |
| `scripts/settings_manager.gd` | Runtime settings, Potato Mode, render scale, FPS cap, VSync, fullscreen, sensitivity, audio volume |
| `scripts/audio_manager.gd` | Procedural audio events and ambient loops |
| `scripts/interactable.gd` | Area-based interactables with prompt/type/quest/zone metadata |
| `scripts/npc_ambient.gd` | Simple idle bob/turn ambient motion for NPCs |
| `scripts/visual_director.gd` | Zone environment, fog, sky, sun disc, cloud planes, lighting palette |
| `scripts/asset_database.gd` | Loads asset manifest, role mapping, visual upgrade manifest |
| `scripts/asset_spawn_helper.gd` | Spawns mapped assets, loads/caches resources, parses OBJ, normalizes bounds, wraps characters, creates placeholders |

## Data Files

| File | Purpose |
| --- | --- |
| `data/quests.json` | Main/side quest definitions, objectives, rewards, unlocks |
| `data/dialogue.json` | NPC and interactable dialogue text/actions |
| `data/items.json` | Item definitions, recipes, icons, effects |
| `data/enemies.json` | Enemy stats, tags, weakness labels, colors |
| `data/upgrades.json` | Blade, Survival, and Oathfire upgrade definitions and effects |
| `asset_sources.json` | Asset-pack source URLs/categories/licenses |
| `asset_manifest.json` | Scanned asset inventory |
| `asset_role_mapping_suggested.json` | Suggested/current role-to-asset mapping |
| `visual_upgrade_manifest.json` | Human visual upgrade roles and status |

## Asset Pipeline

The asset pipeline lives in `tools/` and manages downloads, extraction, scanning, and role mapping.

### Pipeline Components

| Tool | Purpose |
| --- | --- |
| `tools/download_assets.py` | Downloads assets from configured sources, resolves direct and page URLs, extracts supported archives, organizes files |
| `tools/scan_assets.py` | Scans `assets_external/` and writes `asset_manifest.json` |
| `tools/suggest_asset_mapping.py` | Suggests role mappings into `asset_role_mapping_suggested.json` |
| `tools/create_placeholders_if_missing.py` | Marks missing roles with placeholder requirements |
| `tools/pipeline_common.py` | Shared pipeline helpers |
| `tools/README_ASSET_PIPELINE.md` | Pipeline usage and supported URL documentation |

### Downloader URL Support

The downloader supports:

- Direct archive links such as `.zip`, `.7z`, and `.rar`.
- Direct model, texture, and audio file links supported by the pipeline.
- HTTP redirects.
- Session cookies for simple cookie-setting sites.
- `Content-Disposition` filenames.
- `HEAD` checks with ranged `GET` fallback.
- GitHub archive redirects.
- GitHub release pages including `/releases/latest` and `/releases/tag/<tag>`.
- HTML asset pages that expose ordinary download links, including OpenGameArt-style `/sites/default/files/` links.
- `--dry-run` and `--verbose`.

Unsupported or limited:

- Login-only downloads.
- Paywalled downloads.
- Captcha-protected downloads.
- JavaScript-only download buttons.
- Pages with multiple ambiguous valid downloads.
- Automatic extraction for non-ZIP archives.

### Current Manifest Counts

| Category | Count |
| --- | ---: |
| models | 2304 |
| characters | 48 |
| enemies | 18 |
| environment | 1082 |
| animations | 43 |
| textures | 802 |
| audio | 102 |
| ui | 520 |
| licenses | 20 |

### Asset Folder Shape

`assets_external/` contains organized runtime assets and raw/downloaded sources:

- `downloads/`
- `raw/`
- `characters/`
- `enemies/`
- `environment/`
- `animations/`
- `audio/`
- `ui/`
- `licenses/`

The raw/download folders should not be treated as polished runtime content.

### Runtime Asset Integration

`AssetDatabase` loads:

- `asset_manifest.json`
- `asset_role_mapping_suggested.json`
- `visual_upgrade_manifest.json`

`AssetSpawnHelper`:

- Spawns visual roles by role name.
- Loads and caches `PackedScene`, `Mesh`, GLB/GLTF, and OBJ resources.
- Parses OBJ meshes when needed.
- Normalizes imported scene bounds.
- Applies rough fallback category materials.
- Applies mesh-native identity materials to valid skeletal bodies and removes forbidden proxy anatomy.
- Creates primitive placeholders if mapped assets are missing.

## Current Visual Asset Status

Major current human roles use low-poly Poly Pizza / Quaternius CC0 GLB bases:

| Role | Current Source | Status |
| --- | --- | --- |
| `player_human` | Adventurer GLB | Temporary stylized base with mesh-native Kael palette |
| `sister_anwen_human` | Animated Woman GLB | Temporary stylized base with distinct Anwen palette |
| `mira_human` | Woman Casual GLB | Temporary stylized base with deterministic role palette |
| `rook_human` | Hooded Adventurer GLB | Temporary stylized base with deterministic role palette |
| `villager_human` | Animated Human GLB | Temporary base with deterministic crowd variation |

These are legal and browser-friendly, but they are not high-fidelity human characters. They do not have AAA faces, facial expressions, bespoke clothing rigs, or final animation retargeting.

## Web Export

The active export preset is `Web Browser` in `export_presets.cfg`.

Important settings:

- Platform: Web.
- Export filter: selected resources plus include filters.
- Main scene selected.
- Runtime scripts explicitly selected to avoid missing-preload failures.
- Compatibility renderer.
- Thread support off.
- PWA off.
- Output path: `../AshenOath_Web/index.html`.

The export includes JSON, runtime scripts, selected imported assets, audio, UI, and required Godot support files. It excludes tools, raw downloads, screenshot folders, `.blend` files, and preview files.

## Verification And Test Tools

| Tool | Purpose |
| --- | --- |
| `tools/verify_runtime.gd` | Headless runtime verifier for web-only release shape, Greyfen/Wychwood load, dialogue mouse release, blocked gate, enemies, placeholders, fall recovery |
| `tools/verify_combat_001.gd` | Verifies measured blade sweeps, misses, one-contact attacks, parry contact, and attacker stagger |
| `tools/capture_slice_screenshots.gd` | Captures spawn, village center, forest gate, forest trail, and combat clearing; checks nonblank/collision-safe captures; writes originals to `verification_screenshots/` and mirrors future captures into `Development_Gallery/screenshots/` |
| `tools/verify_web_export.py` | Enforces the exact runtime file shape, hashes, and 100 MB payload ceiling |
| `tools/verify_web_001.py` | Audits the Web preset, renderer, export filters, build ID, and hosting headers |
| `tools/verify_web_browser.mjs` | Drives Chrome and Edge through launch, menu, and New Game via DevTools |
| `Export_Web_Build.bat` | Runs Godot Web export and web export verification |
| `Serve_Web_Build.bat` | Serves the web build locally for browser smoke testing |

Common commands:

```powershell
& "C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe" --headless --path "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns" --script res://tools/verify_runtime.gd
```

```powershell
& "C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe" --path "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns" --script res://tools/capture_slice_screenshots.gd
```

Development screenshots are collected in:

- `Development_Gallery/screenshots/`
- `Development_Gallery/index.html`
- `Development_Gallery/SCREENSHOT_TIMELINE.md`

Open `Development_Gallery/index.html` directly in a browser to review the gallery. Originals should remain in their source folders.

```powershell
cd "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns"
cmd /c Export_Web_Build.bat
```

```powershell
& "C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" tools\verify_web_export.py "..\AshenOath_Web"
```

Known verifier note: Godot headless may emit ObjectDB cleanup warnings after passing. Treat assertion failures as hard failures; cleanup warnings still need future investigation but have not blocked the current slice.

## Known Bugs And Limitations

- PERF-001 passes its targeted runtime, world, river, zone-budget, and graphical native-720p gates; its development Web preview is recorded in `PERF_001_ENFORCED_WEB_BUDGETS.md`.
- Fresh RECOVERY-002 screenshots are stored in `Development_Gallery/screenshots/`.
- Godot still emits renderer/resource diagnostics while verifier scenes are destroyed. Active rendered surfaces pass `verify_zone_budgets.gd`; shutdown diagnostics remain technical debt.

- Visual quality is still low-poly/stylized and well below The Witcher 3.
- Gameplay renders at native 1280x720 and 1.0 3D scale. This avoids a severe Intel HD 620/ANGLE slowdown caused by Godot's fractional viewport scaler; browser UI remains responsive to the host canvas.
- Outdoor day/night presentation includes readable cool-toned moonlight, procedural batched stars, visible sun and moon bodies, soft celestial halos, and quality-tier drifting cloud volumes.
- Human models are skeletal, textured, lit, and animated but still lack realistic faces, hands, hair, facial rigs, and bespoke clothing.
- CHAR-001 improves immediate identity and removes proxy anatomy, but the underlying Poly Pizza humans and skeletal Ghoulkin remain low-poly temporary assets rather than final character art.
- Main-route character and Wychwood enemy skeletons animate; broader animation retargeting and facial performance remain incomplete.
- The full campaign route is now playable through Deep Wood, mill, farmstead, marsh, bandit road, Castle Vargan, undercroft, assembly, and Hart Glade; visual fidelity remains deliberately stylized and uneven.
- Castle Vargan is playable and verified with an authored approach, courtyard, and Record Hall, but its modular architecture remains below the final art target.
- Five side quests have authored world interactions and consequences; the remaining five stay data-backed for a later content pass.
- Audio is generated/procedural feedback, not mastered final game audio.
- UI is functional and themed but not final AAA-grade presentation.
- Browser support has verified Chrome and Edge desktop plus Chrome/Edge mobile
  emulation. Firefox, Safari, and real mobile hardware remain incompletely
  validated.
- The slim Web export explicitly packages selected runtime assets and is checked against a 100 MB ceiling.
- The project uses runtime-authored zone sections rather than a large studio-grade scene hierarchy. ENGINE-001 establishes explicit ownership boundaries, while some low-level authored helpers remain in `game.gd`.
- Asset licenses are mostly permissive/CC0, but public release should still include license/credit review from `assets_external/licenses/`.
- WebGL performance on the Dell 7280 is sensitive to draw calls, imported GLBs, transparency, lights, and resolution scale.

## Next Steps

### Short Term

- Preserve the sub-900 ms cold-transition and sub-350 ms warm-transition budgets as later systems change.
- Preserve WEB-001's Chrome/Edge canvas, console, runtime-heap, and New Game
  checks as browser-facing systems change.
- Run physical Android phone performance, thermal, battery, safe-area, and
  multi-touch usability tests before approving native mobile production.
- Produce bespoke realistic human assets as a separate licensed asset-production milestone.

### Medium Term

- Replace current temporary human bases with better licensed rigged GLB characters.
- Replace Ghoulkin/Bog Wretch with stronger monster models and death bodies.
- Integrate animation retargeting for idle, walk, attack, hit, death, and dialogue gestures.
- Author terrain materials for road, mud, grass, stone, wood, and plaster.
- Improve UI styling, spacing, and icon use.
- Replace generated audio with licensed/recorded ambience, combat hits, footsteps, UI, and music.
- Extend the enforced zone budgets when newly released areas are authored.
- Continue extracting stable authored helpers from `game.gd` behind the ENGINE-001 composition interfaces as focused tickets.

### Long Term

- Refine already-open campaign areas one at a time rather than adding more geographic breadth.
- Require each new area to meet the same bar as the vertical slice: bounded play space, clear route, stable collision, no void, no placeholder major actors, and browser performance checks.
- Build a real production asset list for characters, monsters, animation, terrain, VFX, audio, UI, and narrative scenes.
- Add real QA passes for browser compatibility, saves, progression, combat balance, input mode switching, and deployment.
- Keep the benchmark as Witcher-inspired dark fantasy, but make every milestone honest about what is actually achieved.

## Current Acceptance State

The project currently satisfies:

- Web build launches past Godot splash.
- Browser launch screen works.
- Main menu works.
- New Game reaches Greyfen.
- Runtime verifier passes.
- Screenshot capture passes.
- Web export verifier passes.
- First route is playable with a 1080p interface and a 720p Balanced 3D rendering budget.
- PERF-REPAIR-001’s strict Dell-class native-720p gate measured Greyfen at 46.73 FPS average / 30.25 FPS 1% low, Wychwood at 60.00 / 47.08, Wychwood combat at 57.83 / 38.27, Castle Courtyard at 60.00 / 56.05, Record Hall at 59.99 / 52.61, and Hart Glade at 60.01 / 54.22. Warm return measured 318.7 ms; all cold transitions remained below 458 ms. The full report is `.release-gate/perf_001_report.json`.
- PBR terrain/building surfaces, saved day/night time, cleaned skeletal characters, and mixed Wychwood enemy rigs are active.

The project does not yet satisfy:

- AAA visual fidelity.
- Finished full-game scope.
- Photoreal or high-fidelity humans.
- Full facial animation and studio-quality combat motion capture.
- All ten side quests at the same authored standard; five currently meet it.
- Small optimized final Web payload.
- Broad browser/device QA.

## Milestone C Campaign State

- `WORLD-004` through `WORLD-006` provide dedicated bounded builders for the complete campaign route.
- `QUEST-003` through `QUEST-006` implement Ash and Banner, Blood Under Stone, The Hart Remembers, and consequence-driven epilogues.
- `BOSS-001` preserves Witness/Mercy noncombat resolutions and adds a three-phase White Hart encounter for Duty/Ash.
- `SIDE-001` authors five consequential village stories and removes the instant-completion shortcut.
- `QA-004` exhaustively validates 17,496 major-choice combinations and save-stable epilogue resolution.
# RELEASE-001 Web Version 1.0 Candidate

The complete current Web campaign passed the authoritative release suite. Its seven-file export is 65.59 MB with a 29.30 MB PCK. Chrome and Edge completed the released route from Greyfen to Hart Glade without browser console or network errors. Native-720p Balanced profiling measured approximately 60 FPS average in every required zone; the lowest 1% low was 47.17 FPS during Wychwood combat. Android, iOS, and store distribution remain deferred.
