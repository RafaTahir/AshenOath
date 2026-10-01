# COMBAT-001 Result - Unified Equipment and Blade Contact

Status: accepted on 2026-09-21.

## Delivered

- Kael's modeled sword is attached through the live right-hand skeleton pose.
  Fast attack clips no longer read the one-frame-stale `BoneAttachment3D`
  transform, so the hilt remains inside the curled finger pose throughout
  light and heavy attacks.
- The grip contract is now enforced at every sampled strike frame with a
  maximum 0.03-metre separation. Current measured separation is below
  0.000001 metres.
- Blade base and tip transforms drive the damaging sweep, hit result, wall
  occlusion, and visible trail.
- The slash ribbon now uses only the outer third of the measured blade sweep.
  It no longer reproduces the previous full blade as a detached ghost sword.
- Timed parry resolves only through enemy contact, keeps player health
  unchanged, staggers the attacker, plays the current valid hit reaction, and
  releases the guard/grip pose in every excluded state.

## Verification

- `tools/verify_animated_blade_contact.gd`: PASS for light/heavy hits, wall
  rejection, hand/finger attachment, and rendered strike frames.
- `tools/verify_rendered_enemy_parry.gd`: PASS with one parry, unchanged
  health, 1.15-second enemy stagger, drawn sword, grounded body, and pose
  release.
- `tools/verify_combat_001.gd`: PASS across Greyfen/Wychwood runtime combat
  contracts.
- Rendered evidence inspected:
  `D:\Temp\AshenOath\blade_light_*_1789923048.png`,
  `blade_heavy_*_1789923049.png`, and
  `enemy_parry_1789923075.png`.

Detailed logs:

- `D:\Temp\AshenOath\combat001_animated_final_v2.log`
- `D:\Temp\AshenOath\combat001_rendered_parry_final_v2.log`
- `D:\Temp\AshenOath\combat001_contract_final_v2.log`

## Remaining Scope

This ticket accepts the unified sword-equipment and contact contract. Final
production-browser combat route certification remains owned by `CERT-001`,
while Oathfire presentation remains owned by `OATH-001`.

## Running Steps

```powershell
$godot = 'C:\Users\User\.cache\codex-runtimes\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe'
& $godot --path . --script res://tools/verify_animated_blade_contact.gd
& $godot --path . --script res://tools/verify_rendered_enemy_parry.gd
& $godot --path . --script res://tools/verify_combat_001.gd
```
