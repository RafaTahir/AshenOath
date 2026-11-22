# WORLD-REPAIR-002 — Castle, Finale, and River Presentation

## Status
Targeted presentation repair completed on the development branch. No production Web export or Vercel deployment was performed.

## Changes
- Rebuilt the Castle Vargan approach, courtyard, and Record Hall skyline with layered towers, wall bands, rafters, ceiling structure, and readable approach silhouettes.
- Added a grounded antlered White Hart witness display in Hart Glade and a matching authored White Hart encounter body for the finale, replacing the floating wolf presentation at runtime.
- Added undercroft beams and a stronger Hart Glade focal plinth/landmark.
- Kept the river and bridge route systems intact; no river-crossing gameplay or route-critical interaction was added.
- Cleared stale guidance hints on zone transitions so a New Game prompt cannot follow the player into Castle or finale zones.
- Kept required Record Hall and Hart Glade light pools in Balanced/Potato budgets.

## Files
- `scripts/zones/castle_vargan_section.gd`
- `scripts/zones/campaign_finale_section.gd`
- `scripts/enemy_ai.gd`
- `scripts/game.gd`
- `scripts/visual_director.gd`

## Evidence
- `Development_Gallery/screenshots/WORLD_005_01_BanditRoad_20260810_224831.png`
- `Development_Gallery/screenshots/WORLD_005_02_CastleApproach_20260810_224831.png`
- `Development_Gallery/screenshots/WORLD_005_03_CastleCourtyard_20260810_224831.png`
- `Development_Gallery/screenshots/WORLD_005_04_RecordHall_20260810_224831.png`
- `Development_Gallery/screenshots/WORLD_006_03_HartGlade_20260810_222715.png`

## Verification
- `verify_world_003.gd`: pass.
- `verify_world_005.gd`: pass.
- `verify_world_006.gd`: pass.
- `verify_light_001.gd`: pass.
- `verify_engine_002.gd`: pass.
- `verify_engine_003.gd`: pass.
- `verify_zone_budgets.gd`: pass.
- `capture_world_005.gd`: pass at 1280x720.

## Known limitations
Castle and finale geometry remain deliberately lightweight and stylized for the Web/Dell target; they are no longer empty or sky-leaking, but they are not realistic AAA assets. Compatibility renderer shutdown still emits RID/ObjectDB diagnostics from the capture harness and needs the later release lifecycle gate.

## Local running steps
```powershell
cd C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns
& 'C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64.exe' --path .
```

For the browser build, serve `AshenOath_Web` with a local static server; do not use this development checkpoint as a production Web export.
