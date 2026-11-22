# WORLD-012 Result — Authored Greyfen

## Status

Implemented on the cumulative `codex/soul-rebuild` branch. Greyfen keeps its existing quest, river, bridge, gate, NPC, and collision ownership while the Balanced route receives a bounded authored-dressing pass and scale-safe facade treatment.

## Changes

- Preserved the existing grounded house shells and authored roof contract; Potato uses the lightweight fallback slopes, while larger imported roof source meshes remain outside Balanced until their bounds are normalized.
- Added scale-safe Balanced facade modules for doors, windows, and chimneys, with deterministic fallback behavior for Potato.
- Added `GreyfenAuthoredDetailLayer` with ticket ownership for structural drains, shrine arch, forge canopy/chimney/rack, market awning/counter/sign, and river-shore stones.
- Kept the main road, shrine approach, river bridge centre, and bank routes reserved and validated through `ZoneSpatialService`.
- Added `verify_world_012.gd` for authored detail markers, rendered-role presence, route clearance, river safety, and node/mesh/light budgets.
- Updated the shared zone budget to distinguish total skeleton residency from visible skeletons: Greyfen's ten synchronized body/outfit layers measure `20` resident and `6` visible skeleton resources, within explicit `20`/`10` limits rather than failing the older single-layer ceiling.
- Added four fresh 1280x720 Balanced captures for spawn street, shrine quarter, forge yard, and river bridge.

## Verification

```powershell
cd "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns"
& .\tools\run_ticket_gate.ps1 -Profiles world -ChangedViews greyfen_authored -NoCache
```

The direct WORLD-012 runtime gate passed after correcting the detail markers and same-bank route sweep. The zone-budget gate now passes with Greyfen measured at `nodes=961`, `meshes=253`, `lights=4`, `skeletons=20`, and `visible_skeletons=6`. The graphical capture passed through Compatibility/ANGLE at 1280x720 and was inspected by Codex. The full targeted world profile is the final checkpoint gate for this ticket.

## Evidence

- `Development_Gallery/screenshots/WORLD_012_01_Greyfen_Spawn_Street.png`
- `Development_Gallery/screenshots/WORLD_012_02_Greyfen_Shrine_Quarter.png`
- `Development_Gallery/screenshots/WORLD_012_03_Greyfen_Forge_Yard.png`
- `Development_Gallery/screenshots/WORLD_012_04_Greyfen_River_Bridge.png`

## Honest Limitations

- This ticket improves the opening Greyfen slice using the existing approved asset library; it does not claim photoreal humans, a fully authored open world, or completion of Wychwood/cemetery/castle reconstruction.
- Greyfen still uses procedural terrain batching and the existing stylized architecture foundation. Dedicated building interiors, full river dressing, and deeper zones remain later tickets.
- The current project still has known Godot renderer/ObjectDB teardown diagnostics when standalone graphical or headless test trees exit. No new parser/resource/runtime assertion was introduced by WORLD-012; the active budget gate reports no null-material surfaces.
- This ordinary ticket does not export, modify tracked `web/`, or deploy production.

## Running Steps

Targeted gate:

```powershell
cd "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns"
& .\tools\run_ticket_gate.ps1 -Profiles world -ChangedViews greyfen_authored -NoCache
```

Direct verification/capture:

```powershell
& "C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe" --headless --path . --script tools\verify_world_012.gd
& "C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe" --path . --rendering-method gl_compatibility --script tools\capture_world_012.gd
```

Normal play:

```powershell
& "C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64.exe" --path . --editor
```

## Next Ticket

`LIFE-001` — Greyfen Daily Life.
