# COMBAT-001 - Blade-Contact Combat

## Result

Player sword attacks now resolve from the animated weapon's measured hilt-to-tip sweep. The former delayed radius/facing hit path is no longer connected or present in runtime combat.

The second visible-recovery follow-up removes the wrongly oriented imported weapon path that produced a pole above Kael. Kael now always uses one hand-following Oathblade with an explicit ready pose, lateral light slash, and overhead heavy cut.

## Implemented

- Added persistent blade-base and blade-tip markers to Kael's bone-attached sword.
- Added a modeled steel Oathblade with blade, point, guard, grip, and a guaranteed readable material.
- Hidden the ambiguous embedded `Warrior_Sword`; it can no longer bypass the corrected hand socket.
- The hilt follows Kael's right hand while an explicit blade pose prevents imported wrist axes from rotating the weapon upward.
- Light attacks use the fast sword-slash clip; heavy attacks use a slower right-arm power strike with stronger torso commitment.
- Light and heavy attacks emit exactly one contact event during their strike phase.
- `CombatManager` tests the swept blade corridor against living, active enemies and world line-of-sight.
- Damage, oils, hit sparks, impact audio, camera shake, HUD health, and hit-stop share the resolved contact point.
- Slash-trail geometry follows the same measured blade movement used for damage.
- Enemy attacks report a weapon-space contact point. Parry audio, flash, camera response, attacker stagger, and messaging now resolve together.
- Oathfire behavior and combat balance remain unchanged.

## Verification

- `tools/verify_combat_001.gd` checks the exact controlled Oathblade, downward ready pose, lateral light arc, overhead heavy arc, rendered bounds/material, wrist attachment, measured arm motion, sword markers, one-contact-per-swing, real sweep hits, off-target misses, parry contact, and stagger.
- `tools/capture_slice_screenshots.gd` captures ready, light, heavy, and contact frames into the development gallery.
- The verifier is registered in `tools/run_release_gate.ps1`.
- The authoritative release gate passed runtime, story, asset, character, motion, river, navigation, world, visual, audio, packed-startup, and Web-export checks.
- Dell 7280 graphical measurement: 39.1 FPS average, 38.2 FPS minimum, 153 ms warm transition.
- Production Web export: 63.5 MB across seven files; `index.pck` is 27.2 MB.

## Known Limitations

- Character animation quality remains constrained by the current low-poly source rig and its limited clip library.
- Full enemy-family contact traces remain part of `AI-001`; this ticket keeps existing enemy attack timing and balance.

## Run

Open `https://ashenoath.vercel.app/?v=combat-001b`, start a New Game, follow the Road of Crows to Wychwood, use left click for light attacks, right click for heavy attacks, and tap `Q` during an enemy lunge to parry.
