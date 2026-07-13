# ASSET-001 Curated Runtime Library

## Outcome

ASSET-001 replaces the generated full-library runtime index with one reviewed manifest. The source library remains available for future auditions, but only assets listed in `curated_runtime_assets.json` can resolve as runtime roles or enter the slim Web preset.

## Changes

- Added 36 reviewed roles backed by 27 unique runtime files.
- Recorded source pack, CC0 status and a local license file for every role.
- Changed `AssetDatabase` to load only the curated manifest.
- Removed `asset_manifest.json` and `asset_role_mapping_suggested.json` from Web export.
- Removed rejected Warrior, Cleric and OrcSkull auditions from Web export.
- Removed unused Monk/Rogue animated candidates, legacy character fallbacks, `AnimatedHuman`, and three unwired generated Ghoul GLBs from Web export.
- Kept the current five animated human GLBs, Skeleton FBX, required enemy/character OBJs, selected village/nature/prop modules, UI/audio files and runtime textures.
- Packaged all licenses required by the selected assets.

Technical inclusion is not visual approval. Current Kael, Anwen, crowd, Ghoulkin, White Hart and broader enemy models remain temporary art debt for `CHAR-001` and `MON-001`.

## Quarantine

- `Warrior_Animated_CC0.gltf`: rejected by the Kael audition.
- `Cleric_Animated_CC0.gltf`: rejected by the Anwen audition.
- `OrcSkull_Animated_CC0.gltf`: rejected by the Ghoulkin audition.
- `GhoulGaunt_Real.glb`, `GhoulStalker_Real.glb`, `GhoulBrute_Real.glb`: unused generated artifacts that never became runtime bodies.

Files remain in the source workspace for audit/history. They are not deleted and are not exported.

## Verification

- Content integrity: pass, 20 quests / 78 objectives / 72 dialogue actions / 55 runtime references.
- ASSET-001 file gate: pass, 36 roles / 27 unique files / 7.92 MiB selected source payload.
- ASSET-001 instantiation gate: pass for representative characters, enemies and every environment role family.
- Runtime gameplay assertions: pass. Existing classified headless renderer cleanup warnings remain.
- Preview Web export: pass, seven files / 63.1 MB total / 26.8 MB PCK.
- Packed preview startup: pass; main menu audio state initialized.

Measured current production output before ASSET-001: 69.52 MB total / 33.23 MB PCK. The preview saves approximately 6.4 MB without changing gameplay content.

## Commands

```powershell
& .\tools\run_release_gate.ps1 -Only verify_asset_001 -SkipExport -SkipPerformance -SkipScreenshots
& .\tools\run_release_gate.ps1 -Only verify_runtime -SkipExport -SkipPerformance -SkipScreenshots
& $godot --headless --path . --export-release "Web Browser" ..\AshenOath_Web_ASSET_001_PREVIEW\index.html
& $python .\tools\verify_web_export.py ..\AshenOath_Web_ASSET_001_PREVIEW
& $godot --headless --path ..\AshenOath_Web_ASSET_001_PREVIEW --main-pack ..\AshenOath_Web_ASSET_001_PREVIEW\index.pck --quit-after 5
```

## Deployment

No production deployment. ASSET-001 is a development milestone on `codex/studio-recovery-tranche-001`; the existing live build remains unchanged.

## Next Ticket

`NAV-001` should establish navigation routes, bridge anchors, gate corridors and validated recovery before authored world reconstruction increases route complexity.
