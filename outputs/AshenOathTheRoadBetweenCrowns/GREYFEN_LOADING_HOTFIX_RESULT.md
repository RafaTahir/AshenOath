# Greyfen Loading Hotfix

## Fix

- Require the verified opening pack before Greyfen preparation, with visible startup failure and an explicit retry resetting failed download attempts.
- Prepare settlement geometry, river, roads, houses, horizon, shrine, forge, cemetery and opening landmarks behind the existing cover on Web and desktop.
- Publish `opening_presentation_ready` only after essential stages, required scenery checks and a draw from the actual gameplay camera. New Game cannot consume an incomplete cache.
- Keep the menu input guard; explicitly position the camera during covered preparation. Preserve continuous orbit and first-person zoom.
- Remove the movement-dependent scenery delay. Track completed stages on the cached zone so resumed work does not duplicate content.
- Re-enroll deferred named actors into village routines without duplicate registrations.

## Focused Verification

- Opening pack readiness state contract: PASS.
- Graphical moving-player hydration and completed-stage resumption: PASS.
- Graphical complete Greyfen detail, seven Balanced routines, keyboard bridge crossing and return without jump/recovery: PASS.
- Graphical camera orbit, first person and menu-covered preparation: PASS.
- Native screenshot inspected: `D:/Temp/AshenOath/opening_detail_balanced_spawn.png`.
- Native logs: `D:/Temp/AshenOath/greyfen-loading-{native,detail,camera}.log`.
- Production Web export: PASS, 14 artifacts, 86.3 MiB. Existing content-addressed packs are unchanged.
- Fresh hardware Chrome: PASS, 1280x720 WebGL2, real mouse-only New Game, first-control scenery capture, keyboard bridge crossing, no console errors. Engine readiness measured 18,421 ms; the visible-menu click occurred 57,966 ms after navigation; prewarmed New Game took 111.7 ms. Cold preparation is still slow, but no longer exposes a bare playable landscape. These are separate measurements, not a claim that total cold startup meets the historical target.
- Browser fixture corrected for the covered menu and current observer vector/interaction schema. The terminal boolean flag parser also now treats an unvalued final flag as true.
- Source checkpoint: `f625f5923ce3ce140f375da99197885805d27e48`.
- Root PCK SHA-256: `0feab7f4d523618c133f7da323537aca55bccc5a9e83de1a23900592a12639ef`.
- Build ID: `greyfen-f625f5923ce3`.
- Browser evidence: `release_reports/greyfen_loading_fix_20261003/chrome-final.json` and matching first-control capture.
- Deployment: `3f5e4b3` pushed to development and main, published by Vercel. All 14 live artifact SHA-256 hashes match the local release manifest, including the root PCK and all six content packs.
- Live fresh hardware Chrome: PASS at `https://ashenoath.vercel.app/?v=greyfen-loading-3f5e4b3`; mouse New Game, first-control village capture, keyboard bridge crossing, Anwen focus/dialogue (six pages), control restored, no console errors. Engine readiness 12,758 ms; visible-menu click at 42,987 ms after navigation; prewarmed New Game 82.6 ms. Cold preparation remains a disclosed limitation.
- Live evidence: `release_reports/greyfen_loading_fix_20261003/production.json` and `production_first_control_chrome.png`. Temporary browser profiles were created under `D:/Temp/AshenOath` and cleaned by the smoke runner.

No art, story, save format or performance acceptance changes. A cold load must now finish essential scenery before control; this fix does not claim to eliminate download or shader preparation time. Extra population and small dressing still finish in bounded stages after control, even while moving.

## Running Steps

Production: open `https://ashenoath.vercel.app/?v=greyfen-loading-3f5e4b3`, click New Game, then walk across the bridge. The buildings, roads and river are present at first control.

Native reproduction from `D:/Projects/AshenOath/outputs/AshenOathTheRoadBetweenCrowns`:

```powershell
& 'D:/Temp/AshenOath/godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe' --path . --rendering-method gl_compatibility --rendering-driver opengl3_angle --resolution 1280x720 --script res://tools/verify_opening_detail_runtime.gd
```
