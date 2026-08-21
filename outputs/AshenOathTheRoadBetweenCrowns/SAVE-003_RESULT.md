# SAVE-003 — Deterministic Save Migration and Recovery

## Status

Completed on `codex/soul-rebuild` as a development checkpoint. Production
`main`, tracked `web/`, and Vercel remain unchanged.

## Changes

- Advanced the save schema from version 6 to version 7.
- Made direct `Game.load_save_state()` calls run the same migration contract as
  file-backed saves, including future-version rejection.
- Sanitized quest presentation zones, interaction maps, pending endings, boss
  state containers, encounter kill counts, day/night values, and saved setting
  types.
- Added explicit safe defaults for every released campaign zone.
- Hardened `StoryState` against malformed flag/value containers and non-finite
  values while preserving neutral missing choices.
- Rebuilt loaded quest objectives from current definitions, removed unknown
  quest IDs, and cleared invalid tracked-quest references without inventing
  progress.
- Validated loaded river/underworld positions through the active spatial service
  and preserved a valid bridge corridor while clamping the player to walkable
  height.
- Added `verify_save_003.gd` for malformed migration, story/quest sanitization,
  runtime save shape, invalid river recovery, and real zone reload coverage.
- Added a dedicated `save` ticket-gate profile.

## Verification

- `verify_save_001`: PASS.
- `verify_save_003`: PASS.
- Fresh parser/runtime smoke: PASS.
- Fresh SAVE-003 log has no active null-material error.
- Known isolated-process shutdown diagnostics remain classified lifecycle debt
  by QA-005; they are not suppressed by this ticket.

## Running steps

```powershell
cd C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns
$env:GODOT_BIN = 'C:\Temp\AshenOathGodot4.6.3\Godot_v4.6.3-stable_win64_console.exe'
& .\tools\run_ticket_gate.ps1 -Profiles save -NoCache
```
