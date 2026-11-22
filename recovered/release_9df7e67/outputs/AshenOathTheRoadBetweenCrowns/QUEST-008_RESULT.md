# QUEST-008 Result

## Changes
- Road of Crows retains named evidence for Bram, Sella, Oren, Vargan wire, and drag marks.
- Evidence threshold and five-member Wychwood encounter hooks remain data-driven.
- Private Sister Anwen, public notice-board, and retained-evidence reporting
  are now recorded in the narrative contract with their trust/fear and
  relocation consequences.
- Greyfen report prompts now change from generic conversation to an explicit
  private Anwen report or public notice-board report when the route is ready.
- The notice board now resolves post-report dialogue variants with no stale
  `Accept Road of Crows` action after the contract has already been accepted.
- Legacy saves that completed Road of Crows before report choices existed now
  surface the three report targets without inventing the old choice. Selecting
  one clears the migration flag and restores the Bell Beneath Greyfen handoff.
- Quest state migration now restores the inserted `read_chapel_names` objective
  from later Teeth in the Rain progress instead of silently resetting it.

## Verification
- Story ticket gate: PASS (`content_integrity`, runtime smoke, campaign
  coverage, QUEST-001/002/008/009/010/011/012, save, NARR-005, side quests,
  and CIN-002).
- `verify_quest_008.gd`: PASS across all 120 clue-order permutations; the
  three-clue threshold never deadlocks, all three report targets remain
  present, and report variants contain no stale actions.
- `verify_quest_002.gd`: PASS after the legacy chapel-objective migration fix.
- Graphical `capture_world_001.gd` and `capture_world_002.gd`: PASS at
  1280x720 Compatibility rendering with fresh nonblank frames.
- Content integrity: PASS.

## Remaining
The complete player-driven opening route, final browser pacing, and final
visual acceptance remain part of the Milestone D/F release gates. Graphical
capture processes still emit classified shutdown-only renderer cleanup
diagnostics after their pass marker; no active-frame failure was recorded by
the targeted story gate.

## Screenshots
- `Development_Gallery/screenshots/WORLD_001_01_SpawnStreet_20260821_145032.png`
- `Development_Gallery/screenshots/WORLD_001_02_VillageCentre_20260821_145032.png`
- `Development_Gallery/screenshots/WORLD_001_03_ShrineQuarter_20260821_145032.png`
- `Development_Gallery/screenshots/WORLD_001_04_ForgeStreet_20260821_145032.png`
- `Development_Gallery/screenshots/WORLD_002_01_GateThreshold_20260821_145056.png`
- `Development_Gallery/screenshots/WORLD_002_02_InvestigationRoad_20260821_145056.png`
- `Development_Gallery/screenshots/WORLD_002_03_RiverCrossing_20260821_145056.png`
- `Development_Gallery/screenshots/WORLD_002_04_CombatClearing_20260821_145056.png`

## Running Steps
```powershell
$env:GODOT_BIN='C:\Temp\AshenOathGodot4.6.3\Godot_v4.6.3-stable_win64_console.exe'
powershell -ExecutionPolicy Bypass -File .\tools\run_ticket_gate.ps1 -Profiles story -ChangedFiles scripts\game.gd,scripts\zones\greyfen_section.gd,scripts\quest_manager.gd,data\dialogue.json,tools\verify_quest_008.gd -NoCache
& $env:GODOT_BIN --path . --display-driver windows --rendering-method gl_compatibility --rendering-driver opengl3 --script tools/capture_world_001.gd
& $env:GODOT_BIN --path . --display-driver windows --rendering-method gl_compatibility --rendering-driver opengl3 --script tools/capture_world_002.gd
```
