# Phase 1C: First Combat Readability

## Summary

Phase 1C improves the first Wychwood Ghoulkin encounter from "enemy exists in the clearing" toward a more readable combat beat. The pass focuses on telegraphs, block/parry feedback, hit confirmation, death readability, authored encounter staging, and verification coverage.

This is still a low-end web vertical slice. It does not add new quests, zones, enemies, high-fidelity animation retargeting, or AAA character assets. The goal of this pass is clearer combat feel and more honest testing.

## Files Changed

| File | Purpose |
| --- | --- |
| `scripts/combat_feedback.gd` | New lightweight VFX helper for impact bursts, block flashes, parry rings, and windup markers. |
| `scripts/enemy_ai.gd` | Adds windup/attack signals, clearer Ghoulkin attack timing, recovery windows, visible warning markers, stronger stagger/death poses, and readable tint changes. |
| `scripts/player_controller.gd` | Emits block and hurt signals, improves parry/block/hurt flash timing, and preserves combat return values. |
| `scripts/audio_manager.gd` | Adds procedural sounds for enemy windup, block, parry, stagger, and death. |
| `scripts/game.gd` | Wires combat feedback into player/enemy events, adds camera shake/audio/VFX, and adds collisionless readability dressing in the combat clearing. |
| `tools/verify_runtime.gd` | Adds strict checks for first-combat readability dressing and windup warning marker creation. |
| `tools/capture_slice_screenshots.gd` | Adds screenshot captures for Ghoulkin windup, player block moment, and Ghoulkin death readability. |

## Encounter Staging

- Added `FirstCombatReadabilityDressing` to the monster clearing.
- Added non-colliding visual markers for the fight center, combat lane edges, safe footing stone, and boundary roots.
- Kept the combat dressing primitive and cheap so it does not add import, asset, or browser performance risk.
- Avoided new collision clutter in the player-facing fight space.

## Enemy Telegraphs

- Ghoulkin attacks now have a longer, clearer windup.
- Enemies emit `windup_started` and `attack_resolved` signals.
- Windup uses a more exaggerated crouch/lean pose and red-tinted warning state.
- Windup creates an `EnemyWindupWarning` ground marker.
- Enemies briefly enter attack recovery after resolving a strike so attacks do not feel like instant snapping.

## Player Feedback

- Blocking now emits a `blocked` signal and triggers a short shield-like flash, camera shake, and sound.
- Parrying now triggers a stronger blue-white flash, ground ring, camera shake, parry sound, and stagger on the nearest enemy.
- Taking damage now emits a `hurt` signal and triggers impact feedback and camera shake.
- Player hurt tint is stronger and more visible.

## Stagger And Death Readability

- Parried enemies stagger longer.
- Stagger pose has stronger scale/lean changes.
- Enemy death now settles into a more visible collapsed pose instead of disappearing instantly.
- Enemy death triggers a death sound, light camera shake, and ground feedback.

## Camera, Audio, And VFX

- Camera shake is applied to hurt, block, parry, enemy death, and combat impacts.
- Added procedural audio cues instead of importing new audio files.
- VFX are built from short-lived primitive meshes, not particles or dynamic lights.
- Effects are intentionally small and web-safe.

## Web And Potato Mode Notes

- No new large assets were added.
- No dynamic shadows, particles, external dependencies, or high-cost post-processing were added.
- The combat feedback system uses simple `MeshInstance3D` primitives with short lifetimes.
- Encounter staging objects are collisionless visual aids.
- This pass should not materially increase web memory or GPU cost.

## Verification

Commands run from the Godot project root:

```powershell
& 'C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --script res://tools/verify_runtime.gd
```

Result: passed. Output ended with `runtime vertical slice verification complete`.

Known verifier note: Godot still emits ObjectDB cleanup warnings at process exit.

```powershell
& 'C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe' --path . --script res://tools/capture_slice_screenshots.gd
```

Result: passed. Screenshots were saved without script errors.

Known local graphics note: Godot reports Intel HD Graphics 620 OpenGL quality warnings and switches to ANGLE on this machine.

```bat
Export_Web_Build.bat
```

Result: passed. The web export verifier reported `7 files, 261.0 MB`.

## Screenshot Outputs

Key combat screenshots:

- `verification_screenshots/05_forest_gate.png`
- `verification_screenshots/07_combat_clearing.png`
- `verification_screenshots/08_ghoulkin_windup.png`
- `verification_screenshots/09_player_block_moment.png`
- `verification_screenshots/10_ghoulkin_death_read.png`

Current capture set:

- `verification_screenshots/01_greyfen_spawn.png`
- `verification_screenshots/02_village_center.png`
- `verification_screenshots/03_shrine_sister_anwen.png`
- `verification_screenshots/04_sister_anwen_dialogue.png`
- `verification_screenshots/05_forest_gate.png`
- `verification_screenshots/06_forest_trail.png`
- `verification_screenshots/07_combat_clearing.png`
- `verification_screenshots/08_ghoulkin_windup.png`
- `verification_screenshots/09_player_block_moment.png`
- `verification_screenshots/10_ghoulkin_death_read.png`

## Known Issues

- The Ghoulkin and human models are still low-poly/stylized imported stand-ins, not AAA-quality creatures or actors.
- The windup marker exists and verifies, but it may still read subtly in screenshots depending on camera angle and fog.
- There is no real animation retargeting yet; combat poses are procedural transforms, not authored animation clips.
- The first fight is clearer than before, but it still needs better HUD readability, enemy health presentation, attack timing teaching, and audio mix polish.
- Wider areas remain intentionally blocked or partial.

## Recommended Phase 1D

Implement Phase 1D: improve UI/HUD combat readability and first-quest guidance without adding new zones or systems. Focus on compact health/stamina/enemy health feedback, block/parry timing hints, first-fight objective clarity, damage/status cues, and Web/Potato-safe UI polish. Keep scope locked to Greyfen through first Ghoulkin victory and preserve the single web export.
