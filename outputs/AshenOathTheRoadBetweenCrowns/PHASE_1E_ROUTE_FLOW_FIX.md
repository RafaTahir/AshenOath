# Phase 1E-Lite: Route Flow Fix

## Files Changed

- `scripts/game.gd`
- `tools/verify_runtime.gd`
- `PHASE_1E_ROUTE_FLOW_FIX.md`

## Quest-Flow Fixes

- Speaking to Sister Anwen now completes `speak_anwen` as soon as dialogue opens, so closing the dialogue without choosing the action no longer strands the first objective.
- Road of Crows clues are now forgiving:
  - Inspecting `claw_marks` also completes the skipped corpse clue.
  - Inspecting `black_feathers` also completes corpse and claw clues.
  - Inspecting `tracks` completes the investigation clue chain if earlier clues were skipped.
- `tracks` no longer completes `return_village` before the Ghoulkin fight.
- After Ghoulkin victory, the objective remains `Return to Greyfen with proof`.
- Returning to Sister Anwen after victory completes `return_village` and finishes Road of Crows.

## Verifier Checks Added

- Confirms tracks clue exists.
- Confirms inspecting tracks cannot prematurely complete return/report.
- Confirms skipped clue objectives are safely completed.
- Confirms Ghoulkin victory completes `fight_ghoulkin`.
- Confirms return/report objective is visible after victory.
- Confirms reporting to Sister Anwen completes Road of Crows.

## Commands Run

```powershell
& 'C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --script res://tools/verify_runtime.gd
```

## Test Result

Passed: `runtime vertical slice verification complete`

## Known Remaining Issues

- Reporting is implemented through Sister Anwen interaction logic, while her dialogue text/actions are still generic.
- No screenshot capture or web export was run for this lite pass.

## Recommended Next Phase

Phase 1F: add a tiny route-specific Sister Anwen report dialogue/state so the completed contract feels intentional, without adding new systems or expanding the map.
