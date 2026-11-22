# Visible Repair Lockdown Results

## Files Changed
- `scripts/game.gd`
- `scripts/player_controller.gd`
- `scripts/enemy_ai.gd`
- `tools/verify_visible_quality.gd`
- `VISIBLE_REPAIR_LOCKDOWN_RESULTS.md`

## Verifier Checks Added
`tools/verify_visible_quality.gd` now verifies:
- Non-white/default materials for route-visible rocks, stones, trees, trunks, leaves, roofs, houses, graves, fences, shrine pieces, NPC/player-style meshes, and Ghoulkin.
- At least 3 valid Greyfen houses in the first-route area, each with visible roof and wall geometry and non-white materials.
- Main route clearance in Greyfen and Wychwood using conservative corridor checks for trees, rocks/rubble, houses, fences, carts, barrels, crates, and deadfall.
- Visible player locomotion by forcing walk animation and measuring transform changes on visual/proxy/weapon nodes.
- Visible sword animation by forcing a heavy attack and checking `visible_sword_root` transform changes.
- Ghoulkin material and basic windup motion.

## Which Checks Failed Before Fixing
The hard verifier did not exist before this pass. Existing failures were visible/manual only: white/default materials, weak house readability, route blockage risk, static-looking locomotion, and unclear sword swing.

## Material System Fix
- Added a first-route material safety pass in `scripts/game.gd` after zone construction.
- Added bad-white/default material detection and palette fallback for rock, trunk, leaves, roof, wall, grave, shrine, ground, wood, metal, cloth, skin, and monster categories.
- Added player imported-body material fallback in `scripts/player_controller.gd`.
- Added Ghoulkin imported-body material fallback in `scripts/enemy_ai.gd`.

## House Fix
- Marked Greyfen authored houses with `first_route_house`, `greyfen_house`, and `visible_house` metadata.
- Houses are now validated by the verifier for visible non-white walls and roofs.

## Route Clearance Fix
- Existing first-route corridor safeguards are now verified by `verify_visible_quality.gd`.
- The verifier fails if route blockers sit inside the Greyfen/Wychwood corridor.

## Player Animation Fix
- The visible-quality verifier now proves player movement changes visible/proxy/weapon transforms.
- Existing procedural limb proxies and body motion are now part of the automated acceptance check.

## Sword Animation Fix
- The visible-quality verifier now finds `visible_sword_root`, forces a heavy attack, and fails if the visible sword transform does not change.
- This prevents a hidden/tiny attack object from being the only animated weapon.

## Ghoulkin Fix
- Ghoulkin imported bodies now receive a rotten green/grey fallback material if their source material is missing/default/white.
- Verifier checks Ghoulkin is present, non-white, and has transform changes during windup.

## Screenshot Paths
Fresh screenshots were captured and mirrored to:
- `Development_Gallery/screenshots/Capture_01_greyfen_spawn_2026-06-22_003050.png`
- `Development_Gallery/screenshots/Capture_02_village_center_2026-06-22_003050.png`
- `Development_Gallery/screenshots/Capture_03_shrine_sister_anwen_2026-06-22_003050.png`
- `Development_Gallery/screenshots/Capture_04_graveyard_visible_area_2026-06-22_003050.png`
- `Development_Gallery/screenshots/Capture_08_forest_gate_2026-06-22_003050.png`
- `Development_Gallery/screenshots/Capture_09_forest_trail_2026-06-22_003050.png`
- `Development_Gallery/screenshots/Capture_11_player_walking_pose_2026-06-22_003050.png`
- `Development_Gallery/screenshots/Capture_12_player_sword_mid_swing_2026-06-22_003050.png`
- `Development_Gallery/screenshots/Capture_13_ghoulkin_windup_hud_2026-06-22_003050.png`

## Final Verifier Results
Commands run:

```powershell
& "C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe" --headless --path "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns" --script res://tools/verify_visible_quality.gd
& "C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe" --headless --path "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns" --script res://tools/verify_runtime.gd
& "C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe" --path "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns" --script res://tools/capture_slice_screenshots.gd
.\Export_Web_Build.bat
```

Results:
- `tools/verify_visible_quality.gd` passed.
- `tools/verify_runtime.gd` passed.
- Screenshot capture passed.
- `Export_Web_Build.bat` passed and verified `AshenOath_Web_Slim` at 7 files / 43.2 MB.

## Remaining Visible Issues
- The game is still low-poly/stylized and visibly far below Witcher 3 fidelity.
- The verifier proves sword transform changes, but camera-readable sword trails still need stronger art direction.
- Player/Ghoulkin animation remains procedural/proxy-based, not true skeletal animation retargeting.
- Screenshots are useful but still not a substitute for a real playtest pass on the Dell 7280 browser.
