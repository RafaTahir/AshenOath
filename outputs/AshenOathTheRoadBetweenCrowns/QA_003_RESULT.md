# QA-003 - Source-Bound Semantic Visual Gate

## Acceptance Scope

Accepted 2026-09-27 as the visual evidence/decision gate, not as approval of the
game's appearance. This follows the executable QA-003 contract: current rendering
identity, scale/grounding/role/route review, and rejection of pending/stale evidence.
All eleven actual mandatory frames were inspected and rejected. WORLD-001,
WORLD-002, PRES-001, PERF-001, CERT-001 and RELEASE-001 remain blocked at their
own scopes. No deployment, export or game behavior change is part of this ticket.

## Changes

- Shared `tools/visual_evidence.py` hashes actual scripts, scenes, data, role/pack
  manifests and runtime asset bytes. Preserved timestamps cannot hide changes.
- `tools/capture_visual_provenance.py` brackets successful owned captures; source
  changes, failed runs and unchanged old images cannot acquire new provenance.
- QA-003, QA-006 and strict release reporting use the same capture/review contract.
  Seven explicit checks cover anatomy, grounding, scale, materials, composition,
  route clearance and role identity. No automatic artistic approvals are written.
- Dry runs report PLAN, never PASS. Perceptual comparison still requires an
  explicitly approved baseline; rejected game frames are not quality baselines.
- Ticket/release captures record identity before/after; transient provenance
  operations cannot erase unrelated cached green results.
- Screenshot fixtures wait for complete staged opening/actor dressing. Fully
  built roots do not require staged-only metadata. Mandatory generic captures
  stop at the first failed view. Runtime errors after a PASS remain fatal.

## Evidence

- Thirteen controlled `test_visual_evidence.py` cases PASS, including preserved-
  timestamp asset changes, mid-capture source changes, old-image laundering,
  byte tampering, missing semantic notes, pending review, black frames, perceptual
  regression and non-accepting dry runs. These are synthetic gate tests, not
  game appearance approval.
- Six existing QA-003 contract tests PASS; capture cache isolation PASS; both
  affected PowerShell parsers PASS.
- `verify_capture_dressing.gd` PASS for full, staged and deferred-role roots.
- Initial `qa003_required_20260927` run is FAILED: a full Greyfen root was
  incorrectly tested as staged. No completed provenance was attached to that run.
- Corrected `qa003_required_v2_20260927.log/.err` exit 0, no active/shutdown errors
  (Intel OpenGL-to-ANGLE advisory only). Eleven fresh 1280x720 native fixtures
  have successful begin/finish identity. Rendering digest:
  `4be072ee2cd04b2fea931ce24ece0bc65faa9bf1aaa2fa77f5b5d0d500ca1c11`.
- `D:/Temp/AshenOath/qa003_required_v2_20260927/pixel-identity.json` records exact
  inspected hashes, dimensions and pixel metrics. Capture provenance is positive;
  artistic decisions are all REJECTED in the gallery manifest.
- Actual milestone QA-003 and QA-006 both exit 1 for those rejections. Skipped
  identity comparisons are reported as unverified, never fabricated mismatches.

## Visual Findings

Greyfen has disconnected market pieces and floating panels; bridge banks remain
weak. Dialogue hides Anwen and several staged Greyfen views retain Wychwood
guidance. Sword-ready does not clearly show a drawn weapon; contact is obscured
by actor overlap. Castle retains a blank central slab and repetitive empty walls;
Record Hall is improved but sparse and its staged guidance is inappropriate.
The Hart is a complete antlered actor, but the surrounding finale is visually weak.
These are explicit downstream repair inputs, not automatically inferred gameplay
regressions from visual staging. Current accepted actor/route contracts are not
silently reopened or replaced by these fixtures.

## Running Steps

From `D:/Projects/AshenOath/outputs/AshenOathTheRoadBetweenCrowns`:

```powershell
$python = 'C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
& $python tools/test_visual_evidence.py
& $python tools/test_verify_screenshot_qa_003.py
powershell -ExecutionPolicy Bypass -File tools/test_visual_capture_cache.ps1
& $python tools/verify_screenshot_qa_003.py . --mode milestone
```

The last command intentionally fails while the current frames remain rejected.
Use source-bound capture begin/finish around a successful graphical capture before
reviewing future changed views. Staged captures never substitute for real input.
No checkpoint commit, push, merge, production synchronization or deployment.
