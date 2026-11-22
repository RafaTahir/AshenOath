# ANIM-001 Shared Animation Contract

## Changes

- Added semantic clip resolution for idle, walk, run, jump, light/heavy attack, dodge, parry, Oathfire, hit, and death.
- Added bounded walk/run cadence scaling so animation speed follows controller velocity.
- Updated Greyfen routines to use walking cadence instead of sliding with run clips.
- Attached Kael's modeled drawn and sheathed swords to skeletal bone sockets.
- Added inverse rig-scale equipment spaces, removing oversized floating sword geometry.
- Added a truthful animation verifier and a graphical 1280x720 motion capture gate with blank-frame rejection.

## Visual Evidence

- `Development_Gallery/screenshots/ANIM_001_01_Kael_Idle.png`
- `Development_Gallery/screenshots/ANIM_001_02_Kael_Walk.png`
- `Development_Gallery/screenshots/ANIM_001_03_Kael_Attack.png`
- `Development_Gallery/screenshots/ANIM_001_04_Kael_Oathfire_Sheathed.png`
- `Development_Gallery/screenshots/ANIM_001_05_Kael_Motion_Contact_Sheet.png`

## Verification

`verify_anim_001.gd` requires valid shared drivers for Kael, Anwen, all seven retained Greyfen routines, and all five Wychwood enemies. It checks required semantic states, active skeletons, bounded cadence, bone-attached equipment, safe equipment scale, and absence of proxy anatomy.

- Complete functional verifier suite: PASS
- Graphical animation capture: PASS
- Dell 7280 native-720p result: 37.5 FPS average, 35.6 FPS minimum, 129 ms warm transition
- Web export and packed startup: PASS
- Web payload: 63.1 MB total / 26.8 MB PCK

## Limitation

This ticket makes the existing skeletal presentation coherent and prevents static sliding, missing clips, and detached equipment. It does not replace the project's low-poly bodies, add facial animation, or provide bespoke motion-captured clips.

## Running

1. Open `outputs/AshenOathTheRoadBetweenCrowns/project.godot` in Godot 4.6.3.
2. Press `F6` or run `res://scenes/main.tscn`.
3. Press `Enter`, choose **New Game**, and walk/run through Greyfen.
4. Inspect Kael's sword during attacks and Oathfire, then enter Wychwood to inspect enemy locomotion and reactions.
