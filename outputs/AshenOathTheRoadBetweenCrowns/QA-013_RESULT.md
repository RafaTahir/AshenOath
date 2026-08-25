# QA-013 Result - Reproducible Live Baseline Ledger

## Status

`functional_but_incomplete`

QA-013 now has a machine-readable baseline ledger for loading, transitions,
zone performance, memory, node counts, draw calls, primitives, and the nine
required visual views. The ledger reuses the preserved QA-SOUL-001 evidence and
labels every image as historical. It does not claim that the current branch
has been freshly captured or visually approved.

## Changes

- Added `qa_013_baseline_manifest.json` with the baseline anchor, environment,
  required view list, timings, per-zone metrics, evidence sources, and known
  debt.
- Added `tools/verify_qa_013.py` to check evidence paths, image dimensions,
  nonblank images, timings, zone metrics, and the historical/current boundary.
- Registered the QA-013 gate in the ticket profile and static Python runner.

## Verification

- `QA-013` baseline verifier: PASS - historical evidence intact; fresh
  graphical recapture remains required.
- Preserved source reports and all nine baseline images: present and readable.
- Baseline anchor: QA-SOUL-001 at 1280x720 gameplay / 1920x1080 menu.
- Godot 4.6.3 is now provisioned in the external runtime cache, but the fresh
  graphical recapture was not run as part of QA-013 and remains open.

## Known Limitations

- This ticket is not visual approval. The next graphical-capable run must
  regenerate the nine views against the current source and update the ledger.
- Historical opening measurements include slow scene-ready and transition
  samples; those values are intentionally retained as optimization targets.
- Physical gamepad, Firefox, and fresh browser-route measurements remain open.

## Running Steps

```powershell
cd C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns
& "C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" tools\verify_qa_013.py .
```
