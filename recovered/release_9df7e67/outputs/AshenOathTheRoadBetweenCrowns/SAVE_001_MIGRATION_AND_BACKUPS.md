# SAVE-001 Migration And Backups

## Changes

- Advanced the save schema to version 5 without changing subsystem save formats.
- Added atomic temporary-file publication and one rotating backup for manual, autosave, and checkpoint slots.
- Added corrupt-primary recovery, ordered checkpoint fallback, future-version rejection, nested schema sanitization, and safe health/stamina restoration.
- Migrated legacy Road of Crows reporting, Ghoulkin counters, unknown zones, and invalid positions without inventing story choices.

## Verification

- `tools/verify_save_001.gd` covers migration, corruption, backup generations, fallback order, temporary-file cleanup, and same-bank spatial recovery.
- Content integrity, runtime smoke, story campaign, Road of Crows, Teeth in the Rain, and SAVE-001 gates passed.
- No screenshots were generated because this ticket has no visual changes.
- This is an ordinary WORKFLOW-002 checkpoint. It does not export, update `web/`, or deploy production.

## Running

Open `project.godot` in Godot 4.6.3 and press `F6`, or run:

```powershell
& "C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64.exe" --path "outputs\AshenOathTheRoadBetweenCrowns"
```

Use the pause menu to create a manual save. Each slot now keeps its previous valid generation as a `.bak` file and recovers it automatically when required.

## Next Ticket

`PROG-001` implements the compact nine-upgrade progression. Five tickets remain after SAVE-001; production stays unchanged until the seven-ticket milestone completes.
