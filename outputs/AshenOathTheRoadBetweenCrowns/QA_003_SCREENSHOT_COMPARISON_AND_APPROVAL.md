# QA-003 Screenshot Comparison and Manual Visual Approval

## Delivered

- `tools/verify_screenshot_qa_003.py` verifies the current gallery evidence without changing it.
- `Development_Gallery/qa_003_approval_manifest.json` records required views, approval state,
  reviewer, note, expected dimensions, lightweight exposure checks, and optional baselines.
- `tools/test_verify_screenshot_qa_003.py` exercises the verifier against committed gallery images.

## Commands

Ordinary ticket changed-view check, where pending review is allowed:

```powershell
& "C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" tools\verify_screenshot_qa_003.py . --mode ticket --views greyfen_spawn,wychwood_combat
```

Read-only manifest and capture resolution:

```powershell
& "C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" tools\verify_screenshot_qa_003.py . --mode ticket --dry-run
```

Milestone check. This fails closed until every required manifest entry has a human `approved`
status plus non-empty reviewer and note metadata:

```powershell
& "C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" tools\verify_screenshot_qa_003.py . --mode milestone
```

Regression tests:

```powershell
& "C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" tools\test_verify_screenshot_qa_003.py
```

## Limits

The verifier can reject missing, stale, wrong-sized, black, flat, or severely overexposed images.
It can also enforce a configured mean absolute pixel difference against an explicitly approved
baseline. It cannot decide whether a scene is artistically good; that remains the required human
approval recorded in the manifest. QA-003 does not change screenshot capture, gate profiles,
release scripts, gameplay, zones, export output, or deployment.
