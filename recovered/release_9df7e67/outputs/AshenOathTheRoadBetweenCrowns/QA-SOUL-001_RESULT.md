# QA-SOUL-001 Result

## Changes

- Added a deterministic nine-view graphical baseline capture for menu, characters, opening world, combat, Castle, and Hart Glade.
- Added a compact runtime report covering startup, transitions, FPS, memory, nodes, draw calls, primitives, and active materials.
- Added an automated image/report verifier and a truthful historical/current evidence ledger.
- Preserved old screenshots as historical evidence; no original-state image was fabricated or regenerated.

## Verification

- Graphical capture: pass at 1920x1080 for the menu and 1280x720 for gameplay.
- Automated dimensions, nonblank image, timing, measurement, and evidence checks: pass.
- Codex visual review: complete; current defects are recorded in `QA_SOUL_001_TRUTHFUL_BASELINE.md`.

This is a baseline ticket, not a visual approval. Current New Game timing, opening 1% lows, character framing, Castle detail, and Hart presentation remain below the roadmap acceptance targets.

## Running

From the project root:

```powershell
& "C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe" --path . --rendering-method gl_compatibility --script tools/capture_qa_soul_001.gd
& "C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" tools/verify_qa_soul_001.py .
```

No Web export or production deployment is part of this recovery gate.
