# CHAR-QA-001 Result

Date: 2026-08-13
Branch: `codex/soul-rebuild`

## Changes

- Replaced the duplicated full-body composition with generated male and female native head shells plus complete peasant outfit bodies.
- Added rigged role-selected hair and retained shared skeletal animation across head, clothing, and hair layers.
- Corrected the head-shell crop so shoulder and upper-arm triangles cannot survive below the neck line.
- Added a character acceptance verifier covering Kael, Anwen, villagers, guards, and travelers.
- Updated the role manifest to describe the assets actually used at runtime.
- Added an honest controller matrix separating verified software behavior from unavailable physical-device testing.

## Acceptance

- No neck hump, detached shoulder fragments, face cards, eye boxes, or duplicate base body remain in the accepted captures.
- Every tested humanoid has a native modeled head, complete outfit body, rigged hair, at least three active skeleton/animation layers, and an accepted rendered-height range.
- Gamepad family detection, glyph switching, remapping, conflict handling, hotplug simulation, disconnect focus recovery, generic fallback, and guarded rumble pass.
- No physical controller was connected. Xbox, DualShock 4, DualSense, Switch Pro, and generic physical-device certification remain explicitly `untested_no_hardware`.

## Verification

Passed:

- `verify_char_005.gd` through `verify_char_009.gd`
- `verify_anim_003.gd`
- `verify_face_003.gd`
- `verify_input_003.gd`
- `verify_input_004.gd`
- `verify_char_qa_001.gd`

## Screenshots

- `Development_Gallery/screenshots/CHAR_006_Kael_Fused_Rig.png`
- `Development_Gallery/screenshots/CHAR_006_Kael_Sword_Attack.png`
- `Development_Gallery/screenshots/CHAR_007_Anwen_Shared_Rig.png`
- `Development_Gallery/screenshots/CHAR_007_Anwen_ThreeQuarter.png`
- `Development_Gallery/screenshots/CHAR_008_Named_Ecosystem_Lineup.png`
- `Development_Gallery/screenshots/CHAR_009_Greyfen_Crowd_Variation.png`
- `Development_Gallery/screenshots/FACE_003_01_Kael_Native_Face.png`
- `Development_Gallery/screenshots/FACE_003_02_Anwen_Native_Face.png`

## Known Limitations

- Current crowd variety is cohesive but still limited to two base outfits and three hair choices; later named-character tickets must add stronger occupation silhouettes.
- Physical gamepad families require real USB/Bluetooth hardware before certification.
- This ticket does not alter monsters or the White Hart.

## Running

From the project root:

```powershell
& "C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64.exe" --path .
```

Select **New Game**. Kael is visible immediately; Sister Anwen and Greyfen villagers are on the opening route. This development checkpoint is not a production deployment.
