# REPAIR-004 — Quest And Objective Synchronization

## Files Changed

- `scripts/game.gd`
- `scripts/npc_ambient.gd`

## Fixes

- Refresh the tracked quest and compass immediately after every zone selection.
- Use one explicit +Z-facing convention for Sister Anwen during staging and ambient attention.
- Validate Anwen's cemetery relocation through the active spatial service and grounded-position fallback.
- Keep Anwen's dialogue facing lock stable until dialogue closes.

## Verification

- `tools/verify_ui_001.gd` — PASS, including Anwen approach/dialogue facing and tracker/compass consistency.
- `tools/verify_runtime.gd` — PASS, including first objective, Wychwood clues, five-enemy victory, return objective, and Anwen reporting.

## Running Steps

```powershell
cd outputs/AshenOathTheRoadBetweenCrowns
& "C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe" --headless --path . --script tools/verify_ui_001.gd
```

## Remaining Issues

- Dialogue still uses subtitle-first fallback when a browser voice asset is unavailable.
- Campaign consequence visuals remain part of the later presentation tickets.

## Development Checkpoint

Pending the Milestone 1 development branch commit.
