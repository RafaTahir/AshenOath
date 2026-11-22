# PROG-001 Nine-Upgrade Progression

## Changes

- Added one idempotent Oath Mark reward for each completed main quest.
- Added three compact three-tier branches: Blade, Survival, and Oathfire.
- Integrated upgrades with blade damage, heavy damage, parry stamina, maximum health, dodge cost, potion healing, and Oathfire cost, range, and cooldown.
- Added journal upgrade choices without introducing a separate menu or XP grind.
- Added save migration, prerequisite sanitization, New Game reset, and idempotent Oath Mark reconciliation for main quests completed by older saves.

## Verification

- `tools/verify_prog_001.gd` checks all nine definitions, prerequisites, main-versus-side rewards, duplicate prevention, gameplay values, and save roundtrip.
- PROG-001 uses the WORKFLOW-002 `progression` profile plus the changed progression screenshot and a local Web export because browser HUD code changed.
- Production `web/` and Vercel remain untouched for this ordinary roadmap checkpoint.

## Running

Open `project.godot` in Godot 4.6.3 and press `F6`, or run:

```powershell
& "C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64.exe" --path "outputs\AshenOathTheRoadBetweenCrowns"
```

Complete a main quest to earn an Oath Mark, press `Tab`, then use a `Learn` button in the journal. Each branch unlocks from tier one to tier three.

## Next Ticket

`PERF-001` enforces browser performance and zone budgets. Four tickets remain, with production deployment after `MOBILE-001`.
