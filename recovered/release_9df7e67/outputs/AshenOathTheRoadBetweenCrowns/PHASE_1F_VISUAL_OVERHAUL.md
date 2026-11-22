# Phase 1F Visual Overhaul

## Summary

Phase 1F improves the existing first route only: Greyfen spawn, Sister Anwen/shrine staging, Wychwood gate, forest road, clues, and the first Ghoulkin clearing. It does not add new quests, zones, combat systems, UI systems, or assets.

The pass keeps the target honest: a more authored, atmospheric, low-end web vertical slice. It is still not Witcher 3 quality or photoreal AAA.

## Files Changed

| File | Change |
| --- | --- |
| `scripts/settings_manager.gd` | Made Quality Mode the default: 0.75 render scale, 60 FPS target, foliage enabled, Potato Mode off. |
| `scripts/visual_director.gd` | Retuned Greyfen and Wychwood lighting, fog, sky/background color, contrast, and saturation. |
| `scripts/game.gd` | Added Quality-only Greyfen and Wychwood visual dressing layers with road detail, mud, clutter, light pools, tree/edge framing, clue-ground accents, clearing staging, and fog sheets. |
| `tools/verify_runtime.gd` | Added checks that the Quality visual overhaul markers exist in Greyfen and Wychwood. |
| `export_presets.cfg` | Fixed Web export file list so `character_presentation.gd` and `combat_feedback.gd` are included in the `.pck`, addressing a likely black-screen Web export cause. |
| `PHASE_1F_VISUAL_OVERHAUL.md` | This checkpoint report. |

## What Looks Better Now

### Greyfen

- Spawn road has more authored foreground/midground dressing instead of a sparse flat lane.
- Added wet road sheen, leaf litter, weeds, sacks, boards, buckets, cloth scraps, and warm shrine candle pools.
- Sister Anwen/shrine area has stronger warm/cold lighting contrast.
- Default atmosphere is less flat orange and more dark-fantasy dusk.

### Wychwood

- Forest route has more edge density and silhouette framing through deadfall, trees, roots, muddy patches, fog sheets, and darker path detail.
- Clue areas are visually grounded with darker patches so they read less like floating interaction points.
- First Ghoulkin clearing has stronger staging with blood/mud accents and clearer cold forest rim lighting.
- The road and clearing should feel more intentionally composed from the screenshot/camera angles.

### Lighting And Mood

- Greyfen is warmer around human spaces and colder at the edges.
- Wychwood is colder, darker, and foggier.
- Global contrast and saturation are slightly stronger for a less washed-out web image.

## Quality Mode vs Potato Mode

Quality Mode is now the default.

- Potato Mode off.
- 0.75 resolution scale.
- 60 FPS target.
- Foliage density enabled.
- Imported environment props allowed.
- Phase 1F quality visual layers enabled.

Potato Mode remains available from the Settings menu.

- Potato Mode on.
- 0.55 resolution scale.
- 30 FPS target.
- Foliage disabled.
- Heavy imported environment props skipped.
- Phase 1F quality visual layers skipped.

Use Potato Mode if the Dell 7280 stutters in browser.

## Verification

Commands run from the Godot project root:

```powershell
& 'C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --script res://tools/verify_runtime.gd
```

Result: passed. Output included `runtime vertical slice verification complete`. Godot still emitted ObjectDB cleanup warnings at exit.

```powershell
& 'C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe' --path . --script res://tools/capture_slice_screenshots.gd
```

Result: passed and produced updated screenshots. Godot reported the known Intel/ANGLE warning.

```powershell
cmd /c Export_Web_Build.bat
```

Result: passed. Web build verified during export as 7 files, 261.0 MB.

```powershell
& 'C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' tools\verify_web_export.py '..\AshenOath_Web'
```

Result: passed. Output: `web export verified: 7 files, 261.0 MB`.

## Screenshot Paths

Updated screenshots are in:

`C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns\verification_screenshots`

Most relevant Phase 1F captures:

- `01_greyfen_spawn.png`
- `02_village_center.png`
- `03_shrine_sister_anwen.png`
- `07_forest_gate.png`
- `08_forest_trail.png`
- `09_combat_clearing.png`
- `10_ghoulkin_windup_hud.png`
- `13_ghoulkin_victory_objective.png`

## Web Output

Single Web output folder:

`C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOath_Web`

Current files:

- `index.html`
- `index.js`
- `index.wasm`
- `index.pck`
- `index.png`
- `index.audio.worklet.js`
- `index.audio.position.worklet.js`

## Remaining Visual Weaknesses

- Human and monster models are still low-poly/stylized and below the Witcher 3 benchmark.
- No real facial animation, high-quality rigs, bespoke clothing, or cinematic animation retargeting yet.
- Quality Mode may stutter on the Dell 7280 in browser; Potato Mode is the fallback.
- Web export is still large at about 261 MB.
- Some Wychwood framing may still feel crowded from certain camera angles.
- The visual improvement is authored dressing and lighting, not a true terrain/material/character replacement pass.

## Recommended Phase 1G Prompt

Implement Phase 1G: browser startup and quality/performance validation. Verify the Web build loads past the Godot splash into the game, test Quality Mode and Potato Mode on the Dell 7280, add a small settings hint if needed, reduce any Wychwood foreground clutter that hurts camera readability, and keep the first route content unchanged.
