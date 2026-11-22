# MASTER-003 Complete Function and Visual Recovery

## Files Changed

- Character spawning/presentation: `asset_spawn_helper.gd`, `character_presentation.gd`, `character_visual_contract.gd`
- Gameplay: `game.gd`, `player_controller.gd`, `combat_manager.gd`, `enemy_ai.gd`
- Presentation: `visual_director.gd`, `hud.gd`, `audio_manager.gd`, `greyfen_life_controller.gd`
- Verification/release: `verify_master_003.gd`, `verify_runtime.gd`, `export_presets.cfg`, `deploy_web_update.ps1`

## Implemented

- Made sun and moon mutually exclusive by using a real solar orbit and corrected day/twilight/night weights.
- Replaced spherical cloud lumps with lightweight textured billboard cloud layers.
- Restored protagonist-sized skeletal bodies for Kael, Anwen, villagers, and the five Wychwood enemies.
- Added a runtime character visual contract and removed proxy anatomy when valid skeletal assets exist.
- Prevented Anwen from teleporting or turning away when dialogue starts.
- Replaced overlapping interaction ownership with facing, distance, priority, and line-of-sight focus selection.
- Changed conversations to one-line pagination; choices cannot be bypassed by a generic close action.
- Aligned sword damage with strike timing and rejected targets behind walls or outside the forward arc.
- Added enemy separation, attack line-of-sight, and distinct approach profiles.
- Improved Oathfire staging audio, phase signaling, locked direction, and tapered beam geometry.
- Preserved river safety, bridge-only traversal, story progression, Web rendering, and Potato Mode.

## Verification

- `verify_master_003.gd`: PASS
- `verify_runtime.gd`: PASS
- `verify_visible_quality.gd`: PASS
- `verify_motion_quality.gd`: PASS

Godot headless shutdown can still report null-material/ObjectDB cleanup warnings after successful checks.

## Remaining Limitations

- Humans and monsters remain optimized stylized models rather than photoreal scanned characters.
- Clouds are procedural billboard layers, not volumetric weather simulation.
- Facial animation and cinematic dialogue staging remain limited.

## Running

Use the production URL or serve `outputs/AshenOath_Web` through the bundled Python HTTP server. Click the launch screen, choose New Game, and use WASD/mouse, left click, right click, Space, Shift, and C.
