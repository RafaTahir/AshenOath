# QA-REPAIR-001 Screenshot and Visual Approval

## State

The recovery screenshot pass is complete, but this is not a final visual approval. The machine gate passes the fresh evidence; manual review still rejects the current art quality for milestone release.

## Files and Evidence

- Updated `scripts/game.gd` bridge recovery handling and static batch interpolation settings.
- Updated `scripts/world_vfx_controller.gd` to update weather motes on the physics tick with interpolation disabled for static-like particles.
- Updated `scripts/zone_spatial_service.gd` with authored same-bank recovery anchors.
- Updated `tools/capture_slice_screenshots.gd` with destination-zone readiness checks, river-only recovery proof, safe teardown, and corrected river-safe capture points, including the enemy-approach point moved out of the Wychwood channel.
- Updated `Development_Gallery/qa_003_approval_manifest.json` to source the fresh capture revision `801d890`.
- Fresh evidence is in `Development_Gallery/screenshots/` with timestamp `2026-08-11_004817`.

Required machine-reviewed views:

- Greyfen spawn, Sister Anwen dialogue, river bridge, Wychwood combat.
- Sword-ready, light attack, heavy attack, and blade-contact frames.
- Castle approach, Record Hall, and Hart Glade.

## Commands Run

```powershell
& "C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64.exe" --path . --rendering-method gl_compatibility --display-driver windows --script res://tools/capture_slice_screenshots.gd
& "C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" tools\verify_screenshot_qa_003.py . --mode ticket --report .release-gate\qa_003_ticket_report.json
& "C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" tools\test_verify_screenshot_qa_003.py
```

Results:

- Full route capture: PASS, including the corrected enemy-approach frame and the relocated Anwen staging.
- Screenshot dimensions/nonblank/exposure/freshness: PASS for all 11 required views.
- QA-003 regression tests: PASS, 5 tests.
- River recovery proof: PASS; forced recovery lands on a clear same-bank road anchor and the bridge remains a walkable route.
- Strict graphical performance: PASS; Greyfen 46.73 FPS average / 30.25 FPS 1% low, all other required zones above 32/30, warm return 318.7 ms, cold transitions below 458 ms.

## Manual Review Result

Pending/rejected for release. The current images still show low-poly temporary humans and scenery, non-portrait dialogue staging for Anwen, blockout-grade Castle and Record Hall architecture, and an underdeveloped procedural White Hart. These are visible quality failures, not verifier failures.

The latest capture also leaves Godot renderer/RID/ObjectDB cleanup diagnostics during process teardown. No active null-material error appeared during gameplay after the safe teardown change, but the lifecycle warning class is still open.

## Running Steps

From the project root:

```powershell
cd "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns"
& "C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64.exe" --editor project.godot
```

For the local Web candidate, serve `outputs/AshenOath_Web` with the bundled Python and open `http://127.0.0.1:8787/index.html`.

## Remaining Work

1. Finish renderer/resource retirement so the capture and release runners exit without teardown diagnostics.
2. Replace or properly author the route-visible human, monster, Castle, and Hart presentation; then obtain human approval for all 11 required views.
3. Only after those gates pass, run the milestone release export, sync `web/`, push `main`, and deploy Vercel.
