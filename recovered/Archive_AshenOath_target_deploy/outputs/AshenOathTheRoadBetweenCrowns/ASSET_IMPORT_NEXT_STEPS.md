# Asset Import Next Steps

1. Put downloaded asset packs into `assets_external/downloads`, or paste direct download URLs into `asset_sources.json`.
2. Run:

```powershell
python tools/download_assets.py
python tools/scan_assets.py
python tools/suggest_asset_mapping.py
python tools/create_placeholders_if_missing.py
```

3. Reopen Godot so it imports the new models, textures, and audio.
4. Review `asset_manifest.json`.
5. Review and edit `asset_role_mapping_suggested.json` as needed.
6. Use `AssetDatabase` and `AssetSpawnHelper` from Godot scripts to prefer real role assets over placeholders.

## Manual Work That Remains

- Choose final assets for each role when multiple suggestions are possible.
- Confirm licenses and attribution requirements.
- Tune imported model scale, rotation, collision, and materials.
- Assign authored animations to character controllers.
- Replace generated placeholder audio with final mastered audio.

## Role Mapping Format

Each role entry should point to a `res://` path when a real asset exists. Missing roles are marked with placeholder types so the game can keep running.

Example:

```json
{
  "status": "suggested",
  "asset_id": "knight_abcd1234",
  "path": "res://assets_external/enemies/knight.glb",
  "file_name": "knight.glb",
  "source_pack": "quaternius_animated_monsters",
  "license": "CC0",
  "confidence": 12,
  "notes": "Review before final use."
}
```
