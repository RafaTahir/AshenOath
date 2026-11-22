# OATH-001 - Oathfire Reconstruction

## Files Changed
- `scripts/player_controller.gd`
- `scripts/combat_manager.gd`
- `scripts/game.gd`
- `tools/verify_oath_001.gd`
- `tools/capture_slice_screenshots.gd`
- `tools/run_release_gate.ps1`

## Implementation
- Oathfire now locks Kael's facing direction when `C` is first pressed and preserves it through sheathing, charging, release, and recovery.
- The sword is hidden from the hand and shown on Kael's back during the cast.
- Charge glows follow the imported skeleton's actual hand bones; the charge sphere is positioned between those animated hands.
- Damage and VFX now share one cast origin, direction, wall-clipped endpoint, width, range, and charge ratio.
- Release occurs once at the hand-thrust contact frame instead of immediately when the key is released.
- Balanced mode adds a white-hot beam core; Potato retains the required cyan core.
- Launch and impact feedback use the same cast endpoints, and runtime effects are removed during cancellation and zone changes.

## Verification
- `verify_oath_001.gd` checks bone attachments, direction locking, contact timing, single emission, shared cast geometry, effect composition, and transition cleanup.
- Focused screenshots: charge hands, release contact, and wall impact.
- Authoritative release gate: PASS.
- Dell 7280 graphical result: 41.1 FPS average, 39.1 FPS minimum, 107 ms warm transition.
- Web export: PASS, 7 files / 63.5 MB.

## Run The Game
1. Open `https://ashenoath.vercel.app/?v=oath001` in Chrome or Edge.
2. Click the launch screen or press `Enter` to unlock browser audio.
3. Choose `New Game`.
4. Move with `WASD` and look with the mouse.
5. Hold `C` to charge Oathfire, then release `C` to fire in the direction Kael faced when charging began.

## Remaining Limitation
- The current shared humanoid animation library does not include a bespoke two-handed energy-casting clip, so hand motion uses its closest authored interaction clip with bone-tracked VFX.
