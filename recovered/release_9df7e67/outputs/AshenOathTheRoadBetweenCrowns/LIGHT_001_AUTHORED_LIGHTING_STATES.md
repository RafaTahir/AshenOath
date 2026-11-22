# LIGHT-001 Authored Lighting States

## Changes

- Added authored outdoor and interior profiles for every released zone family.
- Aligned dawn, day, dusk, and night illumination with the 36-minute clock.
- Fixed Balanced cloud construction, celestial billboarding, Wychwood cloud visibility, and stale night-light caches.
- Preserved reduced Potato cloud/star density and shadowless local lights.

## Verification

- `tools/verify_light_001.gd` checks profiles, phases, celestial exclusivity, interiors, persistence, readability floors, and quality budgets.
- `tools/capture_light_001.gd` captures only Greyfen, Wychwood, Castle exterior, and Record Hall lighting views at 1280x720.
- Content integrity, runtime smoke, visible quality, zone budgets, LIGHT-001, and all eight changed views passed.
- A repeated completion run returned cached passes for every gate in 2.8 seconds.
- Screenshots: `verification_screenshots/light_001/` and `Development_Gallery/screenshots/LIGHT_001_*`.
- This is an ordinary WORKFLOW-002 checkpoint. It does not export, update `web/`, or deploy production.

## Running

Open `project.godot` in Godot 4.6.3 and press `F6`, or run the current source from PowerShell:

```powershell
& "C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64.exe" --path "outputs\AshenOathTheRoadBetweenCrowns"
```

The public Vercel build intentionally remains on the last production milestone.

## Next Ticket

`SAVE-001` adds versioned migration, backups, and invalid-position recovery. Six tickets remain; production stays unchanged until the complete seven-ticket milestone is finished.
