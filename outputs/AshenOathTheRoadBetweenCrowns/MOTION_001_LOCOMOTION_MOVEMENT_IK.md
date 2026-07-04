# MOTION-001 Locomotion, Movement, and IK Foundation

## Files Changed

- `scripts/player_controller.gd`
- `scripts/game.gd`
- `scripts/hud.gd`
- `tools/verify_runtime.gd`
- `tools/verify_motion_quality.gd`
- `tools/capture_slice_screenshots.gd`
- repository deployment verifier workflow

## Locomotion

- Added acceleration, heavier run acceleration, and readable deceleration instead of horizontal velocity snapping.
- Added smoothed directional turning, slower backward travel, strafe state blending, and distinct run/walk limb amplitudes.
- Improved arm counter-swing, leg rhythm, cloak follow-through, start/stop blending, and speed-synchronized footsteps.

## Movement Mechanics

- Added `X` jump with an airborne pose and landing compression.
- Preserved `Space` dodge and its 28 stamina cost while adding shaped velocity, stronger lean, cloak response, and recovery.
- Added floor snapping and a guarded 0.30-metre step-up probe for small route obstacles.
- Vault/slide was deferred because the current first route has no reliable dedicated obstacle that would make either mechanic safe and understandable.

## IK Feasibility And Grounding

The current imported player does not expose a reliable runtime skeletal foot-control setup. Full skeletal IK was therefore not safe for this pass.

The procedural substitute samples each foot position, smooths the floor normal, adjusts proxy foot heights and pelvis offset, tilts the body into slopes, compresses landings, and scales the contact shadow while airborne. This remains lightweight for Web and Potato Mode.

## Combat Compatibility

Light/heavy sword animation, block/parry, dodge stamina, Oathfire, and the Wychwood encounter remain under their existing ownership. Movement poses yield to attack and block pose priorities; the visible sword transform remains verifier-protected.

## Screenshots

- `Development_Gallery/screenshots/Capture_11_player_idle_pose_2026-07-05_062617.png`
- `Development_Gallery/screenshots/Capture_12_player_walking_pose_2026-07-05_062617.png`
- `Development_Gallery/screenshots/Capture_26_player_running_pose_2026-07-05_062617.png`
- `Development_Gallery/screenshots/Capture_27_player_strafe_turn_pose_2026-07-05_062617.png`
- `Development_Gallery/screenshots/Capture_28_player_jump_pose_2026-07-05_062617.png`
- `Development_Gallery/screenshots/Capture_29_player_dodge_pose_2026-07-05_062617.png`
- `Development_Gallery/screenshots/Capture_30_player_slope_grounding_2026-07-05_062617.png`
- `Development_Gallery/screenshots/Capture_14_player_heavy_attack_arc_2026-07-05_062617.png`

## Verification

- `tools/verify_runtime.gd`: passed during implementation.
- `tools/verify_visible_quality.gd`: passed during implementation.
- `tools/verify_motion_quality.gd`: passed, including a grounded jump launch through the shared controller method.
- Screenshot capture produced the required motion proof frames.

## Remaining Weaknesses

- Motion remains procedural around a low-poly imported body rather than authored skeletal clips.
- Foot proxies improve contact but cannot deform or reposition the imported model's actual feet.
- Step-up is intentionally limited; vaulting and climbing need authored test obstacles and animation support.
