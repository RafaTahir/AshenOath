# ACCESS-001 Pause Ownership Repair - 2026-09-27

## Scope and Outcome

The demonstrated player-movement-while-paused regression is repaired at native
graphical scope. ACCESS-001 remains pending for the complete accessibility,
browser and available-device matrix. Formal recovery count remains 26/37.

Kael inherited Game's always-processing mode. Explicit pausable ownership now
covers the controller and child stamina/animation. Both menu-prewarm handoff
sites and normal/cached zone activation preserve that ownership. The menu,
loading coordinator and InputRouter remain active; camera already checks pause.
Velocity and combat state are preserved rather than cancelled on pause.

Changed runtime files: `scripts/player_controller.gd`, `scripts/game.gd`,
`scripts/zone_runtime_coordinator.gd`. The new bounded real-input fixture is
`tools/verify_paused_player_real_input.gd`, registered as graphical-only in the
ticket and full release runners. It refuses headless proof.

## Evidence

- Parser check: PASS.
- `D:/Temp/AshenOath/access001_pause_after.log`: PASS, real focused New Game,
  Escape pause, held W/A/X/attack, invariant position/velocity/combat/stamina,
  Escape resume and actual forward movement, keyboard-focused Save, paused
  movement rejection and resume. Clean exit, no renderer/resource errors.
- `D:/Temp/AshenOath/access001_pause_continue.log`: PASS on an isolated copy of
  that genuine manual save. Real focused Continue exercises the normal zone
  activation branch, then the same menu/input assertions, plus explicit child
  AnimationPlayer and stamina processing checks. Clean exit, empty stderr.
- The first fixture run `access001_pause_before.log` is rejected as a controlled
  comparison: it used Space, which legitimately activates focused UI Resume.
  The corrected fixture uses the actual jump key X. Historical genuine Castle
  manual-save held-A failure remains the demonstrated original regression.
- `D:/Temp/AshenOath/access001_pause_input.png` is a fresh native menu canvas
  capture, inspected for visible focus and unclipped controls. Native menus use
  a 1920x1080 virtual canvas; this is not a 1280x720 final gallery approval or
  gameplay-FPS evidence. The broader changed-view gallery remains outstanding.

No player position, story flag or interaction handler is mutated by this proof.
Profiles and browser-independent scratch files reside under D:/Temp/AshenOath.
Original saves and production files are untouched. No commit/push/deploy.

## Running and Remaining Work

## Shared World Ownership - Retained Follow-up

The same inherited ALWAYS defect affected the active world. New Greyfen and
campaign roots, covered caches and cache reactivation now own PAUSABLE mode;
inactive caches remain DISABLED. No per-enemy pause polling was added.

- `access001_zone_pause_before.log`: FAIL (4), genuine native cache/activation
  ownership permits world clocks and actor hierarchy to process while paused.
- `access001_zone_pause_after.log`: PASS; world clocks stop, inactive cached
  roots remain stopped, activation resumes, and the ALWAYS menu clock continues.
  This is an explicit ownership/system fixture, not real-input route proof.
- `access001_ai_pause.log`: PASS; the actual five Wychwood actors retain frozen
  position/velocity/attack/windup/animation clocks and cannot damage Kael while
  paused, then the existing AI pursuit/spacing/reservation/bone-contact checks
  pass after resume. The fixture uses diagnostic staging, not player-route proof.
- `access001_pause_world_final.log`: graphical PASS on a copy of the genuine
  save. Visible menus reject movement; real keyboard Save/Continue and Escape
  work. Physical Anwen approach/focus/E, held-input freeze through dialogue,
  actual keyboard pagination and resumed movement pass with empty stderr.
- `access001_anwen_dialogue.png`: fresh native 1280x720 dialogue evidence.
  This does not approve the whole world's visual quality or all accessibility.

Additional runtime file: `scripts/zone_residency_service.gd`. The bounded
`verify_zone_pause_ownership.gd` joins the graphical pause fixture in targeted
and full release gates; actual AI pause assertions are part of `verify_ai_001`.
Only affected source/native checks ran. Browser certification still waits for
native performance; unavailable physical controllers remain explicitly untested.

From the canonical Godot project, with an isolated APPDATA/LOCALAPPDATA child
environment and the graphical Godot console binary:

```powershell
& $Godot --path . --rendering-method gl_compatibility `
  --script tools/verify_paused_player_real_input.gd
# Repeat from a copy of the genuine save produced above:
& $Godot --path . --rendering-method gl_compatibility `
  --script tools/verify_paused_player_real_input.gd -- --continue
```

Full ACCESS acceptance still requires browser paused combat/world simulation, remapping,
keyboard/gamepad focus, subtitles/reduced motion, resize and disconnect behavior
on source-aligned browser bytes. Unavailable physical devices stay untested.
No new Web export while PERF-001 is native-red. Next dependency: one affected
Greyfen graphical performance check after this lifecycle/processing change,
then the source-aligned browser/accessibility matrix when that blocker clears.
