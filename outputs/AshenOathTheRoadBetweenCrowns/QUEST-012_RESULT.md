# QUEST-012 Result

## Changes
- Added an immutable ending guard for invalid, repeated, stale, and double-activated covenant choices.
- Completed peaceful Witness/Mercy and combat Duty/Ash resolution through the same final-choice state contract.
- Persisted `final_witnesses`, `final_covenant`, `final_choice_completed`, `hart_defeated`, and `epilogue_cards` through story/world save state.
- Added state-specific Hart Glade aftermath dressing and removed the stale White Hart interaction after a completed ending.
- Added the `verify_quest_012.gd` gate and registered it in the story profile.
- Extended `epilogue_contract.json` to declare the persisted witness snapshot.

## Verification
- `verify_quest_012.gd`: PASS for all four ending families, including combat handoff, boss defeat, one-shot replay protection, save round trip, and Hart aftermath rebuild.
- Story profile: PASS, including content integrity, runtime smoke, quests 001/002/008/009/010/011/012, save, narrative, campaign quest coverage, side quests, dialogue, and fresh `capture_world_006`.
- World-006 profile: PASS, including Castle/finale route transitions, zone budgets, story regression, Web export, packed startup, and fresh `capture_world_006`.
- Web candidate generated and verified locally; production `web/`, `main`, and Vercel were not modified.

## Screenshots
- `Development_Gallery/screenshots/WORLD_006_01_Undercroft_20260821_104308.png`
- `Development_Gallery/screenshots/WORLD_006_02_Assembly_20260821_104308.png`
- `Development_Gallery/screenshots/WORLD_006_03_HartGlade_20260821_104308.png`

The frames are fresh 1280x720 graphical Compatibility captures and visually inspected for nonblank output, route framing, grounding, and readable lighting. They also document the still-open low-poly/blockout visual debt in the undercroft and finale.

## Remaining
- Full real-input browser playthrough evidence for all four ending families remains part of the final campaign gate.
- The current source still carries known shutdown-only renderer/RID/ObjectDB diagnostics and interim monster/world presentation; this ticket does not claim final visual approval or production deployment.

## Running Steps
```powershell
$env:GODOT_BIN='C:\Temp\AshenOathGodot4.6.3\Godot_v4.6.3-stable_win64_console.exe'
powershell -ExecutionPolicy Bypass -File .\tools\run_ticket_gate.ps1 -Profiles story -ChangedViews world_006 -NoCache
powershell -ExecutionPolicy Bypass -File .\tools\run_ticket_gate.ps1 -Profiles world_006 -ChangedViews world_006 -NoCache
```
