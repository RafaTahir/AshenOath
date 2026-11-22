# QA-003 Source-Bound Screenshot and Codex Visual Review

## Delivered

- `tools/verify_screenshot_qa_003.py` verifies the current gallery evidence without changing it.
- `Development_Gallery/qa_003_approval_manifest.json` records required views, approval state,
  reviewer, note, expected dimensions, lightweight exposure checks, and optional baselines.
- `tools/visual_evidence.py` owns source/asset byte identity and the seven semantic review checks shared by QA-003, QA-006, and strict release reporting.
- Capture runners use `tools/capture_visual_provenance.py begin/finish` around a successful owned graphical capture. Source changes during capture, old unchanged images, failed capture processes, and changed PNG bytes cannot become current evidence.
- `tools/test_verify_screenshot_qa_003.py`, `tools/test_visual_evidence.py`, and `tools/test_visual_capture_cache.ps1` exercise normal and deliberate-failure cases. `tools/verify_capture_dressing.gd` checks complete scene/actor publication before capture.

## Commands

Ordinary ticket changed-view check, where pending review is allowed:

```powershell
& "C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" tools\verify_screenshot_qa_003.py . --mode ticket --views greyfen_spawn,wychwood_combat
```

Read-only manifest and capture resolution:

```powershell
& "C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" tools\verify_screenshot_qa_003.py . --mode ticket --dry-run
```

Milestone check. This fails closed until each required image has matching capture-time source/asset identity, exact approved PNG SHA-256, a Codex reviewer, and inspection notes/verdicts for anatomy, grounding, scale, materials, composition, route clearance, and role identity:

```powershell
& "C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" tools\verify_screenshot_qa_003.py . --mode milestone
```

Regression tests:

```powershell
& "C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" tools\test_verify_screenshot_qa_003.py
```

## Limits

The verifier rejects missing, content-stale, wrong-sized, black, flat, or severely overexposed images. Timestamp changes and documentation-only commits are not proof of changed rendering content. Configured perceptual baselines remain subject to explicit approval. Dry-run output is PLAN, never release PASS.

Pixel checks cannot establish artistic quality. Codex must actually inspect the frame and record a specific verdict for every semantic check; provenance alone never grants approval. A staged screenshot is not real-input route evidence. The gate rejects pending or rejected milestone views rather than rewriting them as approved.

Recovery-004 QA-003 gate construction is accepted at the scope in `QA_003_RESULT.md`; all eleven freshly inspected game frames are rejected and production remains blocked. Rejected images cannot become approved artistic baselines. No export, production synchronization, commit, push, or deployment is authorized by this document.
