# LOAD-QA-002 Result - Startup and Cache Acceptance

## Status

`verified` for the Milestone-A startup and cache contract.

## Changes

- Added a deterministic boot/cache acceptance verifier covering the six-pack
  metadata, byte budget, candidate hash agreement, embedded fallback, and the
  RuntimePackManager temporary-file, validation, retry, cancel, mount, and cache
  contracts.
- Added an optional external-candidate path for validating the clean-room PCK
  cache without copying raw artifacts into the repository.
- Added the `milestone_a` ticket profile, including boot, loader, stream, pack,
  scene, runtime, Web export, and browser gates.

## Verification

- `verify_load_qa_002.py`: metadata and lifecycle contract gate.
- `verify_stream_003.gd`: embedded and external PCK lifecycle gate.
- Full Milestone-A run: PASS for all configured implementation, export,
  packed-startup, and browser gates.

## Limitations

Chrome and Edge browser smoke both reached Greyfen at 1280x720 WebGL2 with no
console errors. Engine readiness measured 8.30 seconds in Chrome and 9.07
seconds in Edge; New Game event timing measured 5.81 and 6.32 seconds after
prewarm. The internal prewarmed activation marker completes in roughly 100 ms;
the software-browser event-to-frame cost and typical cold-start optimization
remain documented follow-up. The candidate publishes five relative packs and
keeps the embedded base PCK as fallback.

## Running Steps

```powershell
cd "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns"
& "C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" tools\verify_load_qa_002.py . `
  --candidate-dir "C:\Users\User\.cache\codex-runtimes\ashenoath-packs-v4"
```
