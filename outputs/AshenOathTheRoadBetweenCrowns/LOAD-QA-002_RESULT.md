# LOAD-QA-002 Result - Startup and Cache Acceptance

## Status

`functional_but_incomplete` pending the Milestone-A browser/export release gate.

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
console errors. Engine readiness measured 42.94 seconds in Chrome and 27.11
seconds in Edge; New Game after the Greyfen readiness point measured 4.79 and
6.22 seconds respectively. These exceed the roadmap cold-start and New Game
budgets. The checked-in manifest keeps external URLs empty, so production uses
the embedded PCK fallback; the external v4 candidates remain outside the
repository until hosting and candidate promotion are complete.

## Running Steps

```powershell
cd "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns"
& "C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" tools\verify_load_qa_002.py . `
  --candidate-dir "C:\Users\User\.cache\codex-runtimes\ashenoath-packs-v4"
```
