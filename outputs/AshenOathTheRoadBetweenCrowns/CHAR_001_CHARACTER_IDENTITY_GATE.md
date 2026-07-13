# CHAR-001 Character Identity Gate

## Scope

Development-only character identity pass for Kael, Sister Anwen, one retained Greyfen villager profile, and the Wychwood skeletal Ghoulkin. Production Web files and Vercel were not changed.

## Changes

- Added mesh-native identity palettes for Kael, Anwen, villagers, and the four Wychwood enemy roles.
- Removed blanket skeletal-body tints in favor of per-surface skin, hair, cloth, leather, linen, boot, eye, and metal treatment.
- Kept detached face cards and proxy anatomy out of valid skeletal characters.
- Fixed Anwen's idle mapping so her real imported animation plays.
- Added connected-body proportion differences for the Wychwood pack.
- Grounded the imported Ghoulkin to its animated leg endpoints.
- Added `verify_char_001.gd`, `capture_char_001.gd`, and the CHAR-001 release-gate entry.
- Included `character_identity_profile.gd` in the explicit slim Web export list.

## Visual Evidence

- `Development_Gallery/screenshots/CHAR_001_01_Kael_Identity.png`
- `Development_Gallery/screenshots/CHAR_001_02_Anwen_Identity.png`
- `Development_Gallery/screenshots/CHAR_001_03_Villager_Identity.png`
- `Development_Gallery/screenshots/CHAR_001_04_Ghoulkin_Identity.png`
- `Development_Gallery/screenshots/CHAR_001_05_Kael_Before_After.png`
- `Development_Gallery/screenshots/CHAR_001_06_Anwen_Before_After.png`
- `Development_Gallery/screenshots/CHAR_001_07_Ghoulkin_Before_After.png`

## Verification

- `verify_char_001.gd`: PASS
- `verify_runtime.gd`: PASS
- `verify_character_real_001.gd`: PASS
- `verify_motion_quality.gd`: PASS
- `verify_navigation_001.gd`: PASS
- Graphical capture at 1280x720 on Intel HD 620/ANGLE: PASS
- Graphical performance: 37.9 FPS average, 35.1 FPS minimum, 267 ms warm transition
- Temporary Web preview: 63.1 MB total, 26.8 MB PCK, packed startup PASS

Godot's existing headless teardown emits null-material/RID/ObjectDB cleanup diagnostics after successful verifier assertions. These remain known engine/project cleanup debt.

## Honest Limitation

This gate makes the four sampled roles distinct, animated, grounded, and free of proxy anatomy. It does not turn the existing low-poly Poly Pizza humans or skeletal Ghoulkin into realistic final character art. Bespoke character meshes, facial rigs, and stronger monster bodies remain later production work.

## Running

1. Open `outputs/AshenOathTheRoadBetweenCrowns/project.godot` in Godot 4.6.3.
2. Press `F6` or run `res://scenes/main.tscn`.
3. Press `Enter` at the launch screen and choose **New Game**.
4. Inspect Kael at spawn, Sister Anwen at the shrine, villagers in Greyfen, and the Ghoulkin in Wychwood.
