# MOTION-002 Real Skeletal Character Animation Recovery

## Files Changed
- Added `scripts/character_animation_driver.gd`.
- Integrated skeletal clips in `player_controller.gd`, `enemy_ai.gd`, `game.gd`, and `npc_ambient.gd`.
- Replaced route-visible static mappings with selected Quaternius CC0 embedded glTF rigs.
- Updated runtime, visible-quality, motion-quality, and Web export configuration.

## Visible Recovery
- Player: real idle, walk, run, sword attacks, hit, roll, and death bone animation.
- NPCs: Anwen, Rook, and nearby villagers now run real asynchronous skeletal idle clips.
- Wychwood: all five enemies use real idle, walk/run, attack, hit, and death animation.
- Legacy proxy limbs and rigid character-detail boxes are hidden when a valid skeleton is active.
- Controller physics remains authoritative; animation root motion does not move collision bodies.

## Assets And License
- Quaternius RPG Character Pack: Warrior, Cleric, Monk, Rogue (CC0 1.0).
- Quaternius Ultimate Monsters: Orc Skull (CC0 1.0).
- Source and license records are in `assets_external/licenses/`.

## Verification
- `verify_runtime.gd`: passes.
- `verify_motion_quality.gd`: passes by measuring real Skeleton3D bone-transform changes.
- `verify_visible_quality.gd`: passes and requires the rigged Warrior sword and attack clips.
- `verify_audio_runtime.gd`: passes.
- Screenshot: `Development_Gallery/screenshots/Capture_10_combat_clearing_2026-07-05_070732.png`.

## Known Limitations
- The Warrior pack has no dedicated jump clip; airborne presentation uses its animated armed run pose.
- No facial animation or full foot IK was added.

## Run The Live Game
1. Open `https://ashenoath.vercel.app/?v=motion002` in Chrome or Edge.
2. Click the game, then press Enter.
3. Choose **New Game**.
4. Use WASD to move, Shift to run, X to jump, Space to roll, and mouse buttons to attack.
