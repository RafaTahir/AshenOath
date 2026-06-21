# Phase 1G Character And Monster Fidelity

## Summary

Phase 1G upgrades the character and first-monster presentation for the existing first route only: player, Sister Anwen, nearby Greyfen NPCs, and the first Ghoulkin encounter. It does not add quests, zones, maps, new systems, or external downloads.

The pass uses existing assets already in the project and pushes them with better mappings, stronger silhouettes, darker materials, cheap role overlays, contact shadows, and clearer monster read. This is still low-poly/stylized and not AAA character art.

## Files Changed

| File | Change |
| --- | --- |
| `scripts/character_presentation.gd` | Added stronger Phase 1G overlays for player, Sister Anwen, villagers, and Ghoulkin; added Quality-only detail checks. |
| `scripts/game.gd` | Named the settings manager so presentation code can detect Potato Mode. |
| `asset_role_mapping_suggested.json` | Remapped first-route story roles to existing Quaternius fantasy OBJ assets where stronger than the previous generic GLBs. |
| `visual_upgrade_manifest.json` | Updated visual-role source paths/status notes for the Phase 1G character base swaps. |
| `tools/verify_runtime.gd` | Added assertions for Phase 1G player, Sister Anwen, and Ghoulkin presentation markers. |
| `PHASE_1G_CHARACTER_MONSTER_FIDELITY.md` | This checkpoint report. |

## Assets Inspected

- `asset_manifest.json`
- `asset_role_mapping_suggested.json`
- `visual_upgrade_manifest.json`
- Existing runtime character assets in `assets_external/characters`
- Existing runtime enemy assets in `assets_external/enemies`

Useful available assets already inside the project:

- `Warrior.obj` / `Warrior_Texture.png`
- `Cleric.obj` / `Cleric_Texture.png`
- `Rogue.obj` / `Rogue_Texture.png`
- `Monk.obj` / `Monk_Texture.png`
- `Skeleton.obj`
- Existing Poly Pizza / Quaternius GLB humans remain available as fallback/alternate assets.

No new assets were downloaded.

## Asset Mappings Changed

| Role | Old Direction | New Direction |
| --- | --- | --- |
| `player_kael` / `player_human` | Generic adventurer GLB | Existing Quaternius `Warrior.obj` fantasy base |
| `sister_anwen` / `sister_anwen_human` | Generic animated woman GLB | Existing Quaternius `Cleric.obj` base |
| `rook_smuggler` / `rook_human` | Hooded adventurer GLB | Existing Quaternius `Rogue.obj` base |
| `widow_elna` | Generic animated woman GLB | Existing Quaternius `Monk.obj` robed base |
| `generic_villager_01` / `villager_human` | Generic animated human GLB | Existing Quaternius `Monk.obj` robed base |

Mira remains on the existing `WomanCasual_PolyPizza_Quaternius_CC0.glb` because it still reads better for a herbalist than the available fantasy bases.

Ghoulkin remains mapped to `Skeleton.obj`, but its runtime presentation is now significantly stronger.

## Player Upgrades

- Swapped visual role to the existing textured Warrior OBJ.
- Added darker split cloak silhouette.
- Added leather harness straps.
- Added armor chest plate.
- Added stronger belt, boots, gloves, shoulders, hood/hair read, and scabbard.
- Kept sword and hilt visuals intact.
- Added Quality-only extra fur collar, gloves, and armor plate details.
- Preserved contact shadow/grounding.

## Sister Anwen Upgrades

- Swapped visual role to the existing textured Cleric OBJ.
- Added wider robe fall panels.
- Added gold stole, prayer cord, staff cap, hood/head read, and shrine amulet.
- Kept calm shrine-facing NPC behavior from earlier phases.
- Preserved contact shadow and dialogue staging.

## Villager / NPC Upgrades

- Rook now uses the existing Rogue OBJ base with dark cloak/dagger presentation.
- Widow/villager visuals now favor the robed Monk OBJ base where appropriate.
- Villagers receive role-specific overlays:
  - Blacksmith apron/glove.
  - Farmer sash.
  - Widow mourning veil.
  - Belts, cloth layers, face/hair markers.
- No extra distant NPCs were added.

## Ghoulkin Upgrades

- Kept the existing Skeleton OBJ mapping for Web safety.
- Added hunched-back read, long arms, claws, glowing eye markers, rib read, and rot stain.
- Preserved existing windup/stagger/death combat behavior.
- Added verifier checks for long-arm and eye overlays.
- Kept the monster readable in the Wychwood clearing instead of hiding it in fog.

## Material / Animation / Grounding Improvements

- Materials are darker, rougher, and more cloth/leather/metal separated through simple `StandardMaterial3D` colors.
- Ghoulkin eyes use small emissive markers only; no expensive shader or particle system was added.
- Existing procedural idle/walk/attack/windup/stagger/death behavior is preserved.
- Contact shadows remain fake geometry, which works in Web and Potato Mode.

## Quality Mode vs Potato Mode

Quality Mode:

- Uses the richer Phase 1G optional details where `Potato Mode` is off.
- Adds player fur collar/glove/armor extras.
- Adds Sister Anwen amulet detail.
- Adds Ghoulkin rib/rot extras.

Potato Mode:

- Keeps the core silhouette changes.
- Skips optional Quality-only extras.
- Avoids new lights, particles, transparency, or heavy shaders.

## Performance Precautions

- No new downloads.
- No particles.
- No dynamic shadows.
- No skeletal retargeting.
- No new combat or UI systems.
- New detail nodes are small primitive meshes.
- Web export remains the single release output.

## Screenshot Paths

Screenshots are in:

`C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns\verification_screenshots`

Fresh Phase 1G screenshots include:

- `01_greyfen_spawn.png`
- `02_village_center.png`
- `03_shrine_sister_anwen.png`
- `04_sister_anwen_dialogue.png`
- `09_combat_clearing.png`
- `10_ghoulkin_windup_hud.png`
- `12_ghoulkin_death_read.png`
- `13_ghoulkin_victory_objective.png`

## Verification Commands Run

```powershell
& 'C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --script res://tools/verify_runtime.gd
```

Result: passed. Output: `runtime vertical slice verification complete`.

```powershell
& 'C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe' --path . --script res://tools/capture_slice_screenshots.gd
```

Result: passed. Output: `slice screenshots saved ...`. The known Intel/ANGLE warning appeared.

```powershell
cmd /c Export_Web_Build.bat
```

Result: passed. Output included `web export verified: 7 files, 261.0 MB`.

```powershell
& 'C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' tools\verify_web_export.py '..\AshenOath_Web'
```

Result: passed. Output: `web export verified: 7 files, 261.0 MB`.

## Test Results

| Check | Result |
| --- | --- |
| New Game starts in Greyfen | Passed via runtime verifier |
| Sister Anwen exists/interacts | Passed via runtime verifier |
| Dialogue mouse release still works | Passed via runtime verifier |
| Wychwood route loads | Passed via runtime verifier |
| First Ghoulkin encounter spawns | Passed via runtime verifier |
| Ghoulkin windup/HUD still works | Passed via runtime verifier |
| Quest flow from Phase 1E preserved | Passed via runtime verifier |
| Screenshot capture | Passed |
| Web export verifier | Passed |

## Known Remaining Visual Weaknesses

- Characters are still low-poly and stylized; they are not high-fidelity Witcher-quality humans.
- No real facial animation, lip sync, fingers, cloth simulation, or cinematic animation clips.
- Sister Anwen's label/name can still visually clutter the shrine screenshot.
- The player and NPC overlays are still primitive-based and can look blocky up close.
- Ghoulkin is more readable and threatening, but still built from a skeleton asset plus overlays rather than a bespoke monster model.
- Web export remains large at about 261 MB.

## Recommended Phase 1H Prompt

Implement Phase 1H: first-route camera and label composition polish. Keep the same route and systems, but reduce shrine label clutter, improve third-person camera framing around Sister Anwen and the Ghoulkin clearing, validate Quality/Potato screenshots side by side, and preserve all Phase 1D-1G gameplay, quest, HUD, visual, and Web export behavior.
