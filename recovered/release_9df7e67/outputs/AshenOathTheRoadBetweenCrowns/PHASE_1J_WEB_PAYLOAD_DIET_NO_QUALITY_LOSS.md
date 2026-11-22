# Phase 1J Web Payload Diet No Quality Loss

## Size Results

| Build | Total | `index.pck` | `index.wasm` |
| --- | ---: | ---: | ---: |
| Original `AshenOath_Web` | 261.0 MiB | 224.7 MiB | 36.0 MiB |
| Slim `AshenOath_Web_Slim` | 43.2 MiB | 6.9 MiB | 36.0 MiB |

The visible slice payload was reduced by about 217.8 MiB without deleting source assets.

## Largest Ballast Found

| Ballast | Approx Size | Action |
| --- | ---: | --- |
| `assets_external/downloads/stylized_nature_megakitstandard.zip` | 99.3 MiB | Excluded from slim shipping |
| `assets_external/downloads/medieval_village_megakitstandard.zip` | 95.4 MiB | Excluded from slim shipping |
| `assets_external/downloads/fantasy_props_megakitstandard.zip` | 70.3 MiB | Excluded from slim shipping |
| Unused animation FBX/GLB libraries | 100+ MiB source-side | Excluded from slim shipping |
| Broad unused FBX alternates | 255+ MiB source-side | Excluded from slim shipping |
| Broad unused texture/UI/audio libraries | Hundreds of MiB source-side | Excluded from slim shipping |
| `Development_Gallery` and screenshots | Dev-only | Excluded from slim shipping |
| `tools`, raw downloads, preview renders | Dev-only | Excluded from slim shipping |

## What Was Excluded From Shipping

- Raw downloaded archives: `.zip`, `.7z`, `.rar`.
- Raw asset extraction folders.
- Tools and development-only scripts.
- Development gallery and verification screenshots.
- Unused animation libraries.
- Unused FBX alternates.
- Unused broad environment, UI, texture, and audio pack contents.
- Preview renders and editor-only source formats.

No source files were deleted.

## What Was Kept To Preserve Quality

The slim preset keeps the assets mapped to the current visible Greyfen-to-Wychwood slice:

- Player: `Warrior.obj` plus texture.
- Sister Anwen: `Cleric.obj` plus texture.
- Rook: `Rogue.obj` plus texture.
- Villagers: `Monk.obj` plus texture.
- Mira and generic human base GLBs.
- Ghoulkin and current enemy fallback meshes: `Skeleton.obj`, `Slime.obj`, `Wolf.obj`.
- First-slice environment roles: village wall/roof/shrine pieces, anvil, barrel, crate, cart, fence, torch, tree, rock, bush.
- Current UI/button/panel textures and UI click audio.
- Runtime data JSON, role mappings, visual upgrade manifest, scripts, and `scenes/main.tscn`.

Phase 1F visual dressing, Phase 1G character/monster wrappers, Phase 1H camera, and Phase 1I animation code remain active.

## Files Changed

| File | Change |
| --- | --- |
| `export_presets.cfg` | Added `Web Browser Slim` preset with exact first-slice asset include list and dev/unused ballast exclusions. |
| `Export_Web_Build.bat` | Now exports `Web Browser Slim` to `../AshenOath_Web_Slim`. |
| `tools/verify_web_export.py` | Reports total size and per-file sizes; warns on oversized `.pck`, total export, or single files. |
| `WEB_DEPLOY.md` | Updated deployment instructions to use `AshenOath_Web_Slim`. |
| `PHASE_1J_WEB_PAYLOAD_DIET_NO_QUALITY_LOSS.md` | This report. |

## How To Build And Use Slim Export

From the Godot project root:

```bat
Export_Web_Build.bat
```

Deploy the contents of:

```text
outputs/AshenOath_Web_Slim
```

The upload root must contain `index.html`, `index.js`, `index.wasm`, `index.pck`, `index.png`, and the audio worklet files.

## Vercel Readiness

Ready for Vercel-style static deployment from a payload-size perspective.

- Total slim folder: 43.2 MiB.
- Largest file: `index.wasm` at 36.0 MiB.
- `index.pck`: 6.9 MiB.
- Single-threaded Web export remains active, so COOP/COEP headers are not required for this build.

## Verification

Commands run:

```powershell
& 'C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --script res://tools/verify_runtime.gd
cmd /c Export_Web_Build.bat
```

Results:

- Runtime verifier passed: `runtime vertical slice verification complete`.
- Slim web export passed `tools/verify_web_export.py`.
- Slim export output: 7 files, 43.2 MiB.

Known existing note: the runtime verifier still reported the existing Godot ObjectDB cleanup warning after success.

## Known Risks

- The slim export is intentionally scoped to the current vertical slice. Expanding areas or switching to currently unused assets requires updating the slim preset include list.
- `asset_manifest.json` is still included for safety even though it is larger than ideal. A later code cleanup could remove runtime dependence and save another small amount.
- This pass did not run a browser playthrough; it verified runtime and export shape.

## Recommended Phase 1K

Run a browser smoke/playtest pass against `AshenOath_Web_Slim`: start new game, speak to Sister Anwen, enter Wychwood, inspect clues, fight Ghoulkin, verify no missing visible assets, then update any slim include rules if the browser exposes a missing optional resource.
