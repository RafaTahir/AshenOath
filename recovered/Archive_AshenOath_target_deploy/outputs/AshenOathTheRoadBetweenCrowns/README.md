# Ashen Oath: The Road Between Crowns

Playable Godot 4.6 dark fantasy action RPG vertical slice built as a Web-first release. The benchmark is Witcher 3-style dark fantasy staging and quest readability, constrained to a browser-playable Godot slice.

## Open And Run

1. Install Godot 4.x.
2. Open Godot Project Manager.
3. Choose Import.
4. Select this folder: `AshenOathTheRoadBetweenCrowns`.
5. Open the project and press Play.

The main scene is `res://scenes/main.tscn`.

On this machine you can also run `Run_Ashen_Oath_Godot_4_6.bat` from this folder.

The browser build is the only release output. Rebuild it with `Export_Web_Build.bat` or the editor export preset named `Web Browser`. The output folder is `../AshenOath_Web`; upload the contents of that folder to a static host. See `WEB_DEPLOY.md`.

To test the browser build locally after exporting, run `Serve_Web_Build.bat` and open `http://127.0.0.1:8080`.

## Controls

- WASD: move
- Mouse: camera
- Arrow keys: camera fallback
- Shift: run
- Space: dodge
- Left mouse: light attack
- Right mouse: heavy attack
- Q: block
- E: interact
- R: use Redroot Potion
- F: throw Ash Bomb
- Tab: inventory, journal, crafting
- Esc: pause/settings

## Browser Build Notes

The first screen asks for one click before the main menu. That click enables browser audio and gives Godot permission to capture the mouse during gameplay. Dialogue, inventory, settings, and menus release the pointer again so buttons can be clicked normally.

## Playable Flow

Start in Greyfen Village, speak to Sister Anwen, follow the lanterned Wychwood road, investigate the forest clues, fight the first Ghoulkin encounter, and return/update the contract objective. Broader quest content remains present in data, but the release target is the first playable route.

## Current Recovery Pass

- Greyfen and Wychwood now prioritize one authored first-route slice with mapped kit assets, layered terrain patches, road shoulders, path stones, grass tufts, shrine staging, forest gate lighting, fog sheets, and stronger monster-clearing composition.
- Player, NPC, and enemy silhouettes use mapped kit assets where available, with simple staging and readable labels.
- Inventory items can be crafted and used: Redroot heals, Bitterleaf restores stamina, Ash Bomb damages nearby enemies, Moon Oil and Rot Oil apply blade bonuses, and Iron Trap slows enemies.
- The HUD, splash screen, controls screen, menus, dialogue, journal, crafting, and ending screens have a consistent dark-fantasy visual treatment.
- Procedural animation, hit flashes, camera shake, hit-stop, generated audio cues, ambient loops, and in-world labels improve combat and exploration feel.
- Combat now includes timed enemy windups, parry windows, stagger response, target-facing attacks, boss combat branches, and clearer feedback.
- Save/load now includes autosave, checkpoint saves, death checkpoint loading, versioned save payloads, and persistent removed clues/herbs.
- Side quests remain represented in data, but unfinished areas should not define the first impression.
- Quest rewards now grant actual coin/items from quest data.
- Inventory items have replaceable SVG icon assets and JSON icon metadata.
- The project has been smoke-tested with Godot 4.6.3 using headless scene startup, an automated flow test, and web export output verification.

## Production Limits

This build is intentionally lightweight enough for browser play on low-end hardware. The standard is Witcher 3 as a direction benchmark for staging, density, atmosphere, and quest clarity, but true AAA production still requires authored meshes, skeletal animation, bespoke audio, and a long QA pass. The project should keep replacing generated pieces with authored assets.

## Placeholder Content

All art remains low-poly and lightweight, but major first-slice characters/enemies now use mapped kit assets where available. The code is structured so models, icons, sounds, animation, and authored scenes can keep replacing generated primitives over time.

## Low-Spec Notes

The project uses small hub zones, limited enemies, simple AI, compatibility rendering, fog, low draw complexity, and a settings menu with Potato Mode.
