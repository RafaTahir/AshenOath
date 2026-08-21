# ASSET-004 Result

## Scope

Locked the cohesive Quaternius source families and corrected the acceptance contract so it distinguishes a verified runtime artifact from a temporary playable fallback. No full raw pack was copied into the repository or Web export.

## Changes

- Versioned `soul_asset_pack_manifest.json` with pack metadata, selected runtime artifacts, byte/hash evidence, export policy, dependencies, and excluded-source rules.
- Corrected `soul_character_role_manifest.json`: only the optimized Ranger runtime is export-eligible and approved; Kael, Anwen, villagers, guards, Ghoulkin, Bog Wretch, Gravebound Knight, and White Hart remain explicitly blocked pending local source acquisition and visual review.
- Strengthened `tools/verify_asset_acceptance.py` to validate runtime artifact bytes/hashes, source URLs, license files, required role fields, export eligibility, blocked reasons, and animation-source exclusions.
- Updated `tools/register_soul_asset.py` so registration records reproducible artifact evidence and permits only the selected optimized UAL2 runtime animation file.
- Documented that new source downloads are manual/free-page acquisitions until a local archive is available; no unverified pack is silently treated as runtime-ready.

## Verification

```text
ASSET ACCEPTANCE: PASS (5 source packs, 1 approved role, 8 pending roles, 6 verified runtime artifacts)
```

The current prototype remains playable through its existing temporary fallbacks. No temporary body, derived Ghoul, or Wolf finale mapping is falsely marked final.

## Known limitation

The source pages are not stable direct archives in this environment. `PIPE-003` and the character tickets must register locally downloaded GLBs only after their SHA-256, license record, Godot import, skeleton, active clips, triangle budget, and portrait review pass.

## Running steps

```powershell
cd "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns"
& "C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" tools\verify_asset_acceptance.py . --json-report .release-gate\asset_acceptance.json
```
