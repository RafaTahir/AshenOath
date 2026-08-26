# ASSET-005 Result - Approved Runtime Asset Boundary

## Status

`verified`

The runtime now has one explicit ASSET-005 acceptance manifest. It records
source URLs, CC0 license files, exact bytes and SHA-256 values for processed
runtime files, role fallbacks, export eligibility, and quarantine rules.

Only `road_ranger_human` (Captain Senn) is approved at this boundary. Kael,
Sister Anwen, villagers, guards, travelers, Ghoulkin, Bog Wretch, Gravebound
Knight, Ashwing, and the White Hart retain playable fallback mappings but are
blocked from visual approval until their rendered identity gates pass.

## Changes

- Added `runtime_asset_manifest.json` as the ASSET-005 source of truth.
- Added `tools/verify_asset_005.py` with exact local artifact, license,
  fallback, quarantine, and export-input checks.
- Added runtime acceptance metadata accessors to `scripts/asset_database.gd`.
- Added the runtime manifest to the explicit Web and QA export file lists.
- Added a `.gitignore` rule for unprocessed duplicate monster-pack sources.
- Registered `verify_asset_005` under the targeted assets profile.
- Preserved all existing gameplay mappings; this ticket does not silently
  promote provisional models or remove playable fallbacks.

## Verification

- `ASSET-005`: PASS - 1 approved runtime role, 10 explicit fallbacks.
- Legacy asset acceptance: PASS - 6 source packs, 1 approved role, 9 pending
  roles.
- Curated runtime asset file gate: PASS - 64 roles, 42 unique files.
- Deterministic asset pipeline: PASS.
- Content integrity: PASS - 20 quests, 80 objectives, 86 dialogue actions,
  44 runtime references.
- Runtime packs: PASS - 6 packs within the 100 MB budget.
- Python syntax compilation: PASS for `verify_asset_005.py`.
- `git diff --check`: PASS, with expected Git line-ending notices only.
- Godot 4.6.3 is provisioned in the external runtime cache. The Milestone-A
  packed Web export and browser checks pass; final visual approval for the ten
  blocked fallback roles remains intentionally assigned to later character and
  world tickets.

## Changed Views

None. This is a manifest and acceptance-boundary ticket. No visual claim is
made without a graphical runtime capture.

## Known Limitations

- The current humanoid and monster fallbacks remain visibly provisional.
- The final shared humanoid family, monster family replacements, and portrait
  evidence belong to the later character/monster tickets.
- The Ranger hash contract is verified from local files, but its imported
  Skeleton3D, clips, materials, and gameplay appearance still require Godot
  acceptance.

## Running Steps

```powershell
cd C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns
& "C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" tools\verify_asset_005.py .
```

Expected output begins with:

`ASSET-005 VERIFIER: PASS (1 approved runtime role, 10 explicit fallbacks)`
