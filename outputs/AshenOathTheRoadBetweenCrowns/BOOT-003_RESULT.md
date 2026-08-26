# BOOT-003 Result - Single Immediate Browser Boot

## Status

`verified` for the Milestone-A boot contract.

## Changes

- Kept the authored HTML shell as the first Web surface with no black frame.
- Removed the production QA telemetry script from the Web export filter.
- Added `window.__ashenOathBoot`, DOM boot-state markers, and performance marks
  for first paint, engine start, progress, and engine readiness.
- Preserved direct Web entry to the real Godot menu while Greyfen prewarming runs
  behind the menu; the desktop launch screen remains unchanged.

## Verification

- `verify_boot_003.py`: static contract gate.
- `verify_loadgame_002.py`: loader-input contract gate.
- Milestone-A aggregate gate: PASS for the configured implementation,
  export, packed-startup, and Chrome/Edge browser checks.

## Limitations

The current candidate uses an embedded base PCK plus five relative streamed
packs. Cold engine readiness measured 8.30 seconds in Chrome and 9.07 seconds
in Edge; the 8-second typical target remains a documented optimization
follow-up, while the 12-second hard ceiling passed. Production promotion is
the remaining milestone action.

## Running Steps

```powershell
cd "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns"
& "C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" tools\verify_boot_003.py .
```
