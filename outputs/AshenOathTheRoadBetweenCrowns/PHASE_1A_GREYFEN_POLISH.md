# Phase 1A Greyfen Polish

Date: 2026-06-21

## Summary

This pass improves the first 90 seconds after New Game in Greyfen without adding new quests, expanding blocked areas, or changing the core gameplay architecture. The goal was to make the spawn, shrine, and north road feel more deliberately staged while preserving browser-first Web performance and Potato Mode.

The result is still a low-poly/stylized vertical slice, not AAA or photoreal. The first impression is more authored: the player now spawns into a clearer north-facing road composition with lantern rhythm, road ruts, shrine candles, warm pools of light, mourning details, and village clutter placed around houses and landmarks instead of scattered randomly.

## Files Modified

| File | Change |
| --- | --- |
| `scripts/game.gd` | Added Greyfen first-impression dressing helpers, route readability props, shrine staging props, cheap light-pool meshes, road ruts, village story clusters, crow silhouettes, and NPC scale tuning for background villagers. |
| `scripts/visual_director.gd` | Tuned Greyfen dusk palette toward colder ambient fog and warmer lantern/sun contrast. |
| `tools/capture_slice_screenshots.gd` | Added a dedicated shrine/Sister Anwen screenshot and renumbered forest/combat captures. |
| `tools/verify_runtime.gd` | Added assertions for the new Greyfen first-impression marker, road rut readability, and lantern rhythm. |
| `PHASE_1A_GREYFEN_POLISH.md` | New handoff file for this pass. |

## Visual Improvements Made

- Spawn composition now has stronger road framing with darker side masses, visible wheel ruts, and warm foreground lantern pools.
- The main road toward Wychwood has repeated lantern/candle markers and darker rut strips to make the route legible without needing a minimap.
- Shrine/Sister Anwen area has more ceremony: candles, greenish shrine focus, hanging cloth, warm edge lighting, and clearer interactable staging.
- Village dressing now includes firewood stacks, broken fences, wheelbarrows, mourning markers, fake low fog banks, cloth pieces, and small sky silhouettes.
- Non-critical background NPCs were scaled down so they no longer overpower the first spawn/shrine screenshots.
- Greyfen lighting is colder and more mournful overall, with warmer focal points around lanterns and the shrine.

## Performance Precautions

- No new external assets were added.
- Most additions are cheap primitive meshes: boxes, cylinders, and small spheres.
- New visual density avoids heavy GLB instances and avoids new dynamic shadow requirements.
- Most light readability is faked with emissive meshes and flat colored ground patches.
- Only a few new OmniLight calls are used, and they reuse names already allowed by the Potato Mode light filter.
- Transparent fog planes were not expanded in Greyfen because performance mode skips most Greyfen fog sheets.
- The pass adds visual metadata for verifier counting instead of relying on duplicate node names.

Approximate new runtime visual budget in Greyfen:

| Category | Approximate Count | Notes |
| --- | ---: | --- |
| Road rut / mud strips | 22 | Collisionless box meshes. |
| Lantern posts / glows / fake pools | 30-40 nodes | Mostly collisionless or very small primitive nodes. |
| Shrine candles / cloth / path accents | 20-25 nodes | Small primitives; no new imported assets. |
| Story props | 35-45 nodes | Firewood, wheelbarrows, broken fences, mourning markers. |
| Bird silhouettes / low fog banks | 10-15 nodes | Tiny opaque primitives. |

## Known Issues

- Human models remain low-poly stand-ins and still do not meet a Witcher 3 style human-quality bar.
- Greyfen is still procedurally authored in `game.gd`; this pass improves composition but does not replace the god-object architecture.
- Web export remains large at about 261.0 MB because broad asset folders are still included.
- Potato Mode keeps the scene readable but limits fog, shadows, and foliage density.
- Screenshot capture still records some old numbered screenshots from previous runs alongside the new set.
- Godot may emit ANGLE/OpenGL warnings on the Dell 7280-class GPU; this is expected from the current Compatibility renderer path.

## Verification Commands Run

Runtime verifier:

```powershell
cd "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns"
& "C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe" --headless --path . --script res://tools/verify_runtime.gd
```

Screenshot capture:

```powershell
cd "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns"
& "C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe" --path . --script res://tools/capture_slice_screenshots.gd
```

Web export:

```powershell
cd "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns"
cmd /c Export_Web_Build.bat
```

The export batch runs:

```powershell
& "C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" "tools\verify_web_export.py" "..\AshenOath_Web"
```

## Test Results

| Check | Result | Notes |
| --- | --- | --- |
| Runtime verifier | Passed | `runtime vertical slice verification complete`. A prior strict duplicate-name check was corrected to use metadata because Godot auto-renames repeated nodes. |
| Screenshot capture | Passed | Saved screenshots to `verification_screenshots`. Godot reported the known ANGLE fallback warning for Intel HD Graphics 620. |
| Web export verifier | Passed | `web export verified: 7 files, 261.0 MB`. |
| Web output | Rebuilt | Current output is `outputs/AshenOath_Web`. |

## Screenshot Outputs

Current captured screenshot files:

- `verification_screenshots/01_greyfen_spawn.png`
- `verification_screenshots/02_village_center.png`
- `verification_screenshots/03_shrine_sister_anwen.png`
- `verification_screenshots/04_forest_gate.png`
- `verification_screenshots/05_forest_trail.png`
- `verification_screenshots/06_combat_clearing.png`

Older screenshot files from prior numbering may still remain in the folder:

- `verification_screenshots/03_forest_gate.png`
- `verification_screenshots/04_forest_trail.png`
- `verification_screenshots/05_combat_clearing.png`

## Recommended Phase 1B Next Step

Phase 1B should focus on character presence and animation readability for the same first route:

- Improve Sister Anwen, player, and villagers with better proportions, face/hair/clothing overlays, and grounded stance.
- Add simple idle/look-at behavior for Sister Anwen at the shrine.
- Add player and NPC shadow/contact grounding that works in Web/Potato Mode.
- Improve the first dialogue moment with subtle camera-safe staging, better nameplate position, and no oversized background NPC silhouettes.
- Keep the scope locked to Greyfen spawn through Sister Anwen and the Wychwood gate.
