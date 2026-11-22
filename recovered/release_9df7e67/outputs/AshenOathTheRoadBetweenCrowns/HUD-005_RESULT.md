# HUD-005 Result

## Changes

- Added responsive gameplay HUD anchoring for tracker, compass, prompt, combat status, dialogue, inventory, and notifications.
- Kept the gameplay canvas at native 1280x720 while preserving the 1920x1080 menu canvas.
- Updated the menu identity to `SOUL REBUILD | DEVELOPMENT CANDIDATE` so
  development builds cannot present themselves as the final release.
- Added a complete main-menu `Quit` action. Desktop builds exit through Godot;
  Web builds show a browser-safe departure notice instead of pretending they
  can close the tab.
- Preserved keyboard, mouse, touch, and gamepad labels, pagination, focus, accessibility contrast, and subtitle scaling.

## Verification

- verify_hud_005.gd: PASS
- Product ticket gate: PASS (`verify_hud_005`, `verify_audio_007`,
  `verify_access_003`, `verify_perf_008`, `verify_qa_012`)

## Screenshots

- Fresh product evidence was regenerated in
  `Development_Gallery/screenshots/HUD_005_MainMenu_1080p_20260821_152839.png`,
  `SOUL_REBUILD_Greyfen_Current_20260821_152844.png`, and
  `SOUL_REBUILD_HartGlade_Current_20260821_152845.png`.
- A full release screenshot refresh remains part of the Milestone G release gate.

## Known limitation

This ticket does not claim final visual approval of every campaign HUD composition; the complete real-input screenshot review remains QA-012/RELEASE-003.

## Running steps

From the project directory:

    .\tools\run_ticket_gate.ps1 -Profiles product -NoCache
