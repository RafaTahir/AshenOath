# PIPE-003 Result

## Scope

Added deterministic registration for reviewed character/monster artifacts. The pipeline records bytes, SHA-256, source pack, license file, runtime path, and a pending visual-review state without requiring Blender to be installed on every developer machine.

## Changes

- Added `tools/register_soul_asset.py`.
- The command is dry-run by default and rejects `downloads`, `raw`, and excluded animation-source paths as runtime mappings.
- `--write` is required to update `soul_character_role_manifest.json`; the command refuses missing assets or missing license records.
- The role manifest keeps the final approval decision separate from registration, so a hash alone cannot approve a bad-looking model.

## Verification

- `verify_asset_acceptance.py`: PASS with six pending roles and zero approved roles.
- Existing `verify_char_001.gd`, `verify_motion_quality.gd`, and `verify_anim_001.gd`: PASS for the current temporary runtime mappings.

## Known limitation

The portable Blender/gltfpack execution step remains environment-dependent. The repository now has the deterministic registration contract; actual source conversion starts when the selected CC0 GLBs are available locally and the processing tools are provisioned outside the repository.

## Running steps

```powershell
cd "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns"
& "C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" tools\register_soul_asset.py --role kael --path res://assets_external/characters/Adventurer_PolyPizza_Quaternius_CC0.glb --source-pack quaternius_universal_base_characters --license-file res://assets_external/licenses/Quaternius_RPG_Characters_CC0.txt
```
