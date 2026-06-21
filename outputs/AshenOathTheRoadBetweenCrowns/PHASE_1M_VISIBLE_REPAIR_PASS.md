# Phase 1M Visible Repair Pass

## Files Changed
- `scripts/game.gd`
- `scripts/player_controller.gd`
- `tools/capture_slice_screenshots.gd`
- `PHASE_1M_VISIBLE_REPAIR_PASS.md`

## Visible Fixes Made
- Replaced fragile imported first-route house composition with authored colored houses: plaster walls, dark sloped roof slabs, ridge beams, doors, timber strips, and warm windows.
- Forced first-route trees, rocks, gravestones, fences, carts, crates, barrels, and torches through direct colored procedural meshes instead of relying on white/default imported environment props.
- Added first-route road clearance rules so trees and rubble are pushed off the Greyfen/Wychwood route or skipped if still inside the playable corridor.
- Added visible procedural player limb proxies for walk/run readability when imported character bodies do not animate.
- Enlarged the sword blade and added a sword swing afterimage/trail for attack readability.

## Screenshots Captured
Saved to `verification_screenshots/` and mirrored to `Development_Gallery/screenshots/`.

Final gallery set:
- `Development_Gallery/screenshots/Capture_01_greyfen_spawn_2026-06-21_233231.png`
- `Development_Gallery/screenshots/Capture_02_village_center_2026-06-21_233231.png`
- `Development_Gallery/screenshots/Capture_03_shrine_sister_anwen_2026-06-21_233231.png`
- `Development_Gallery/screenshots/Capture_04_graveyard_visible_area_2026-06-21_233231.png`
- `Development_Gallery/screenshots/Capture_08_forest_gate_2026-06-21_233231.png`
- `Development_Gallery/screenshots/Capture_09_forest_trail_2026-06-21_233231.png`
- `Development_Gallery/screenshots/Capture_11_player_walking_pose_2026-06-21_233231.png`
- `Development_Gallery/screenshots/Capture_12_player_sword_mid_swing_2026-06-21_233231.png`
- `Development_Gallery/screenshots/Capture_13_ghoulkin_windup_hud_2026-06-21_233231.png`
- `Development_Gallery/screenshots/Capture_16_ghoulkin_victory_objective_2026-06-21_233231.png`

## Commands Run
```powershell
& "C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe" --headless --path "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns" --script res://tools/verify_runtime.gd
& "C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe" --path "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns" --script res://tools/capture_slice_screenshots.gd
.\Export_Web_Build.bat
```

## Verification Result
- `tools/verify_runtime.gd` passed.
- Screenshot capture passed and produced the final 16-image set.
- Web export passed through `Export_Web_Build.bat`; `AshenOath_Web_Slim` verified at 7 files / 43.2 MB.
- Godot headless still emits the known ObjectDB cleanup warning after passing.

## Known Remaining Visible Issues
- The project is still stylized/low-poly, not Witcher 3 realism.
- Sword swing now reads better, but the afterimage is still subtle from the default behind-player camera.
- Player/NPC bodies still rely on overlays and proxies rather than proper skeletal animation retargeting.

## Recommended Next Phase
Phase 1N should rebuild player/enemy combat readability from the camera angle: side-readable attack arcs, clearer weapon trails, and stronger Ghoulkin hit reactions, then re-export the Web build.
