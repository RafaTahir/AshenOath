# CHAR-FACING-RANGER-001 Result

## Changes

- Calibrated route-visible Universal human and Ranger models by 180 degrees so their visible forward axis matches Godot movement toward `-Z`.
- Removed the player shared-animation rotation override and separated forward movement from intentional backpedaling.
- Removed Anwen's opposite-facing special case and aligned NPC route/dialogue yaw with the shared `-Z` contract.
- Integrated the optimized, 1K-textured `Male_Ranger_Runtime.gltf` as `road_ranger_human`; Captain Senn now uses that role without changing quests or dialogue.
- Updated character, asset, visual, license, export, and Ranger checksum manifests. Duplicate UAL2 setup/root-motion sources and raw Ranger source files remain excluded from runtime tracking.

## Evidence

- `Development_Gallery/screenshots/CHAR_001_01_Kael_Identity.png`
- `Development_Gallery/screenshots/CHAR_001_02_Anwen_Identity.png`
- `Development_Gallery/screenshots/CHAR_001_03_Villager_Identity.png`
- `Development_Gallery/screenshots/CHAR_006_Kael_Sword_Attack.png`
- `Development_Gallery/screenshots/CHAR_007_Anwen_ThreeQuarter.png`
- `Development_Gallery/screenshots/CHAR_FACING_RANGER_001_01_Senn_Portrait.png`
- `Development_Gallery/screenshots/CHAR_FACING_RANGER_001_02_Senn_Walk.png`
- `Development_Gallery/screenshots/CHAR_FACING_RANGER_001_03_Senn_Gameplay.png`

All captures are 1280x720 and were rendered with the Compatibility renderer. Codex visual review found grounded bodies, front-facing human presentation, no neck hump/proxy overlays, and a distinct Ranger silhouette. The Ranger hood intentionally obscures most facial detail as part of the source outfit.

## Verification

- `content_integrity`: PASS
- `runtime_smoke`: PASS
- `verify_character_real_001.gd`: PASS
- `verify_motion_quality.gd`: PASS; real skeleton transforms changed for player, NPCs, and Wychwood enemies
- `verify_runtime.gd`: PASS
- `capture_char_001.gd`: PASS
- `capture_char_006.gd`: PASS
- `capture_char_007.gd`: PASS
- `capture_char_facing_ranger_001.gd`: PASS
- `verify_web_export.py`: PASS; 7 files, 95.6 MB, PCK 59.3 MB
- Packed PCK startup: PASS; runtime-ready marker reached
- Chrome browser smoke: PASS; 1280x720 WebGL2, engine 8.6 s, New Game 1.6 s, JS heap 12.3 MB, no console errors
- Edge browser smoke: PASS; 1280x720 WebGL2, engine 10.4 s, New Game 2.0 s, JS heap 11.6 MB, no console errors
- Verified local PCK SHA256: `36e51ef582caadd29af94a36ae80d868d0eac2c8eb457a1f3334fb95bcea5b11`

The motion gate emits existing dummy-renderer material/RID cleanup diagnostics only after its pass marker during teardown; no active-render failure occurred.

## Web / Running Steps

Production export, browser smoke, and live deployment are completed below. Local development:

```powershell
cd "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns"
& "C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe" --path . --editor
```

For the browser candidate after export:

```powershell
python -m http.server 8787 --bind 127.0.0.1 --directory "..\AshenOath_Web"
```

Open `http://127.0.0.1:8787/?v=char-facing-ranger-001`. Start New Game, walk forward and backward, approach Sister Anwen, and continue to Captain Senn on the bandit road.

Production: open `https://ashenoath.vercel.app/?v=char-facing-ranger-001` after the deployment hash check.

## Known Limitations

- The shared Quaternius humans remain grounded stylized production assets, not photoreal characters.
- Physical controller hardware coverage remains limited to the existing project matrix.
- The Ranger hood intentionally reduces face visibility at gameplay distance; a later character pass can replace the hooded source outfit if stronger facial readability is required.

## Release

- Commit: `CHAR-FACING-RANGER-001: fix locomotion facing and integrate Ranger`.
- Local verified PCK hash: `36e51ef582caadd29af94a36ae80d868d0eac2c8eb457a1f3334fb95bcea5b11`.
- The final commit hash and live Vercel hash are reported after the production push.
