# WORLD-013 Result — Authored Wychwood

## Files changed

- `scripts/zones/wychwood_section.gd`
- `tools/verify_world_013.gd`
- `tools/capture_world_013.gd`
- `tools/gate_profiles.json`
- `Development_Gallery/screenshots/WORLD-013_*.png`

## Implementation

- Added a bounded `WychwoodAuthoredPresentation` layer without changing quest ownership, river rules, or enemy stats.
- Added a non-blocking root arch at the Greyfen-facing threshold so the entrance reads as a forest landmark rather than a flat marker.
- Added two low-cost MultiMesh canopy layers, a batched understory, and forest-floor detail with Potato/Balanced/Quality instance budgets.
- Added five clue sightline markers and restrained root crossings around the route while preserving the existing authored corridor.
- Added a framed combat clearing with ash bed, boundary stones, enemy-spacing metadata, and a memory landmark for aftermath dressing.
- Kept all custom presentation geometry collision-free; route and bridge collision remain owned by the existing spatial service.

## Verification and captures

```powershell
& "C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe" --headless --path . --script tools/verify_world_013.gd
& .\tools\run_ticket_gate.ps1 -Profiles world_013 -ChangedViews wychwood_authored -ChangedFiles @('outputs/AshenOathTheRoadBetweenCrowns/scripts/zones/wychwood_section.gd','outputs/AshenOathTheRoadBetweenCrowns/tools/verify_world_013.gd','outputs/AshenOathTheRoadBetweenCrowns/tools/capture_world_013.gd','outputs/AshenOathTheRoadBetweenCrowns/tools/gate_profiles.json','outputs/AshenOathTheRoadBetweenCrowns/WORLD_013_RESULT.md') -NoCache
```

The graphical captures are written to `Development_Gallery/screenshots/` and are inspected at 1280x720. The ticket does not export or deploy production.

## Running steps

1. Open PowerShell in this project directory.
2. Run `& "C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64.exe" --path .`.
3. Choose **New Game** and walk from Greyfen through the Wychwood gate.
4. Follow the central clue route, cross only at the bridge, and enter the clearing to verify sightlines and enemy spacing.
5. Use `E` at the return gate; the existing bridge/navigation recovery must remain unchanged.

## Known limitations

- The environment remains grounded stylized Web geometry; this ticket does not introduce an external forest asset pack.
- Existing Wychwood character and monster fidelity is unchanged and remains covered by the later character/monster tickets.
- Godot may still report shutdown RID/ObjectDB diagnostics after multi-zone verification; those lifecycle warnings are tracked separately.

## Next ticket

`WORLD-014 — Cemetery and Chapel`.
