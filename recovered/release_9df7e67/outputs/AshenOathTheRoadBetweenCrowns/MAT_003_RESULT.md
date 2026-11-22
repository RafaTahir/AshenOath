# MAT-003 Result — Unified Material Library

## Status

Implemented and verified on the cumulative `codex/soul-rebuild` branch. World surfaces now use one cached contract for authored PBR terrain/buildings plus explicit procedural roles; unknown surface IDs still fall back deterministically to the ground material.

## Changes

- Extended `WorldMaterialLibrary` with explicit `water`, `foliage`, `metal`, `blood`, `ash`, and `emissive_window` roles.
- Preserved the seven complete PBR sets for forest ground, wet mud, cobblestone, plaster, timber, roof tiles, and medieval brick.
- Added surface profiles, PBR-role enumeration, contract reporting, cache-key counts, and deterministic role detection for verifiers and later zone builders.
- Added lightweight role flags: alpha water, alpha-scissored foliage, metallic procedural metal, blood/ash color separation, and emissive warm windows.
- Kept Balanced/Potato texture budgets unchanged; Quality retains normals, ORM, AO, and triplanar projection only for texture-backed surfaces.
- Added `verify_mat_003.gd` and a 1280x720 Compatibility-renderer material swatch capture.
- Registered the targeted `materials` workflow profile and `materials` changed-view capture.

## Verification

```powershell
cd "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns"
& .\tools\run_ticket_gate.ps1 -Profiles materials -ChangedViews materials -NoCache
```

Result: `TICKET GATE: PASS`.

Passed gates: content integrity, runtime smoke, MAT-001, MAT-003, visible quality, and the graphical material capture. The swatch capture rendered at 1280x720 through Compatibility/ANGLE and was inspected for nonblank output and role separation.

## Evidence

- `Development_Gallery/screenshots/MAT_003_Unified_Surface_Library.png`

## Honest Limitations

- The role library improves material consistency and removes silent role fallback; it does not by itself rebuild blockout buildings, terrain meshes, river geometry, or foliage placement. Those are subsequent `WORLD-012` and later world tickets.
- Water and foliage currently reuse compact texture sources where dedicated maps are not present; the contract is explicit and browser-safe rather than photoreal.
- This ordinary ticket does not export, modify tracked `web/`, or deploy production.

## Running Steps

For the targeted ticket gate:

```powershell
cd "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns"
& .\tools\run_ticket_gate.ps1 -Profiles materials -ChangedViews materials -NoCache
```

For the direct verifier and capture:

```powershell
& "C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe" --headless --path . --script tools\verify_mat_003.gd
& "C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe" --path . --rendering-method gl_compatibility --script tools\capture_mat_003.gd
```

For normal play:

```powershell
& "C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64.exe" --path . --editor
```

## Next Ticket

`WORLD-012` — Authored Greyfen.
