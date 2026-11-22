# CHAR-001 Result

## Scope

Validated the current A-set Kael and Sister Anwen assemblies as the final
role-specific hero bodies for this recovery ticket. This ticket does not accept
crowd recipe diversity or monster faces; those remain owned by `CHAR-002` and
`MON-001`.

## Changes

- Corrected `tools/capture_face_003.gd` so its +Z portrait camera captures the
  gameplay-facing front of Universal humanoids instead of the backs of their
  heads.
- Updated `tools/verify_char_001.gd` to include the rendered albedo texture in
  its palette signature. The former check compared only the white material
  multiplier and falsely treated distinct baked atlases as identical.
- Updated `tools/verify_char_007.gd` to validate Anwen's current single-mesh
  `Anwen_A_Set_Atlas.gltf` contract and its declared female peasant, native
  head, and buns-hair sources. It no longer demands duplicate runtime head and
  hair nodes that the startup atlas intentionally consolidates.
- Added explicit `--human-only` and `--hero-only` modes to the existing broad
  face and real-character verifiers. Their default modes retain the complete
  crowd/monster checks for the later owning tickets.

## Runtime Result

- Kael resolves to `Kael_A_Set_Atlas.gltf`, one skinned mesh, one shared
  skeleton, native face materials, grey parted hair, grounded 1.78 m bounds,
  and validated head/hand equipment bones.
- Anwen resolves to `Anwen_A_Set_Atlas.gltf`, one skinned mesh, one shared
  skeleton, native female face materials, buns hair, grounded 1.68 m bounds,
  and a hand-bone staff socket.
- Anwen turns toward Kael during approach and retains the player-facing
  dialogue contract.
- Neither hero contains face cards, eye boxes, fake necks, proxy limbs, or
  root-mounted anatomy.

## Verification

- Fresh graphical character gallery capture: PASS.
- Fresh front-facing FACE-003 portrait capture: PASS.
- `verify_char_001.gd`: PASS.
- `verify_char_006.gd`: PASS.
- `verify_char_007.gd`: PASS.
- `verify_face_003.gd -- --human-only`: PASS.
- `verify_character_real_001.gd -- --hero-only`: PASS.

Logs are under `D:\Temp\AshenOath\char001`.

## Screenshots

- `Development_Gallery/screenshots/CHAR-RESTORE-001_A1_Kael.png`
- `Development_Gallery/screenshots/CHAR-RESTORE-001_A2_Anwen.png`
- `Development_Gallery/screenshots/CHAR-RESTORE-001_Dialogue_Anwen.png`
- `Development_Gallery/screenshots/FACE_003_01_Kael_Native_Face.png`
- `Development_Gallery/screenshots/FACE_003_02_Anwen_Native_Face.png`

All listed captures are fresh 1280x720 native Compatibility-renderer evidence.

## Remaining Work

- The fresh crowd frame still shows insufficient adjacent recipe diversity;
  this remains a release blocker under `CHAR-002`.
- Full FACE-003 continues to reject the current Wychwood stalker, raider, and
  brute face contracts; this remains a release blocker under `MON-001`.
- World art, performance, production browser certification, and release remain
  open under their own tickets.
- No Web export, commit, push, merge, tracked production synchronization, or
  deployment was performed.

## Running Steps

```powershell
Set-Location D:\Projects\AshenOath\outputs\AshenOathTheRoadBetweenCrowns
$godot = 'C:\Users\User\.cache\codex-runtimes\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe'
& $godot --path . --script res://tools/capture_char_restore_001.gd
& $godot --path . --script res://tools/capture_face_003.gd
& $godot --path . --script res://tools/verify_char_001.gd
& $godot --path . --script res://tools/verify_char_006.gd
& $godot --path . --script res://tools/verify_char_007.gd
& $godot --path . --script res://tools/verify_face_003.gd -- --human-only
& $godot --path . --script res://tools/verify_character_real_001.gd -- --hero-only
```
