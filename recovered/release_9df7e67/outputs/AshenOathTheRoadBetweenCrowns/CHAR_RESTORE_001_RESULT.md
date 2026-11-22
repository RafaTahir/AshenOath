# CHAR-RESTORE-001 Result

## Status

Implemented and locally verified on `codex/masterpiece-rebuild`.

This ticket is committed locally only. It was intentionally not pushed to
`origin/main`, the development remote, or Vercel.

## What Changed

- Restored the preferred A-set Universal character composition for Kael and
  Sister Anwen, including their fixed identity recipes and front-facing
  presentation.
- Added deterministic actor-seeded character recipes for Universal male and
  female bodies: occupation palette, complexion, eye tint, hair choice, hair
  tint, and clothing treatment.
- Kept Captain Senn and `road_ranger_human` on the complete Ranger runtime
  asset without Universal overlays.
- Remapped human role manifests and runtime mappings to the Universal body,
  head, hair, and shared animation sources.
- Remapped Ghoulkin, Stalker, Raider, Brute, Bog Wretch, and Gravebound roles
  to the retained Skeleton source with role-specific scale, tint, posture, and
  combat profile. Ashwing remains Dragon-based and White Hart remains
  Wolf-based with its supernatural presentation.
- Removed obsolete primitive presentation helpers and old overlay anatomy
  paths. Valid equipment remains bone/socket attached.
- Updated character, monster, asset, license, audition, export, and Web
  verifier references to the retained runtime sources.
- Added `tools/capture_char_restore_001.gd` for deterministic 1280x720
  identity, crowd, Ranger, monster, gameplay-distance, and dialogue captures.
- Updated the character verifier's imported-scene bounds calculation to use
  transformed rendered bounds, avoiding false failures for valid FBX/GLTF
  imports.

## Runtime Role Mapping

| Role family | Runtime source |
| --- | --- |
| Kael | Universal male body/head, `Hair_SimpleParted.gltf` |
| Sister Anwen | Universal female body/head, `Hair_Buns.gltf` |
| Male villagers, guards, travelers, named men | Universal male body/head with deterministic recipes |
| Female villagers and named women | Universal female body/head with deterministic recipes |
| Captain Senn | `characters_ranger/Male_Ranger_Runtime.gltf` |
| Ghoulkin, Stalker, Raider, Brute, Bog Wretch, Gravebound | `assets_external/enemies/Skeleton.fbx` |
| Ashwing | `assets_external/enemies/Dragon.fbx` |
| White Hart | `assets_external/enemies/Wolf.fbx` |

## Retired Files

The following were removed from the current worktree after remapping and a
zero-reference scan. Historical Git commits and the rollback repository were
not changed.

- Rejected B/C screenshots: `CHAR_006_Kael_Fused_Rig.png`,
  `CHAR_007_Anwen_Shared_Rig.png`, `CHAR_008_Named_Ecosystem_Lineup.png`,
  and `CHAR_009_Greyfen_Crowd_Variation.png`.
- Animated B/C human sources and texture companions: `Warrior_Animated_CC0`,
  `Cleric_Animated_CC0`, `Monk_Animated_CC0`, and `Rogue_Animated_CC0`.
- Generated monster sources: `GhoulGaunt_Real.glb`,
  `GhoulStalker_Real.glb`, and `GhoulBrute_Real.glb`.
- `OrcSkull_Animated_CC0.gltf` and its atlas.
- Generated `.import` sidecars for the deleted assets.

## Evidence

Fresh 1280x720 captures in
`Development_Gallery/screenshots/`:

- `CHAR-RESTORE-001_A1_Kael.png`
- `CHAR-RESTORE-001_A2_Anwen.png`
- `CHAR-RESTORE-001_Crowd_Variation.png`
- `CHAR-RESTORE-001_Ranger_Senn.png`
- `CHAR-RESTORE-001_Monster_Families.png`
- `CHAR-RESTORE-001_Gameplay_Kael.png`
- `CHAR-RESTORE-001_Gameplay_Anwen.png`
- `CHAR-RESTORE-001_Dialogue_Anwen.png`

The captured humans are front-facing, complete, grounded, and visibly
different by role/palette. The Ranger remains hooded by design. The retained
Skeleton family is intentionally stylized and is differentiated through role
scale, tint, posture, and combat presentation; it is not a claim of
photorealistic monster replacement.

## Verification

Passed:

- `verify_pipe_003.py`
- `verify_asset_acceptance.py`
- `verify_asset_005.gd`
- `verify_web_001.py`
- `verify_char_001.gd`
- `verify_char_002.gd`
- `verify_char_005.gd`
- `verify_char_006.gd`
- `verify_char_007.gd`
- `verify_char_008.gd`
- `verify_char_009.gd`
- `verify_char_gameplay_qa_001.gd`
- `verify_char_qa_001.gd`
- `verify_face_003.gd`
- `verify_anim_003.gd`
- `verify_motion_quality.gd`
- `verify_character_real_001.gd`
- `verify_mon_002.gd`
- `verify_perf_003.gd`
- `verify_asset_001.gd`
- `verify_character_role_contract.gd`
- Active-manifest JSON parsing
- Deleted-runtime zero-reference scan
- Capture dimension and nonblank checks

`verify_mon_002.gd` prints three dummy-renderer/null-material diagnostics in
its existing headless harness before its final PASS. No ticket assertion
failed. Active graphical runtime rendering was not used as a release-wide
renderer-error certification in this ticket, so that broader lifecycle issue
remains outside this checkpoint.

## Limitations And Preserved Work

- The retained Universal and Skeleton sources are cohesive with the available
  repository assets, but they remain stylized low-poly content rather than
  high-fidelity realistic humans or horror creatures.
- Physical controller hardware was not available for this ticket; controller
  coverage is limited to existing automated/runtime contracts.
- The full real-input campaign route and full screenshot gallery were not
  rerun because this is a character remapping checkpoint.
- Existing unrelated edits remain uncommitted, including deployment workflow
  documentation, regenerated runtime-pack candidate manifests, existing
  CHARACTER_REAL screenshots, the current `scripts/game.gd` work, and the
  unrelated inspection helper. They were deliberately preserved and excluded
  from this ticket commit.

## Running Steps

From the canonical repository:

```powershell
cd "D:\Projects\AshenOath\outputs\AshenOathTheRoadBetweenCrowns"
& "C:\Users\User\.cache\codex-runtimes\godot-4.6.3\Godot_v4.6.3-stable_win64.exe" --path . --script tools/capture_char_restore_001.gd
& "C:\Users\User\.cache\codex-runtimes\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe" --headless --path . --script res://tools/verify_character_real_001.gd
```

The apparent junction path is also valid:

```powershell
cd "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns"
```

## Checkpoint

The final local commit for this ticket will use:

`CHAR-RESTORE-001: restore preferred character set and retire B/C assets`
