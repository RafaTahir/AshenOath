# OATH-001 Result - Oathfire Presentation Contract

Status: accepted on 2026-09-21.

## Delivered

- Oathfire owns one state sequence for sheathing, locked initial facing,
  two-hand charge, release, collision-clipped impact, redraw, and cancellation.
- Charge origin now derives from the live left/right hand-bone poses rather
  than one-frame-stale attachment transforms. The central charge, rendered
  hands, damage corridor, and release beam therefore share one origin.
- Arm IK converges both hands in front of Kael while the sword remains safely
  sheathed, then releases on redraw, transition cancellation, and excluded
  equipment states.
- The beam visual midpoint and length are checked against the authoritative
  cast origin/endpoint, and the endpoint flare is checked against the same
  collision result.

## Verification

- `tools/verify_oath_002.gd`: PASS under graphical Compatibility rendering.
- Initial facing remains locked after player rotation.
- Charge hand effects match live hand bones; projected charge center is 6.4
  pixels from the projected hand midpoint against a 36-pixel limit.
- Wall clipping, one-shot release, cooldown, redraw, transition cancellation,
  effect cleanup, and sword restoration pass.
- Rendered evidence inspected:
  `D:\Temp\AshenOath\oath001_charge.png` and
  `D:\Temp\AshenOath\oath001_release.png`.
- Detailed log: `D:\Temp\AshenOath\oath001_screen_alignment.log`.

## Remaining Scope

Final production-browser combat-route certification remains owned by
`CERT-001`; broader authored world/VFX polish remains owned by the presentation
and world tickets.

## Running Steps

```powershell
$godot = 'C:\Users\User\.cache\codex-runtimes\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe'
& $godot --path . --script res://tools/verify_oath_002.gd
```
