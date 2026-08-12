# SCENE-001 Result

## Changes

- Added `zone_scene_manifest.json` with separate gameplay and decoration layer records for Greyfen, Wychwood, and the cemetery. Later campaign sections remain explicitly marked `procedural_fallback`.
- Added `ZoneSceneCatalog` to resolve and attach small authored PackedScene layers before the existing zone builder runs.
- Added opening layer scenes with authored spawn, gate, bridge, clue, clearing, chapel, bell, and ossuary anchors. Decoration layer roots are ready for mapped assets without changing current collision ownership.
- Added `verify_scene_001.gd` to load every opening layer through `ResourceLoader` and require authored children.

## Verification

- `tools/verify_scene_001.gd`: PASS.
- `tools/verify_runtime.gd`: PASS through Greyfen, Anwen, Wychwood, first encounter, return, and Castle approach checks.
- Existing procedural construction remains the visual fallback while the new layers are populated and accepted.

## Running Steps

```powershell
cd "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns"
& "C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe" --headless --path . --script tools\verify_scene_001.gd
& .\tools\run_ticket_gate.ps1 -Profiles scene -NoCache
```

## Limitations

The layer scenes currently contain anchors and composition roots, not the final building, terrain, or character meshes. This is intentional: replacing live procedural geometry is deferred until the packed layer has equivalent collision, quest, save, and visual evidence.
