# QA-013 Result - Reproducible Live Baseline Ledger

## Status

`verified`

QA-013 now has a machine-readable baseline ledger for loading, transitions,
zone performance, memory, node counts, draw calls, primitives, and the nine
required visual views. The exact camera set was freshly recaptured against the
current branch on 2026-08-26 at 1280x720 gameplay and 1920x1080 menu. The
frames are current technical evidence, not final visual approval.

## Changes

- Added `qa_013_baseline_manifest.json` with the baseline anchor, environment,
  required view list, timings, per-zone metrics, evidence sources, and known
  debt.
- Added `tools/verify_qa_013.py` to check evidence paths, image dimensions,
  nonblank images, timings, zone metrics, and the historical/current boundary.
- Registered the QA-013 gate in the ticket profile and static Python runner.

## Verification

- `QA-013` baseline verifier: PASS - current evidence intact; final visual
  review remains separate.
- Current source report and all nine recaptured images: present and readable.
- Baseline anchor: QA-SOUL-001 at 1280x720 gameplay / 1920x1080 menu.
- Godot 4.6.3 Compatibility recapture completed with ANGLE Intel HD 620.
- Current scene-ready timing: 10005.8 ms; Greyfen/New Game: 6069.6 ms;
  Wychwood transition: 668.4 ms; Castle approach: 388.5 ms; Hart Glade:
  290.9 ms.

## Known Limitations

- This ticket is not visual approval. Character/world visual acceptance remains
  a later gate and the current captures visibly retain provisional geometry.
- Current Greyfen 1% low measured 14.2 FPS during the short capture sample;
  this is evidence for later performance work, not a release pass.
- Physical gamepad, Firefox, and fresh browser-route measurements remain open.

## Running Steps

```powershell
cd C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns
& "C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" tools\verify_qa_013.py .
```
