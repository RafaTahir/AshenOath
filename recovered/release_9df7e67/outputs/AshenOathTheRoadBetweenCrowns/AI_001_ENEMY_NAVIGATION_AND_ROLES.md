# AI-001 - Enemy Navigation and Roles

## Result

The first Wychwood pack now maintains authored engagement lanes instead of steering every active enemy directly into Kael. Ghoulkin skirmish, the Stalker takes a wide flank, the Raider feints laterally, and the Brute advances through the centre at a slower pace. Existing staged wave activation and combat balance are preserved.

Enemy attacks now resolve from a measured animated rig contact source. The current cursed-skeleton family uses its head/jaw chain; compatible humanoid rigs use a hand. A clear strike corridor, line of sight, measured contact radius, and the single-attacker token must all agree before damage is applied.

## Files

- `scripts/enemy_ai.gd`
- `scripts/game.gd`
- `data/enemies.json`
- `tools/verify_ai_001.gd`
- `tools/capture_slice_screenshots.gd`
- `tools/run_release_gate.ps1`

## Acceptance

- Five enemies exist but only one is active at encounter opening.
- Four behavior roles use distinct engagement radii and approach angles.
- Enemies cannot attack through another enemy.
- Only one enemy may wind up or strike at a time.
- Every Wychwood enemy retains navigation-safe pursuit and a valid animated rig contact bone.
- Damage contact is measured from the visible animation rather than body distance alone.

## Run

Open `https://ashenoath.vercel.app/`, choose **New Game**, follow the Road of Crows into Wychwood, and observe each wave spreading around Kael. Tap `Q` during a lunge to parry; hold `Q` to block.
