# WORLD-014 Result — Cemetery and Chapel

## Files changed

- `scripts/zones/cemetery_section.gd`
- `tools/verify_world_014.gd`
- `tools/capture_world_014.gd`
- `tools/gate_profiles.json`
- `Development_Gallery/screenshots/WORLD-014_*.png`

## Implementation

- Added a bounded `CemeteryAuthoredPresentation` layer with explicit bell, chapel, ossuary, grave-row, Crow Shrine, and aftermath state contracts.
- Added a bell-house hood, braces, rope, and clapper to turn the existing bell landmark into a readable structure.
- Added chapel buttresses, a memory-lit window, floor moss, and a clearer ruined-chapel focal point without sealing the doorway.
- Added three low-cost grave-row rhythms, a Crow Shrine roost with silhouettes, and state anchors for silent/rung, sealed/opened, and pending/cleared states.
- Pulled cemetery-edge trees outside the authored sightlines and reduced their scale so the chapel, bell, and shrine remain readable from the approach without narrowing the route.
- Kept all additions render-only. Existing clue positions, Anwen staging, ambush ownership, Castle route, river safety, and collision remain unchanged.

## Verification and captures

```powershell
& "C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe" --headless --path . --script tools/verify_world_014.gd
& .\tools\run_ticket_gate.ps1 -Profiles world_014 -ChangedFiles @('outputs/AshenOathTheRoadBetweenCrowns/scripts/zones/cemetery_section.gd','outputs/AshenOathTheRoadBetweenCrowns/tools/verify_world_014.gd','outputs/AshenOathTheRoadBetweenCrowns/tools/capture_world_014.gd','outputs/AshenOathTheRoadBetweenCrowns/tools/gate_profiles.json','outputs/AshenOathTheRoadBetweenCrowns/WORLD_014_RESULT.md') -NoCache
```

The full uncached `world_014` profile passed: content integrity, runtime smoke, cemetery structure, WORLD-014 presentation, narrative compatibility, river safety, navigation, zone budgets, and visible quality. The four latest 1280x720 captures were inspected by Codex and written to `Development_Gallery/screenshots/`. The ticket does not export or deploy production.

## Running steps

1. Open PowerShell in this project directory.
2. Run `& "C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64.exe" --path .`.
3. Choose **New Game** and continue to Greyfen’s cemetery road.
4. Inspect the bell, grave court, chapel, and Crow Shrine; use `E` at the existing clues and chapel interaction.
5. Keep river crossings on bridges and confirm the Castle gateway remains accessible.

## Known limitations

- The cemetery remains grounded stylized Web geometry rather than a bespoke external environment pack.
- Bell ringing, grave changes, and Crow Shrine choices remain owned by existing story/gameplay code; this ticket adds the visible state contract and staging layer.
- The current graphical capture still reports existing shutdown RID/ObjectDB diagnostics and the river controller's physics-interpolation warning; these are tracked separately from the passing WORLD-014 assertions.

## Next ticket

`SKY-003 — Living Sky and Weather`.
