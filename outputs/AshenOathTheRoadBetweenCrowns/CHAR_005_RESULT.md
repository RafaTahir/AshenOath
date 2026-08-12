# CHAR-005 Result — Shared Humanoid Foundation

## Status

Implemented and verified as an import/pipeline foundation ticket. The new Quaternius Universal Base Characters are available to Godot as complete humanoid GLTF scenes, and the Universal Animation Library 2 imports with 43 clips.

The live character mappings remain on the existing verified runtime fallback until the animation-fusion and named-character tickets replace them. This is intentional: importing a body without retargeting its clips would reintroduce frozen or detached actors.

## Files Changed

- `asset_sources.json`
- `export_presets.cfg`
- `scripts/asset_spawn_helper.gd`
- `scripts/character_role_contract.gd`
- `soul_character_foundation.json`
- `tools/download_assets.py`
- `tools/gate_profiles.json`
- `tools/verify_char_005.gd`
- `tools/verify_motion_quality.gd`
- `assets_external/characters_universal/`
- `assets_external/animations/soul_universal_animation_library_2.glb`
- `assets_external/licenses/`

## Implemented

- Added direct, repeatable download support for free itch.io name-your-price archives.
- Added selected CC0 Quaternius humanoid sources and license records.
- Added the shared role contract for target height, skeleton profile, sockets, materials, collision, and root-motion policy.
- Added contract metadata to spawned character scenes and normalization metadata to the existing bounds path.
- Added a truthful CHAR-005 verifier covering imported body scenes, one shared skeleton, head/hand bones, visible meshes, forbidden proxy anatomy, body bounds, and animation-library clip count.
- Corrected the verifier to compute bounds without querying global transforms on detached nodes.
- Corrected the motion verifier teardown so a passing gate exits rather than leaving a Godot process running.
- Added selected character resources to the Web export filters; raw archives remain excluded.

## Verification

Command:

```powershell
cd "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns"
& .\tools\run_ticket_gate.ps1 -Profiles characters -NoCache
```

Result: **PASS**

- Content integrity: pass
- Runtime smoke: pass
- CHAR-005 import gate: pass
- Existing character gates: pass
- Motion quality: pass
- Greyfen life: pass

Godot still reports known dummy-renderer shutdown diagnostics during the broad motion gate. They occur after the pass marker and remain lifecycle work for `ENGINE-003`; they are not hidden by this ticket.

## Running Steps

Use the existing desktop or Web instructions in `PROJECT_STATE.md`. To inspect this foundation directly:

```powershell
cd "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns"
& "C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64.exe" --path . --editor
```

The new body scenes are source assets for the next fusion tickets; they are not yet the final in-game Kael or Anwen presentation.

## Remaining Work

- Fuse UAL2 clips onto the shared humanoid skeleton without root motion.
- Build Kael’s and Anwen’s role-specific outfits, face profiles, sockets, and dialogue staging.
- Replace runtime fallback mappings only after motion and visual-distance gates pass.
- Complete crowd variants and monster-family replacement in their dedicated tickets.
