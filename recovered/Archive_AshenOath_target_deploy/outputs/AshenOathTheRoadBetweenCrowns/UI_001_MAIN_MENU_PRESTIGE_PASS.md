# UI-001 Main Menu Prestige Pass

## Files Changed

- `scripts/hud.gd`
- `scripts/audio_manager.gd`
- `scripts/game.gd`
- `tools/capture_main_menu_screenshot.gd`

## Visual Changes

- Rebuilt the main menu into a dark-fantasy presentation with a large `ASHEN OATH` title, `The Road Between Crowns` subtitle, atmospheric ash, Wychwood/village silhouettes, cold moon tone, and warm shrine-like glow.
- Added a responsive two-column layout with title/build text on the left and a clean vertical menu on the right.
- Added bottom-corner build text: `UI-001 | 2026-06-22 | ashenoath.vercel.app`.

## Button Changes

- Restyled menu buttons with custom dark panels, gold borders, hover underline, pressed state, and disabled state.
- Main menu now includes `New Game`, `Continue`, `Controls`, `Settings`, `Credits`, and `Quit`.
- `Continue` is disabled when no manual, autosave, or checkpoint save exists.

## Audio Changes

- Added lightweight procedural `menu_hover`, `menu_click`, and `main_menu` music cues.
- Menu hover/click signals are routed through the existing audio manager and respect master volume.
- No external audio assets were added.

## Screenshot Paths

- `verification_screenshots/ui_001_main_menu_prestige_2026-06-22_121400.png`
- `Development_Gallery/screenshots/UI_001_Main_Menu_Prestige_2026-06-22_121400.png`

## Verification Results

- `verify_runtime.gd`: passed.
- `verify_visible_quality.gd`: passed.
- `capture_main_menu_screenshot.gd`: passed.

## Export Result

- Web export passed and synced into the root `web/` folder.
- Final web build size after UI-001: `45,353,708` bytes, about `43.3 MB`.

## Commit Hash

- `75aac84 UI-001: main menu prestige pass`

## Deployment Status

- Pushed to `origin/main`.
- Vercel auto-deploy trigger expected for `https://ashenoath.vercel.app/`.
