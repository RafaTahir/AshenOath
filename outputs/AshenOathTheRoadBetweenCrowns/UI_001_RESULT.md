# UI-001 Result - Honest Boot and Quiet HUD

Status: accepted for the UI-001 contract on 2026-09-24. This is not a release or performance acceptance.

## Delivered

- Replaced the polygon menu backdrop with Greyfen-specific artwork. The retained source image is `assets_external/ui/greyfen_menu_concept.png`; the compact Web derivative is `assets_external/ui/greyfen_menu_runtime.jpg`.
- Kept boot transfer progress below 100% until the opening-ready state. New Game remains available during prewarm and can be activated by mouse alone.
- Kept the gameplay HUD compact at 1280x720 and readable after a 1920x1080 browser resize. The objective tracker, compass, interaction prompt, and dialogue use the shared objective/focus state.
- Made root and opening-pack resource inclusion explicit. The opening pack includes all twelve texture atlases referenced by its retained prop models; the Web presets include the menu image and the exact opening runtime materials they need. `tools/verify_web_bootstrap_pck.gd` checks these dependencies from an isolated packed runtime.
- Extended `tools/verify_web_browser.mjs --ui-acceptance` to exercise Settings pages 1-3, mouse-only New Game, full Greyfen presentation, and browser resize. It retains console/resource diagnostics and screenshots.

## Verification

- Focused native `verify_ui_001.gd`, `verify_quest_001_runtime.gd`, and `verify_hud_005.gd`: pass. Static `verify_web_preset_parity.py`: pass.
- Isolated packed bootstrap and opening-pack resource checks: pass.
- Source-aligned QA export: 15 files, 99.1 MB, root PCK SHA-256 `fb22ff3b61b73772950d645503f1abf5c1b304928aace545b76c167383f5ccd5`; `verify_web_export.py`: pass.
- Chrome and Edge: native 1280x720 WebGL2; Settings opened by mouse; all three pages reached; New Game started by mouse alone; Greyfen detail completed; 1920x1080 resize and 1280x720 restoration worked; zero console or resource errors. Evidence: `D:/Temp/AshenOath/ui001_chrome_allpages.json` and `D:/Temp/AshenOath/ui001_edge_allpages.json`.
- Inspected the menu, three Settings pages, hydrated 720p gameplay, and 1080p gameplay captures. Controls, Back actions, title, HUD, objective, and prompt are in frame without incoherent overlap. Screenshots are under `D:/Temp/AshenOath/ui001_{chrome,edge}_allpages*.png` and are not included in the Web payload.

## Boundaries

- This does not approve Greyfen/Wychwood world art, full-route input, native FPS, startup latency, or production deployment. The current QA artifact is close to the 100 MB ceiling; later asset changes require a fresh payload check.
- Browser startup measurements in this UI run were Chrome 11.7 seconds and Edge 10.8 seconds to engine readiness. They are observations, not a fresh cold/warm loading certification.
- Godot's custom texture import settings for the three root images and twelve opening prop atlases must remain tracked for reproducible payload size.

## Local Run

From `D:\Projects\AshenOath\outputs\AshenOathTheRoadBetweenCrowns`, run `tools/verify_web_preset_parity.py`, export the `Web QA Browser` preset into `D:\Projects\AshenOath\outputs\.release-gate\AshenOath_QA`, sync the current opening PCK and runtime manifest, run `tools/verify_web_export.py`, then run `node tools/verify_web_browser.mjs --export ..\.release-gate\AshenOath_QA --browser chrome --ui-acceptance --report D:\Temp\AshenOath\ui001_chrome.json` and repeat with `--browser edge`.

No commit, push, merge, or deployment was performed for this acceptance.
