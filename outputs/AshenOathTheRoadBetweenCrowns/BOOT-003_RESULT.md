# BOOT-003 Result - Single Immediate Browser Boot

## Status

`functional_but_incomplete` pending the Milestone-A browser/export release gate.

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

The current playable source remains an embedded PCK. Cold engine readiness was
measured at 42.94 seconds in Chrome and 27.11 seconds in Edge, above the
8-second typical and 12-second hard targets. Hosted split-pack URLs and
production deployment remain intentionally deferred.

## Running Steps

```powershell
cd "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns"
& "C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" tools\verify_boot_003.py .
```
