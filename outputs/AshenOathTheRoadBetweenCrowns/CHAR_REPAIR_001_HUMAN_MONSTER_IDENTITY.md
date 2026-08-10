# CHAR-REPAIR-001: Human and Monster Identity

## Files Changed

- `scripts/enemy_ai.gd`
- `scripts/character_identity_profile.gd`
- `visual_upgrade_manifest.json`
- `character_role_manifest.json`
- `monster_family_manifest.json`
- `tools/capture_character_real_portraits.gd`
- refreshed `Development_Gallery/screenshots/CHARACTER_REAL_001_*.png`

## Implemented

- The primary Ghoulkin and Raider now use the existing textured, rigged Quaternius `OrcSkull_Animated_CC0.gltf` body instead of the internally generated segmented ghoul mesh.
- Stalker and Brute retain separate rigged family bodies, scale profiles, animation drivers, and behavior identities.
- Monster material identity now preserves readable role palettes and the capture tool applies the same identity profile used by runtime.
- Portrait capture now resolves qualified animation names such as `CharacterArmature|Idle`; it no longer records a false T-pose because it only looked for a literal `Idle` clip.
- Mapped route-visible characters continue to use Skeleton3D/AnimationPlayer contracts and no released proxy face/limb anatomy.

## Verification

- `verify_char_001.gd`: PASS
- `verify_char_002.gd`: PASS
- `verify_mon_001.gd`: PASS
- `verify_motion_quality.gd`: PASS
- Graphical portrait capture: PASS, 9 images at 1280x720

The graphical/headless Godot runs still print the known imported null-material and dummy-renderer teardown warnings. They are not being treated as clean release status; they remain assigned to `ENGINE-REPAIR-001`.

## Running Steps

From the project directory:

```powershell
& "C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe" --headless --path . --script tools/verify_char_001.gd
& "C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe" --headless --path . --script tools/verify_mon_001.gd
& "C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe" --path . --script tools/capture_character_real_portraits.gd
```

Open the refreshed images under `Development_Gallery/screenshots/`.

## Remaining Weakness

The available free character library remains deliberately stylized and below the Witcher 3 benchmark. Stalker and Brute are still low-poly derived bodies, and true facial expressions, lip sync, and bespoke clothing remain future work. No Web export or production deployment was performed for this development checkpoint.

## Next

Continue with `WORLD-REPAIR-001`: repair Greyfen/Wychwood route composition, river/bridge clearance, scenery blockers, and player-facing world materials before the lifecycle and performance gates.
