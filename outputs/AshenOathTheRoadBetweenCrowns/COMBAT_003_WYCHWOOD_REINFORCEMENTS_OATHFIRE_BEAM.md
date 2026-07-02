# COMBAT-003 Wychwood Reinforcements and Oathfire Beam

## Implemented

- Expanded the first Wychwood encounter to five protagonist-sized enemies.
- Added Stalker, Raider, and Brute variants with distinct stats, scale, color, silhouette, and staged sense ranges.
- Changed encounter victory to require all five enemies.
- Added backward-compatible `wychwood_pack_kills` save state.
- Added hold-C Oathfire charging, stamina cost, cooldown, movement slowdown, cancellation, and camera-directed release.
- Added collision-clipped, piercing multi-target beam damage.
- Added procedural charge sphere, beam core, optional aura, impact feedback, camera reaction, controls text, and Potato fallback.

## Controls

Hold `C` for at least 0.35 seconds, then release to fire. Maximum charge is reached at 1.25 seconds. The attack costs 40 stamina and has a four-second cooldown.
