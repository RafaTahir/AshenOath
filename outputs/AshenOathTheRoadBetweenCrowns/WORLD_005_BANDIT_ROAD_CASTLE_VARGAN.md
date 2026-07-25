# WORLD-005 — Bandit Road and Castle Vargan

## Files Changed
- Added a dedicated authored Bandit Road zone builder.
- Preserved and verified the existing Castle approach, courtyard, and Record Hall builder.
- Added targeted verification and four changed-view captures.
- Registered the new runtime builder in the slim Web export.

## Visible Result
- The road now has a ruined checkpoint, drainage ditches, Senn's command camp, wagon, rubble, controlled trees, and clear travel lanes.
- Senn and his two guards remain off the gate corridor.
- Castle approach, courtyard NPCs, evidence, ledger choice, haunting, and return gates remain intact.

## Running
1. Open the project in Godot 4.6.3.
2. Run `scenes/main.tscn`.
3. Start New Game, follow the campaign through Marsh Crossing, then use the north road to reach Captain Senn and Castle Vargan.

## Verification
Run `tools/run_ticket_gate.ps1 -Profiles world_005 -ChangedViews world_005`.
