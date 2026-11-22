# Character Contract Continuation Result

## Scope

Harden the runtime character acceptance boundary and audit the current shared
humanoid candidates without shipping a visibly worse model.

## Changes

- Added target height, ground offset, skeleton profile, animation profile,
  equipment sockets, required sockets, and height tolerance to the role spec.
- Added rendered-bounds, grounding, material, socket, and one-pass
  normalization checks to `CharacterRoleContract`.
- Prevented duplicate normalization and duplicate role-scale application.
- Added a single-layer fullbody composition path for future dressed imports.
- Made native face detection recognize imported eyes and brows as well as head,
  skin, hair, jaw, mouth, and teeth surfaces.
- Removed the old synthetic face-feature and per-frame feature-normalization
  helpers from the released identity profile.
- Corrected stale foundation and role manifests that still pointed crowd roles
  at the rejected fullbody candidate or Ghoul role at OrcSkull.
- Restored the complete clothed peasant composites as the current runtime
  fallback after the graphical fullbody audition failed.

## Evidence

- `Development_Gallery/screenshots/CHAR_006_Kael_Fused_Rig.png`
- `Development_Gallery/screenshots/CHAR_006_Kael_Sword_Attack.png`
- `Development_Gallery/screenshots/CHAR_007_Anwen_Shared_Rig.png`
- `Development_Gallery/screenshots/CHAR_007_Anwen_ThreeQuarter.png`
- `Development_Gallery/screenshots/CHAR_008_Named_Ecosystem_Lineup.png`
- `Development_Gallery/screenshots/CHAR_009_Greyfen_Crowd_Variation.png`

The images are fresh 1280x720 captures. They show grounded connected fallback
characters with native faces and hair. The Universal fullbody candidate was
also captured, but rejected because its current imported wardrobe is
underwear-only and the female source is bald.

## Verification

- `verify_char_005.gd`: PASS, 43 shared animation clips.
- `verify_char_006.gd`: PASS, Kael fused rig and sword socket.
- `verify_char_007.gd`: PASS, Anwen fused body and approach facing.
- `verify_char_008.gd`: PASS, eight named identity profiles.
- `verify_char_009.gd`: PASS, crowd scale and variation.
- `verify_face_003.gd`: PASS, native face materials and face driver.
- `verify_character_real_001.gd`: PASS.
- `verify_character_role_contract.gd`: PASS, one-pass normalization,
  grounding, sockets, and role scale.
- `verify_asset_acceptance.py`: PASS, five source packs, one approved role,
  eight pending roles.
- `verify_pipe_003.py`: PASS, deterministic conversion and registration boundary.

Shutdown-only dummy-renderer allocation messages still appear in isolated
Godot processes after pass markers; they are not treated as active-frame
visual approval.

## Acceptance boundary

The contract work is complete. Final character replacement is not: Kael,
Anwen, crowd, guards, and most monsters remain pending visual approval until
proper clothed human and monster-family sources are acquired and captured.

## Running steps

```powershell
cd "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns"
& "C:\Temp\AshenOathGodot4.6.3\Godot_v4.6.3-stable_win64_console.exe" --headless --path . --rendering-method gl_compatibility --script tools/verify_character_role_contract.gd
& "C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" tools/verify_asset_acceptance.py
```

No Web export or production deployment was performed for this checkpoint.
