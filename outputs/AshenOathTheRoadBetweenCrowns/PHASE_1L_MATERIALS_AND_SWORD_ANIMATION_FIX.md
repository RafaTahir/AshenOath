# Phase 1L Materials And Sword Animation Fix

## Files Changed

| File | Change |
| --- | --- |
| `scripts/asset_spawn_helper.gd` | Added safe material fallback pass for imported meshes with missing/default white materials while preserving textured/non-white materials. |
| `scripts/player_controller.gd` | Rebuilt the player sword as one visible blade assembly with a shared pivot and attack/block pose animation. |
| `PHASE_1L_MATERIALS_AND_SWORD_ANIMATION_FIX.md` | This report. |

## Cause Of White Objects

Many visible assets are mapped `.obj`/`.glb` imports. When Godot could load an imported resource directly, `AssetSpawnHelper` used the imported mesh/scene and skipped the custom OBJ material loader. If that imported resource had no material, or only a default white material, it remained plain white. This affected first-route assets such as trees, rocks, enemies, and some character bases.

The slim export was not the primary cause for this pass. The required first-route character textures are still included, and untextured environment OBJ assets now receive procedural material fallback.

## Material And Texture Fix

- Added `_apply_safe_materials()` to `AssetSpawnHelper`.
- Preserves imported materials when they have textures or non-white albedo.
- Replaces missing/default-white materials with dark-fantasy fallback colors.
- Added fallback categories for:
  - tree/forest foliage,
  - rock/stone/wall/shrine stone,
  - roof/old wood/barrel/crate/cart/fence,
  - torch/metal/anvil,
  - bone/skeleton,
  - monster flesh,
  - cleric/monk/rogue/warrior character bases.
- Keeps roughness/metallic values conservative and Web/Potato safe.

## Export Filter Changes

None. No export preset or slim asset list was changed.

## Cause Of Sword Animation Bug

The player weapon was built as separate blade and hilt mesh nodes. Phase 1I rotated those separate nodes directly, which made the hilt/small component read like the attacking stick while the larger blade could appear disconnected or static.

## Sword Animation Fix

- Added `weapon_root` as the shared visible sword pivot.
- Rebuilt the player weapon as:
  - `visible_sword_root`,
  - `visible_sword_blade`,
  - `visible_sword_hilt`,
  - `visible_sword_pommel`.
- Light/heavy attacks now rotate the whole visible sword assembly.
- Heavy attack has a larger windup/arc.
- Block/parry ready pose now moves the full sword into a defensive silhouette.
- Combat logic and hit timing were not changed.

## Verification

Commands run:

```powershell
& 'C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --script res://tools/verify_runtime.gd
& 'C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe' --path . --script res://tools/capture_slice_screenshots.gd
cmd /c Export_Web_Build.bat
```

Result:

- Runtime verifier passed: `runtime vertical slice verification complete`.
- Screenshots captured successfully.
- Slim Web export rebuilt and passed `tools/verify_web_export.py`.
- Slim Web output remains 43.2 MB total with `index.pck` at 6.9 MB.
- Known existing note: Godot still reports ObjectDB cleanup warnings after verifier success.

## Screenshot Paths

- `verification_screenshots/01_greyfen_spawn.png`
- `verification_screenshots/03_shrine_sister_anwen.png`
- `verification_screenshots/10_ghoulkin_windup_hud.png`
- `verification_screenshots/11_player_block_cue.png`
- `verification_screenshots/12_ghoulkin_death_read.png`

Screenshots were also mirrored into `Development_Gallery/screenshots/`.

## Remaining Visual Issues

- Imported trees are now colored, but single-mesh tree fallbacks cannot separate bark and leaves perfectly.
- Characters still use stylized low-poly bases and authored wrappers, not AAA skin/cloth shaders.
- The spawn screenshot can still be poorly framed by the automated capture script; shrine/combat captures better represent the actual fix.

## Run Steps

```powershell
cd "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOath_Web_Slim"
& "C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" -m http.server 8787 --bind 127.0.0.1
```

Open:

```text
http://127.0.0.1:8787/index.html?v=phase1l
```

The slim Web build has already been rebuilt for this phase. If you make more source changes later, run `Export_Web_Build.bat` again from the Godot project root before starting the server.

## Recommended Phase 1M

Browser validation and capture pass for `AshenOath_Web_Slim`: export once, test material fixes and sword animation in Chrome/Edge, verify no white assets in the actual Web build, then tune screenshot capture framing so spawn/light/heavy attack screenshots reliably show the repaired visuals.
