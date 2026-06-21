# Phase 1I Animation Presentation

## Files Changed

| File | Change |
| --- | --- |
| `scripts/player_controller.gd` | Tuned procedural locomotion, combat pose phases, block stance, dodge/landing/hurt posture, and footstep rhythm. |
| `scripts/enemy_ai.gd` | Improved Ghoulkin/enemy procedural windup, chase menace, hit stagger, attack recovery, and death pose readability. |
| `scripts/npc_ambient.gd` | Calmed Sister Anwen and nearby NPC idle motion, added timing variation, slower look-at behavior, and reduced mannequin-like bobbing. |

## Player Animation Changes

- Reduced toy-like vertical bob and made movement feel more grounded.
- Added heavier forward lean for movement and dodge, with clearer hurt recoil.
- Split attack presentation into windup, strike, and recovery poses.
- Strengthened block/parry silhouette through sword/root posture instead of adding mechanics.
- Slowed footstep cadence slightly to better match the heavier body feel.

## Ghoulkin Animation Changes

- Ghoulkin windups now crouch and twist into the attack for clearer threat readability.
- Chase motion is lower and more predatory, with less frantic bobbing.
- Hits now create a short readable stagger/recoil.
- Death pose is flatter, heavier, and less like an instant scale collapse.

## NPC And Sister Anwen Changes

- Sister Anwen has calmer shrine idle motion, slower turning, and subtler breathing.
- Nearby Greyfen NPCs use lower bob, varied yaw offsets, and slower attention turns.
- Look-at behavior is less twitchy and holds attention briefly when the player approaches.

## Performance Precautions

- No skeletal retargeting, animation players, new assets, new systems, or heavy per-frame searches were added.
- Changes stay within existing procedural transforms.
- Web/Potato Mode remains safe; actor counts and scene content are unchanged.

## Verification

Command run:

```powershell
& 'C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --script res://tools/verify_runtime.gd
```

Result: passed.

Output:

```text
runtime vertical slice verification complete
```

## Known Issues

- This remains procedural pose polish, not real skeletal animation or full animation retargeting.
- Human faces, cloth motion, hand placement, weapon contact, and bespoke attack animations are still not AAA-grade.
- Screenshot capture was skipped because this pass only required the lightweight runtime verifier.

## Recommended Phase 1J

Do a focused audio and encounter presentation pass for the first route: footstep surface variation, shrine ambience, Wychwood tension swell, Ghoulkin windup/impact/death sounds, and victory/return audio cues.
