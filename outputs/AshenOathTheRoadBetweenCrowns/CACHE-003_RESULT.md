# CACHE-003 Result

## Changes

- Added `runtime_pack_manifest.json` with version, dependency, checksum, byte-budget, entry-scene, and preload fields for base, opening, campaign, character, monster, and audio packs.
- Added `tools/build_web_runtime_manifest.py` to write SHA-256 and byte metadata for a verified Web export.
- Kept the current stable Web filenames and embedded PCK as the safe fallback. Hashed filenames are a later deployment step once the manifest is wired into the HTML shell and Vercel routing.

## Verification

- `tools/verify_runtime_packs.py`: PASS, six packs, 100 MB deployment ceiling.
- `python -m py_compile tools/verify_runtime_packs.py tools/build_web_runtime_manifest.py`: PASS.
- `tools/run_ticket_gate.ps1 -Profiles packs -NoCache`: PASS, including content integrity, runtime smoke, pack validation, Web export, export validation, and packed startup.
- Current local export: seven-file Web artifact, approximately 65.8 MB total and 29.5 MB PCK.

## Running Steps

```powershell
cd "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns"
& "C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe" --path . --editor
```

For the local Web candidate, run `Export_Web_Build.bat`, then serve `..\AshenOath_Web` with the bundled Python HTTP server.

## Limitations

The source pack URLs and role records are ready, but no downloaded character pack is marked approved yet. The game remains on its existing embedded runtime assets until the asset acceptance gate passes for a replacement.
