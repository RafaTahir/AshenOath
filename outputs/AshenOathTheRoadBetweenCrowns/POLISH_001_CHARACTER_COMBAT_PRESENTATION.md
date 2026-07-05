# POLISH-001 Character and Combat Presentation

## Files Changed

- `scripts/game.gd`
- `scripts/player_controller.gd`
- `scripts/enemy_ai.gd`
- `scripts/npc_ambient.gd`
- `scripts/greyfen_life_controller.gd`
- `scripts/character_presentation.gd`
- `scripts/character_animation_driver.gd`
- `scripts/hud.gd`
- `tools/verify_runtime.gd`
- `tools/verify_castle_vargan.gd`
- `tools/verify_polish_001.gd`
- `tools/capture_slice_screenshots.gd`
- `scripts/deploy_web_update.ps1`

## Improvements

- Castle Vargan is directly accessible from Greyfen; entering it starts `Blood Under Stone` for fresh and legacy progress.
- Sister Anwen keeps ownership of her facing during dialogue and no longer turns away as the player approaches.
- Greyfen walkers now use rigged, animated human assets with role-specific clothing, face, hair, and color overlays.
- Kael and Anwen receive distinct human presentation details while preserving their skeletal animation.
- Wychwood enemies now use skirmisher, flanker, feinter, and brute approach profiles with different recovery movement.
- Tap-Q parry has a clear timing window, prevents the incoming hit, and exposes the attacker to bonus damage; holding Q remains block.
- Sword light arcs occur only through the strike window and originate at the animated rig sword when available.
- Oathfire now sheaths and hides Kael's real rigged sword, uses a hands-together animation, forms the charge between both hands, releases, then redraws the sword.

## Visual Proof

Screenshots are in `verification_screenshots/` and mirrored to `Development_Gallery/screenshots/`:

- `60_polish_skeletal_villagers.png`
- `61_polish_anwen_facing.png`
- `62_polish_kael_character.png`
- `63_polish_parry_contact.png`
- `64_polish_sword_slash_alignment.png`
- `65_polish_oathfire_sheathed.png`
- `66_polish_oathfire_hand_charge.png`
- `67_polish_enemy_approaches.png`

## Verification

- `verify_runtime.gd`: pass
- `verify_greyfen_life.gd`: pass
- `verify_motion_quality.gd`: pass with measured skeleton movement
- `verify_polish_001.gd`: pass
- Screenshot capture: pass, nonblank images written to both screenshot locations

## Remaining Limitations

- Characters remain cohesive stylized low-poly rigs, not photoreal humans.
- Oathfire hand acting uses the best compatible clip already present in the Web-safe rig rather than bespoke motion capture.
- The screenshot harness loads many zones and captures images in one process, so its sampled FPS is not a representative gameplay benchmark.

## Next Recommended Phase

Author bespoke facial textures, hair/clothing meshes, and dedicated parry/Oathfire skeletal clips while keeping the current verified gameplay contracts.
