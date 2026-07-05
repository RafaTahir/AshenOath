# UI-002 - Main Menu 1080p Pass

## Files Changed
- `project.godot`
- `scripts/hud.gd`
- `scripts/game.gd`
- `scripts/settings_manager.gd`
- `tools/capture_main_menu_screenshot.gd`
- `tools/verify_runtime.gd`
- `tools/verify_visual_003.gd`
- `PROJECT_STATE.md`

## Improvements
- Raised the UI canvas to 1920x1080 while retaining a 720p 3D budget for Balanced gameplay.
- Rebuilt the menu composition for 1080p with stronger typography, spacing, panel proportions, and responsive full-screen background layers.
- Increased button size, readability, keyboard focus visibility, and first-action focus behavior.
- Settings now show current values and refresh immediately after every change.
- Replaced Web `Quit`, which produced a black canvas, with a browser-safe `Exit Game` return to the launch screen.
- Continue remains visibly disabled when no save exists.

## Verification
Runtime, screenshot, Web export, packed startup, and production deployment results are recorded during finalization.
