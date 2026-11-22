# ENGINE-REPAIR-001 — Materials and Resource Lifecycle

## Status
Targeted repair checkpoint completed on the development branch. Production Web output was not changed.

## Changes
- Validate zone, VisualDirector, and player render roots after late-created equipment, sky, and VFX are attached.
- Ensure mesh surfaces and MultiMesh surfaces receive the stable world fallback before the renderer sees them.
- Preserve mesh resources during staged zone retirement instead of nulling live renderer resources.
- Keep essential Castle and finale light pools in the low-cost lighting budget.
- Apply the authored interior clear/fog profile so Record Hall and Undercroft cannot inherit Greyfen's blue outdoor fog.

## Files
- `scripts/game.gd`
- `scripts/visual_director.gd`
- `tools/verify_engine_003.gd`

## Verification
- `verify_engine_002.gd`: pass.
- `verify_engine_003.gd`: pass.
- `verify_zone_budgets.gd`: pass; visible-zone material reports contain zero missing surfaces.
- `verify_light_001.gd`: pass.
- Fresh graphical Castle capture: `Development_Gallery/screenshots/WORLD_005_04_RecordHall_20260810_224831.png`.

## Known limitation
Godot's Compatibility/ANGLE shutdown still reports renderer RID/ObjectDB cleanup warnings after headless and screenshot tools exit. Active route material validation passes; the remaining warnings are lifecycle teardown diagnostics and remain release-visible work for the later full engine gate.

## Local check
```powershell
cd C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns
& 'C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --script res://tools/verify_engine_003.gd
```

## Next
Continue with the remaining audio, performance, and screenshot-integrity gates before any milestone release.
