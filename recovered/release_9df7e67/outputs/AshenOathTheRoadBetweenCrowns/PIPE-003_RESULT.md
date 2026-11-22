# PIPE-003 Result

## Scope

Added a deterministic conversion boundary and registration flow for reviewed character/monster artifacts. The pipeline validates source/output locations, records bytes, SHA-256, source pack, source URL, license file, runtime path, and a pending visual-review state without requiring Blender or gltfpack to be installed on every developer machine.

## Changes

- Added `tools/register_soul_asset.py`.
- Added `tools/character_asset_pipeline.py` for plan-only or external-gltfpack execution. It rejects raw/download/source-animation paths, keeps root motion disabled, and never promotes an output automatically.
- Added `tools/verify_pipe_003.py` and wired it into the `assets` ticket profile.
- The command is dry-run by default and rejects `downloads`, `raw`, and excluded animation-source paths as runtime mappings.
- `--write` is required to update `soul_character_role_manifest.json`; the command refuses missing assets or missing license records. Registered outputs remain `approved: false` and `export_eligible: false` until later visual and Godot import gates pass.
- The role manifest keeps the final approval decision separate from registration, so a hash alone cannot approve a bad-looking model.

## Verification

- `verify_asset_acceptance.py`: PASS with eight pending roles and one approved Ranger role.
- `verify_pipe_003.py`: PASS; the conversion boundary, deterministic export settings, and registration contract are parse-valid.
- Existing `verify_char_001.gd`, `verify_motion_quality.gd`, and `verify_anim_001.gd`: PASS for the current temporary runtime mappings.

## Known limitation

The portable Blender/gltfpack execution step remains environment-dependent. The repository now has a deterministic plan/execute boundary; actual source conversion starts when selected CC0 GLBs are available locally and the processing tools are provisioned outside the repository. No generated fallback body is promoted by this ticket.

## Running steps

```powershell
cd "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns"
& "C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" tools\register_soul_asset.py --role kael --path res://assets_external/characters/Adventurer_PolyPizza_Quaternius_CC0.glb --source-pack quaternius_universal_base_characters --license-file res://assets_external/licenses/Quaternius_RPG_Characters_CC0.txt
& "C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" tools\character_asset_pipeline.py --source res://assets_external/characters_ranger/Male_Ranger_Runtime.gltf --output res://assets_external/characters_ranger/Captain_Senn_Runtime.glb --role ranger --source-pack quaternius_modular_character_outfits_fantasy --source-url https://quaternius.itch.io/modular-character-outfits-fantasy --license-file res://assets_external/licenses/Quaternius_Modular_Character_Outfits_Fantasy_CC0.txt
```
