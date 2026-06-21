# Phase 1B Character Presence

Date: 2026-06-21

## Summary

This pass improves character presence and animation readability for the first route: New Game spawn, Greyfen village, Sister Anwen at the shrine, and the Wychwood gate approach. It keeps the project browser-first, low-spec, and Potato Mode safe.

The goal was not to create AAA characters. The current characters remain low-poly/stylized stand-ins, but they now have stronger silhouettes, fake grounding, more readable role-specific overlays, smoother NPC facing, cleaner Sister Anwen staging, and a fixed dialogue text presentation.

## Files Modified

| File | Change |
| --- | --- |
| `scripts/character_presentation.gd` | New small helper for cheap character overlays, contact shadows, role silhouettes, face/hair/hood/robe/gear details. |
| `scripts/player_controller.gd` | Applies player presentation overlays/contact shadow and improves procedural idle/move/attack visual readability. |
| `scripts/npc_ambient.gd` | Replaced simple bob with role-aware ambient motion and smoothed look-at behavior toward the player. |
| `scripts/game.gd` | Applies NPC presentation overlays, wires NPC ambient setup, and adds Sister Anwen dialogue staging/facing. |
| `scripts/enemy_ai.gd` | Adds cheap contact shadows to enemies for stronger grounding in the first encounter. |
| `scripts/hud.gd` | Enables BBCode on dialogue text so bold dialogue markup renders correctly. |
| `tools/capture_slice_screenshots.gd` | Adds a dedicated Sister Anwen dialogue screenshot. |
| `tools/verify_runtime.gd` | Adds checks for player/Sister/enemy contact shadows, player overlay, Sister overlay, and dialogue spacing. |
| `PHASE_1B_CHARACTER_PRESENCE.md` | New handoff file for this pass. |

## Character Visual Improvements

- Player now gets a cheap presentation pass after either imported GLB body or fallback body creation.
- Player silhouette now includes split cloak panels, chest read, belt read, shoulder read, head/face/hair indication, and scabbard read.
- Sister Anwen now gets distinct robe panels, gold stole, staff read, hood/head detail, shoulders, and contact shadow.
- Mira, Rook, and villagers receive small role-specific overlays so they feel less clone-like.
- Enemies receive contact shadows so Ghoulkin/Bog Wretch bodies sit more clearly on the ground.

## Animation And Readability Improvements

- Player idle bob is more restrained.
- Movement lean is clearer but capped to avoid cartoon wobble.
- Attack animation now has a stronger windup/swing read on the sword and hilt.
- Player visual root now subtly rotates during heavy/light attack for clearer combat intent.
- NPC idle motion is role-aware: Sister Anwen is calmer, Rook is slightly sharper, villagers are restrained.
- NPC facing uses smoothed rotation toward the player when nearby instead of constant blind idle rotation.

## Dialogue Staging Improvements

- Sister Anwen interaction now stages the player at a cleaner conversational distance if the player is too close or too far.
- Player faces Sister Anwen before dialogue opens.
- Sister Anwen faces the player before dialogue opens.
- Dialogue mouse release/capture flow remains intact.
- Dialogue text now renders BBCode correctly instead of showing literal `[b]...[/b]`.

## Grounding / Contact Shadow Approach

- Contact shadows are fake geometry, not dynamic shadows.
- They use very flat dark `CylinderMesh` instances under major characters/enemies.
- They work in Potato Mode and do not depend on lights or real-time shadow casting.
- They are intentionally opaque and low-cost to avoid transparent-plane sorting problems.

## Web / Potato Mode Performance Precautions

- No new external assets were added.
- No new lights were added.
- No skeletal animation retargeting was introduced.
- New nodes are simple primitive meshes using basic materials.
- Approximate cost:
  - Player: about 12-14 small primitive presentation nodes.
  - Sister Anwen: about 12-14 small primitive presentation nodes.
  - Generic NPCs: about 7-9 small primitive presentation nodes each.
  - Enemies: 1 contact shadow node each.
- No broad scene-density increase was made.
- Web build remains the single output path.

## Verification Commands Run

Runtime verifier:

```powershell
cd "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns"
& "C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe" --headless --path . --script res://tools/verify_runtime.gd
```

Screenshot capture:

```powershell
cd "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns"
& "C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe" --path . --script res://tools/capture_slice_screenshots.gd
```

Web export:

```powershell
cd "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns"
cmd /c Export_Web_Build.bat
```

## Test Results

| Check | Result | Notes |
| --- | --- | --- |
| Runtime verifier | Passed | `runtime vertical slice verification complete`. Godot still emits the known ObjectDB cleanup warning on exit. |
| Screenshot capture | Passed | Saved current screenshots to `verification_screenshots`. Godot reported the known ANGLE fallback warning for Intel HD Graphics 620. |
| Web export verifier | Passed | `web export verified: 7 files, 261.0 MB`. |
| Web output | Rebuilt | Current output is `outputs/AshenOath_Web`. |

## Screenshot Outputs

Current captured screenshot files:

- `verification_screenshots/01_greyfen_spawn.png`
- `verification_screenshots/02_village_center.png`
- `verification_screenshots/03_shrine_sister_anwen.png`
- `verification_screenshots/04_sister_anwen_dialogue.png`
- `verification_screenshots/05_forest_gate.png`
- `verification_screenshots/06_forest_trail.png`
- `verification_screenshots/07_combat_clearing.png`

Older screenshot files from previous numbering may still remain in the folder.

## Known Issues

- The characters remain low-poly and stylized; this is not high-fidelity human art.
- Runtime overlay geometry improves readability but can still look blocky from some angles.
- The project still lacks true skeletal animation retargeting for the imported animation library.
- NPC look-at behavior is simple and can only rotate the interactable root, not individual heads/spines.
- Dialogue staging gently repositions the player for Sister Anwen when needed; it is useful, but still a lightweight staging trick rather than a cinematic conversation system.
- Web export remains large because broad asset folders are still included.

## Recommended Phase 1C Next Step

Phase 1C should focus on first-combat readability and feel:

- Improve Ghoulkin windup silhouettes and attack telegraphs.
- Add clearer player hit/block/parry feedback.
- Add enemy contact/audio timing for attack, hit, stagger, and death.
- Improve combat camera framing around the first clearing.
- Add a small combat screenshot/verifier path for windup, hit, stagger, and victory states.
- Keep scope locked to Wychwood gate through the first Ghoulkin encounter.
