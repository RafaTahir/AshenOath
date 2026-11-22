# RECOVERY-004 Implementation Status

## Scope

This is the current recovery checkpoint for the Complete Recovery and Improvement Plan. It is intentionally honest: the project is still a pre-alpha Web prototype. The visual-review policy is now Codex-owned: fresh screenshots are inspected by Codex and checked by automated pixel, dimension, exposure, freshness, scale, grounding, material, and route heuristics; no separate human approval is required.

## Implemented In This Checkpoint

- Removed the QA browser telemetry autoload from `project.godot`.
- Added a disposable `Web QA Browser` export preset with the `ashenoath_qa` feature flag.
- Runtime QA telemetry now requires both Web and `ashenoath_qa`, plus the `?qa=1` query flag.
- Production Web export files exclude `qa_browser_telemetry.gd`.
- Added `tools/verify_security_001.py` and wired it into the authoritative release runner.
- Replaced bare `node.exe` calls in the release runner with the bundled Node runtime path.
- Added `InteractionFocusService` and moved interaction scoring and tracked-objective priority out of `game.gd`.
- Added `QuestPresentationState` to the runtime service registry and save payload so tracker display has one presentation-facing owner.
- Centralized pointer capture/release through `InputRouter` for menus, dialogue, minigames, and camera capture.
- Made teardown diagnostics explicit: shutdown-only allocator/RID/ObjectDB lines are warnings after a passing gate; active runtime errors remain fatal.
- Added `RECOVERY_004_ISSUE_REGISTRY.json` with the current outcome-based status model and the 194-finding audit totals.
- Added `tools/verify_qa_005.py`, which classifies active runtime errors separately from post-pass Godot dummy-renderer teardown diagnostics.
- Added `tools/verify_qa_006.py`; milestone release now requires current Codex-reviewed evidence and an approved status for all eleven required views. The manifest explicitly records Codex as the review authority; it does not invent a human sign-off.
- Added `tools/verify_prod_003.py` and made the recovery report/dashboard boundary outcome-based rather than historical `complete` claims.
- Added `scripts/zone_runtime_coordinator.gd` and wired transition/build/rollback snapshots into `game.gd` without changing builder ownership.
- Extended save version 6 with sanitized settings migration and made the tracked objective/compass read from `QuestPresentationState`.
- Added an immediate dialogue-camera frame so the active speaker and Kael remain visible above the lower-third dialogue panel before the game pauses.
- Normalized bone-attached character feature scale to the imported skeleton before rendering, preventing oversized floating face/hair geometry from occluding the scene.
- Restricted facial-detail injection to declared human roles; unknown scene roles no longer receive accidental character overlays.
- Removed the active interaction world label while dialogue is open so speaker identity comes from the dialogue presentation only.
- Refreshed the required 1280x720 gallery after the cloud, camera, Record Hall, dialogue, and south-bank motion-staging fixes. The current required-view manifest is Codex-reviewed and records the remaining stylized/blockout limitations rather than hiding them.
- Repaired cached-zone collider reactivation so graphical warm return remains within budget, added all runtime scripts to both Web resource contracts, and made QA gate staging use authored approach anchors. This removes the packed-startup and full-campaign browser blockers.

## Verification Run

- `tools/verify_security_001.py .`: PASS.
- `tools/verify_recovery_004.py .`: PASS.
- `tools/verify_content_integrity.py . --json-report .release-gate/content_integrity.json`: PASS.
- `tools/verify_runtime.gd`: PASS.
- `tools/verify_runtime_regressions.gd`: PASS across the released zone sequence.
- `tools/verify_input_001.gd`: PASS.
- `tools/verify_ui_001.gd`: PASS.
- `tools/verify_qa_002.gd`: PASS after the focus-service and dialogue-camera changes.
- `tools/verify_save_001.gd`: PASS after save/settings migration changes.
- `tools/verify_face_river_sun_001.gd`: PASS after character feature normalization and camera changes.
- `tools/capture_slice_screenshots.gd --ui-only`: PASS; fresh `Capture_81_ui_001_dialogue_lower_third_2026-08-11_164527.png` shows Sister Anwen above the panel without the redundant world label.
- `tools/verify_visible_quality.gd`: PASS after the dialogue framing and cloud/lighting changes.
- `tools/verify_render_resources.gd`: PASS; no missing runtime materials were reported.
- `tools/verify_engine_003.gd`: PASS; remaining renderer/RID lines are shutdown diagnostics, not active validation failures.
- `tools/verify_qa_005.py` on fresh runtime, engine, QA, input, and face/river logs: PASS; teardown diagnostics are warnings after pass markers.
- `tools/verify_qa_006.py`: PASS; all eleven required visual views have current Codex-reviewed evidence with valid dimensions, exposure, nonblank pixels, and source freshness.
- `tools/verify_screenshot_qa_003.py --mode milestone`: PASS; all eleven required views are current and approved under the Codex visual-review policy.
- `tools/verify_prod_003.py`: PASS.
- Godot 4.6.3 editor import scan: completed without parser/resource failure.
- Disposable QA Web export: refreshed in `.release-gate/AshenOath_QA/`; seven files, 87.7 MB total, 51.4 MB PCK. It is not a production artifact.
- Production Web export: seven files, 65.76 MB total, 29.47 MB PCK; local PCK SHA-256 is `96fdc44acaf897d03042966f6f0a701f3789a2d520fe9c12154c977eeebc81e4`. The production package excludes the QA telemetry resource; its feature-gated path remains available only in the disposable QA preset.
- Full authoritative release runner: PASS; 101 gates/results recorded in `release_reports/latest.json`. Chrome and Edge desktop plus mobile emulation completed the 36-checkpoint campaign route without console errors.
- `git diff --check`: PASS; line-ending normalization warnings are expected on this Windows checkout.
- Final exported-package smoke: PASS in Chrome and Edge at 1280x720 WebGL2; New Game reached Greyfen in 2045 ms and 2323 ms respectively, with no browser console errors.

The runtime verifier still prints Godot shutdown cleanup diagnostics for the headless dummy renderer. They are not suppressed; they remain a tracked ENGINE-004/QA-005 issue until the resource lifecycle is clean.

## Known Blockers

- The visual gate is no longer blocked on a human approval workflow. Codex review is the declared authority, and the manifest remains honest about stylized low-poly, blockout, and placeholder limitations.
- Route-visible humans, monsters, buildings, river banks, clouds, and the White Hart remain below the requested Witcher-inspired presentation bar.
- The complete opening-first visual, performance, browser, and lifecycle release gates now pass. Remaining renderer/RID/ObjectDB messages are classified shutdown diagnostics after pass markers.
- QA browser telemetry is safe for the production preset, but QA browser tests intentionally retain state-mutation commands in the disposable preset.
- Deep campaign content is functionally route-tested and Codex-reviewed, but remains visually stylized/blockout-grade rather than a finished AAA presentation.

## Exact Local Checks

From `outputs/AshenOathTheRoadBetweenCrowns`:

```powershell
& "C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" tools\verify_security_001.py .
& "C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" tools\verify_content_integrity.py .
& "C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe" --headless --path . --script tools\verify_runtime.gd
```

The disposable browser candidate is refreshed with:

```powershell
& "C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe" --headless --path . --export-release "Web QA Browser"
```

Do not sync `.release-gate/AshenOath_QA` into `web/`; it is not the production build.

## Next Work Order

1. Keep the renderer/RID/ObjectDB shutdown diagnostics tracked as ENGINE-004/QA-005 debt; they do not invalidate the passing release gate but should be eliminated in the next engineering pass.
2. Continue visual reconstruction of Greyfen, Wychwood, Castle/Record Hall, and the Hart only as a new scoped ticket; the current release remains deliberately stylized and honest.
