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
- Web export, fresh Chrome and deployment: pending final artifact below.

No art, story, save format or performance acceptance changes. A cold load must now finish essential scenery before control; this fix does not claim to eliminate download or shader preparation time. Extra population and small dressing still finish in bounded stages after control, even while moving.

## Running Steps

Production after publication: open `https://ashenoath.vercel.app/?v=greyfen-loading-fix`, click New Game, then walk across the bridge. The buildings, roads and river must be present at first control.

Native reproduction from `D:/Projects/AshenOath/outputs/AshenOathTheRoadBetweenCrowns`:

```powershell
& 'D:/Temp/AshenOath/godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe' --path . --rendering-method gl_compatibility --rendering-driver opengl3_angle --resolution 1280x720 --script res://tools/verify_opening_detail_runtime.gd
```
