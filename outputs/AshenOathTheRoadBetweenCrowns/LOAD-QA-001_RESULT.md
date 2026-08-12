# LOAD-QA-001 Result

## Changes

- The Web boot shell remains the first meaningful paint and includes the interactive Crow's Crossing activity, keyboard/pointer/touch handling, gamepad polling, progress text, retry state, and reduced-motion fallback.
- Added a delayed in-game transition vignette. It stays hidden for 750 ms, uses a restrained translucent road card, ignores mouse input, and is dismissed on successful or failed recovery. Ordinary fast transitions retain the last rendered frame without a flash.
- Added static acceptance checks for the shell, runtime-pack budget, transition hooks, gamepad loading input, and reduced-motion behavior.

## Verification

- `tools/verify_load_qa_001.py`: PASS.
- `tools/run_ticket_gate.ps1 -Profiles loading -NoCache`: PASS.
- Passed content integrity, runtime smoke, loading contract, runtime regressions, stream, portal, Web export, export validation, and packed startup.
- The verified local Web artifact remains below the 100 MB policy.

## Running Steps

```powershell
cd "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns"
& .\tools\run_ticket_gate.ps1 -Profiles loading -NoCache
```

For browser startup, serve `..\AshenOath_Web` with the bundled Python HTTP server and open `http://127.0.0.1:8787/`. The first page is the Crow's Crossing shell; click `Enter the Road`, collect embers with A/D, arrow keys, pointer/touch, or a connected gamepad, and wait for the Godot menu.

## Limitations

The Web shell is interactive during WASM startup. Zone construction is still partly procedural, so the vignette is a fallback for future time-sliced transitions rather than a claim that all current synchronous builder work is already threaded.
