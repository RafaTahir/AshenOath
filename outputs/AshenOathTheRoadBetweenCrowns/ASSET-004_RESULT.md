# ASSET-004 Result

## Scope

Locked the cohesive Quaternius source families and added a reproducible acceptance contract without copying a full raw pack into the repository or Web export.

## Changes

- Added `soul_asset_pack_manifest.json` with pack version, official source page, download page, dependencies, preload priority, license, and acquisition status.
- Added `soul_character_role_manifest.json` for Kael, Anwen, villagers, guards, Ghoulkin, and the White Hart. Each role has a height/triangle/texture budget, required clips, sockets, current fallback, and explicit approval state.
- Added `tools/verify_asset_acceptance.py` to validate sources, licenses, role references, fallback availability, forbidden proxy paths, approved-file hashes, and excluded directories.
- Documented that new source downloads are manual/free-page acquisitions until a local archive is available; no unverified pack is silently treated as runtime-ready.

## Verification

```text
ASSET ACCEPTANCE: PASS (5 source packs, 0 approved roles, 6 pending roles)
```

The current prototype remains playable through its existing temporary fallbacks. No character role is falsely marked final.

## Known limitation

The source pages are not stable direct archives in this environment. The next pipeline ticket must register locally downloaded GLBs only after their SHA-256, license record, Godot import, skeleton, active clips, triangle budget, and portrait review pass.

## Running steps

```powershell
cd "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns"
& "C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" tools\verify_asset_acceptance.py . --json-report .release-gate\asset_acceptance.json
```
