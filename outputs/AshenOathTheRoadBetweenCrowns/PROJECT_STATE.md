# Ashen Oath Project State

Last updated: 2026-06-21

## Summary

Ashen Oath: The Road Between Crowns is a Godot 4.6.3 browser-first dark-fantasy action RPG vertical slice. The current build is a playable low-spec Web slice focused on Greyfen village, the Wychwood road, and the first Ghoulkin encounter.

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
- Main menu supports New Game, Continue, Controls, Credits/Licenses, and Quit.
- Pause menu supports resume, save/load, checkpoint load, settings, controls, and main-menu style navigation.
- Settings expose resolution scale, shadows, fullscreen, VSync, mouse sensitivity, invert Y, master volume, and Potato Mode.
- Gameplay captures the mouse.
- Dialogue, inventory, settings, and menus release the mouse pointer so buttons remain clickable.
- Keyboard camera fallback is available with arrow keys.

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

- Player light/heavy attack resolution.
- Attack radius and damage values.
- Oil bonus support by enemy tag.
- Bomb damage in an area around the nearest living enemy.
- Iron trap slow effect.
- Enemy hit feedback, impact signal, and kill signal.
- Hit-stop on impacts.
- Camera shake and hit spark effects.
- Parry/block behavior.
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

Current audio is functional feedback, not final mastered game audio.

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

### Web Performance Mode

Implemented in `scripts/settings_manager.gd`, `scripts/game.gd`, and `scripts/asset_spawn_helper.gd`.

Current default performance settings:

- `potato_mode`: true
- `resolution_scale`: 0.55
- `target_fps`: 30
- `shadow_quality`: 0
- `foliage_density`: 0

Performance mode also:

- Disables dynamic shadows.
- Disables grass batches.
- Skips many imported environment GLB/OBJ role visuals.
- Reduces fog-sheet spawning.
- Keeps only selected lights.
- Turns imported mesh shadow casting off.

This improves browser smoothness on low-end hardware but makes the world visually sparser.

## Scenes And Zones

### `scenes/main.tscn`

The only authored scene file. It instantiates `scripts/game.gd`, which creates managers, UI, player, camera, zones, enemies, interactables, and environment elements at runtime.

### Greyfen

Built procedurally in `game.gd` by `_build_greyfen()`.

Implemented elements:

- Ground and terrain layers.
- Bounded play area.
- Paved road and side path.
- Path edges and stones.
- Spawn composition.
- Village houses and collision.
- Shrine scene.
- Blacksmith area.
- Cemetery area.
- Notice board.
- Sister Anwen, Mira, Rook, Widow Elna, Blacksmith Tor, Farmer Toma.
- Wychwood gate.
- Blocked ruins/castle gate.
- Props, torches, fences, lanterns, rubble, carts.

In performance mode, many imported environmental assets are replaced/skipped to reduce draw calls.

### Wychwood

Built procedurally in `game.gd` by `_build_wychwood()`.

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
| `scripts/game.gd` | Main orchestration, zone building, managers, interaction routing, quest flow, combat hooks, save hooks, runtime environment, input map, fall recovery |
| `scripts/player_controller.gd` | Player movement, combat input, health/stamina composition, parry/block, dodge, visuals, procedural animation |
| `scripts/camera_controller.gd` | Third-person camera, mouse/keyboard look, camera collision, shake, sensitivity/invert settings |
| `scripts/enemy_ai.gd` | Enemy setup, chase/attack AI, leash, windup, stagger, slow, death, visuals |
| `scripts/combat_manager.gd` | Player attack resolution, bomb/trap logic, hit/impact/kill signals |
| `scripts/health_component.gd` | Health, damage, heal, death, save/load |
| `scripts/stamina_component.gd` | Stamina spend/restore/regeneration, save/load |
| `scripts/hud.gd` | All HUD, menus, dialogue, inventory, crafting UI, ending/death screens |
| `scripts/quest_manager.gd` | Quest definitions, active/completed/unlocked state, objective progression, tracker/journal, save/load |
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
- Adds runtime wrappers to character bases: cloak, face markers, hair/hood, belt, shoulder overlays, staff/dagger.
- Creates primitive placeholders if mapped assets are missing.

## Current Visual Asset Status

Major current human roles use low-poly Poly Pizza / Quaternius CC0 GLB bases:

| Role | Current Source | Status |
| --- | --- | --- |
| `player_human` | Adventurer GLB | Temporary stylized base with runtime wrapper |
| `sister_anwen_human` | Animated Woman GLB | Temporary stylized base with hood/staff/priestess styling |
| `mira_human` | Woman Casual GLB | Temporary stylized base with herbalist styling |
| `rook_human` | Hooded Adventurer GLB | Temporary stylized base with rogue/dagger styling |
| `villager_human` | Animated Human GLB | Temporary generic human base |

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
| `tools/capture_slice_screenshots.gd` | Captures spawn, village center, forest gate, forest trail, and combat clearing; checks nonblank/collision-safe captures; writes originals to `verification_screenshots/` and mirrors future captures into `Development_Gallery/screenshots/` |
| `tools/verify_web_export.py` | Checks Web export folder and required Godot output files |
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

- Visual quality is still low-poly/stylized and well below The Witcher 3.
- Performance mode makes the browser build smoother but reduces scenery density and removes grass.
- Human models still lack high-fidelity faces, hands, hair, facial rigs, clothing layers, and final silhouettes.
- Character and enemy animation is mostly procedural; the downloaded animation libraries are not fully retargeted into controllers.
- Major areas beyond the first route are partial, blocked, or data-only.
- Castle Vargan/Ruins should not be treated as release-ready.
- Side quests are represented in data but not all have fully authored gameplay spaces.
- Audio is generated/procedural feedback, not mastered final game audio.
- UI is functional and themed but not final AAA-grade presentation.
- Browser support has focused on Chrome/Edge/Firefox desktop; Safari and mobile are experimental.
- The Web export remains large because the include filters still package many assets.
- The project is not currently organized as a large studio-grade scene hierarchy; much of the world is built procedurally in `game.gd`.
- Asset licenses are mostly permissive/CC0, but public release should still include license/credit review from `assets_external/licenses/`.
- WebGL performance on the Dell 7280 is sensitive to draw calls, imported GLBs, transparency, lights, and resolution scale.

## Next Steps

### Short Term

- Add an on-screen FPS/performance readout for browser testing.
- Add explicit quality presets instead of using Potato Mode as the default-only path.
- Reduce Web export size by narrowing runtime asset include filters.
- Profile load time and runtime frame pacing in Chrome and Edge.
- Restore some visual density with cheaper batched/procedural geometry instead of many GLB instances.
- Improve Greyfen/Wychwood composition without reintroducing stutter.
- Make screenshot regression compare performance and quality presets separately.

### Medium Term

- Replace current temporary human bases with better licensed rigged GLB characters.
- Replace Ghoulkin/Bog Wretch with stronger monster models and death bodies.
- Integrate animation retargeting for idle, walk, attack, hit, death, and dialogue gestures.
- Author terrain materials for road, mud, grass, stone, wood, and plaster.
- Improve UI styling, spacing, and icon use.
- Replace generated audio with licensed/recorded ambience, combat hits, footsteps, UI, and music.
- Add collision/performance budgets per zone.
- Split world authoring into smaller scene or resource modules if `game.gd` continues to grow.

### Long Term

- Reopen/expand areas one at a time: cemetery micro-quest, deeper Wychwood, then Castle Vargan.
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
- First route is playable in a low-spec browser configuration.

The project does not yet satisfy:

- AAA visual fidelity.
- Finished full-game scope.
- High-fidelity humans.
- Fully animated combat/NPCs.
- Fully authored side quests and later main quests.
- Small optimized final Web payload.
- Broad browser/device QA.
