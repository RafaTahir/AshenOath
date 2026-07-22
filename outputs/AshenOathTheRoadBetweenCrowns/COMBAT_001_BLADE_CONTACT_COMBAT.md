# COMBAT-001 - Blade-Contact Combat

## Result

Player sword attacks now resolve from the animated weapon's measured hilt-to-tip sweep. The former delayed radius/facing hit path is no longer connected or present in runtime combat.

## Implemented

- Added persistent blade-base and blade-tip markers to Kael's bone-attached sword.
- Light and heavy attacks emit exactly one contact event during their strike phase.
- `CombatManager` tests the swept blade corridor against living, active enemies and world line-of-sight.
- Damage, oils, hit sparks, impact audio, camera shake, HUD health, and hit-stop share the resolved contact point.
- Slash-trail geometry follows the same measured blade movement used for damage.
- Enemy attacks report a weapon-space contact point. Parry audio, flash, camera response, attacker stagger, and messaging now resolve together.
- Oathfire behavior and combat balance remain unchanged.

## Verification

- `tools/verify_combat_001.gd` checks sword markers, blade length, one-contact-per-swing, real sweep hits, off-target misses, parry contact, and stagger.
- `tools/capture_slice_screenshots.gd` captures `73_combat_001_blade_contact` into the development gallery.
- The verifier is registered in `tools/run_release_gate.ps1`.
- The authoritative release gate passed runtime, story, asset, character, motion, river, navigation, world, visual, audio, packed-startup, and Web-export checks.
- Dell 7280 graphical measurement: 33.0 FPS average, 32.4 FPS minimum, 267 ms warm transition.
- Production Web export: 63.5 MB across seven files; `index.pck` is 27.2 MB.

## Known Limitations

- Imported low-poly sword and character animations remain constrained by the current source assets.
- Full enemy-family contact traces remain part of `AI-001`; this ticket keeps existing enemy attack timing and balance.

## Run

Open `https://ashenoath.vercel.app/?v=combat-001`, start a New Game, follow the Road of Crows to Wychwood, use left click for light attacks, right click for heavy attacks, and tap `Q` during an enemy lunge to parry.
