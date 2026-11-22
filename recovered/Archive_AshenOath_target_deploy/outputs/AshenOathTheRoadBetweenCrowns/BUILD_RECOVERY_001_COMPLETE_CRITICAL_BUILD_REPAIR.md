# BUILD-RECOVERY-001

## Files and systems changed
- Character normalization now survives role, NPC, player, and enemy spawning.
- Sister Anwen faces approaching players without the former 180-degree offset.
- Wychwood uses three encounter waves: two Ghoulkin, Stalker/Raider, then Brute.
- Dormant enemies are hidden, non-colliding, non-simulating, and invulnerable.
- Kael uses the imported Warrior Sword on the hand socket; Oathfire behavior remains intact.
- River recovery uses validated, same-bank positions away from bridge mouths and buildings.
- Dialogue no longer repeats the speaker name. Quest tracking is explicit and zone-aware.
- The Hart, torch flames, Record Hall lighting, tree silhouettes, and tracker layout were corrected.
- Repeated world shells and authored details are batched by material with retained collision nodes.
- Route caching translates whole zones instead of recursively toggling thousands of colliders.

## Verification
- Runtime vertical-slice flow: pass.
- Graphical Compatibility performance: 29.5 FPS average, 29 FPS minimum, 158 ms warm transition.
- Balanced world renders at 1280x720 beneath the 1920x1080 UI canvas.
- Acceptance screenshots: `Development_Gallery/screenshots/`.
- Authoritative runner: `tools/run_release_gate.ps1`.

## Honest limitation
The release remains a stylized low-poly browser RPG. It is more coherent and stable, but its current licensed character and environment assets are not photoreal or AAA-grade.

## Running
Open `https://ashenoath.vercel.app/`, click **Enter**, then **New Game**. Use WASD and mouse to move/look, E to interact, mouse buttons to attack, Q to parry/block, Space to dodge, and hold C to charge Oathfire.
