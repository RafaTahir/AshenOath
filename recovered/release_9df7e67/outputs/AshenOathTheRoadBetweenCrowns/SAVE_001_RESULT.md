# SAVE-001 Result

## Scope

Accepted the current persistence and migration contract without touching the
player's real save files. Full campaign choice/ending permutations remain a
separate certification gate.

## Changes

- `scripts/game.gd`
  - Treats `ZoneSpatialService` recovery results as walkable surface points and
    lifts all loaded positions to the player capsule origin clearance.
  - Preserves higher authored elevations and the existing bridge-specific path.
- Existing save infrastructure retained:
  - Atomic primary/backup publishing and corrupt-primary recovery.
  - Explicit future-version rejection without silently loading an older backup.
  - Sanitized legacy quests, story values, settings, inventory, vendor state,
    world counters, and objective presentation.
  - Deferred restoration of health, stamina, and equipment after zone creation.

## Verification

- `verify_save_001.gd`: PASS.
- `verify_save_003.gd`: PASS, including invalid Wychwood position recovery,
  same-bank identity, river exclusion, and capsule grounding.
- `verify_deferred_player_restore.gd`: PASS.
- `verify_save_version_boundary.gd`: PASS.
- No real `user://` player save was modified; focused fixtures clean their own
  isolated test slots.

Evidence is under `D:\Temp\AshenOath\save001_*.log`.

## Browser Acceptance

The source-aligned 15-file, 99.1 MB QA artifact has root PCK SHA-256
`fb22ff3b61b73772950d645503f1abf5c1b304928aace545b76c167383f5ccd5`.
On those exact bytes, Chrome and Edge each passed two same-profile refresh paths:

- Real mouse Pause -> Save -> refresh -> visible Continue -> controllable Greyfen.
- Automatic opening checkpoint -> refresh -> visible Continue -> controllable Greyfen.

The four reports are under `D:\Temp\AshenOath\save001_{chrome,edge}_{clicksave,auto45}.json`.
Warm-menu screenshots were inspected and explicitly show `Continue source: manual save`
or `Continue source: safe checkpoint`; all runs had zero console/resource errors.
The first automatic Edge trial reloaded after only 32 seconds of wall time and
found no save. The browser driver incorrectly equated that with 30 seconds of
uninterrupted game time and also captured the HTML shell before it was hidden.
The corrected driver waits for the actual Godot menu and allows 45 seconds
for the 30-second checkpoint timer plus Web stalls. This is not a claim that
the first checkpoint always appears by 32 seconds of wall time.

Legacy, corrupt, future-version, invalid-position, and deferred-state cases
remain covered by the native fixtures above. Browser upgrade across a future
deployed revision, every zone, and ending permutations belong to CERT-001.

## Running Steps

```powershell
Set-Location D:\Projects\AshenOath\outputs\AshenOathTheRoadBetweenCrowns
$godot = 'C:\Users\User\.cache\codex-runtimes\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe'
& $godot --headless --path . --rendering-method gl_compatibility --audio-driver Dummy --script tools/verify_save_001.gd
& $godot --headless --path . --rendering-method gl_compatibility --audio-driver Dummy --script tools/verify_save_003.gd
& $godot --headless --path . --rendering-method gl_compatibility --audio-driver Dummy --script tools/verify_deferred_player_restore.gd
& $godot --headless --path . --rendering-method gl_compatibility --audio-driver Dummy --script tools/verify_save_version_boundary.gd
```
