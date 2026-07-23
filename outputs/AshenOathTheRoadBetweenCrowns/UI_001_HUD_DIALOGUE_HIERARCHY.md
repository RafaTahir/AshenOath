# UI-001 HUD and Dialogue Hierarchy

## Scope

- Reduced the gameplay HUD footprint and strengthened the visual hierarchy at 720p.
- Rebuilt dialogue as a lower third with a single speaker heading and page progress.
- Prioritized the tracked quest in compass focus instead of nearby incidental NPCs.
- Corrected Sister Anwen's source-facing offset during approach and dialogue staging.

## Files

- `scripts/hud.gd`
- `scripts/game.gd`
- `scripts/npc_ambient.gd`
- `tools/verify_ui_001.gd`
- `tools/capture_slice_screenshots.gd`
- `tools/run_release_gate.ps1`

## Acceptance

- Compact HUD panels do not dominate the play view.
- Dialogue releases the mouse and remains below the central action area.
- The current tracked objective controls compass priority.
- Sister Anwen visibly faces Kael on approach and throughout dialogue.
- UI-001 screenshots are written to `Development_Gallery/screenshots/`.

## Verification

- `verify_ui_001.gd`: PASS.
- Authoritative release gate: PASS.
- Native 720p performance: 40.7 FPS average, 38.8 FPS minimum.
- Web export: PASS, 7 files, 63.5 MB.
- Packed Web startup: PASS.

## Screenshots

- `Development_Gallery/screenshots/Capture_79_ui_001_hud_hierarchy_2026-07-23_103721.png`
- `Development_Gallery/screenshots/Capture_80_ui_001_anwen_approach_2026-07-23_103721.png`
- `Development_Gallery/screenshots/Capture_81_ui_001_dialogue_lower_third_2026-07-23_103721.png`
