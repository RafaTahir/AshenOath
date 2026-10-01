# ACCESS-001 Weapon Context and Remapping - 2026-09-27

## Outcome

Retained native input repair; ACCESS-001 remains pending. Current recovery count
is 27/37 accepted. No export, commit, push, merge or deployment occurred.

Controller events were restoring InputMap on every button/axis event, losing
action state and rebuilding the controls menu. Profiles now apply only when
the selected device changes, preserving that selecting event without replaying
GUI input. X switches sword/bow; Y remains jump. LT aims in bow mode and casts
Oathfire in sword mode. D-pad arrow selection no longer also zooms the camera.
Keyboard 1/2 and separately bound Oathfire retain their existing behavior.

Saved multi-key bindings restore all keys, not only the final key. Only the exact
old default Y-sword/X-bow pair migrates to X weapon cycling; explicit custom
profiles and unrelated bindings remain. All 31 actions are exposed over six
remapping pages. Enter selecting a row no longer becomes its binding: activation
owns its event, and the next input is captured before GUI navigation. Changing
device glyphs preserves ammunition state. Waiting remaps survive profile updates.

## Evidence and Limits

- `access_contracts_20260927.*` under D:/Temp/AshenOath: focused weapon dispatch,
  INPUT-003, INPUT-004 and ACCESS-001 logic contracts pass cleanly. Synthetic
  controller events are not physical-controller certification.
- `access_remap_dispatch_before_20260927`: the isolated rendered-Control input
  pipeline reproduces the initiating-Enter binding bug. The first edit's parser
  failure is retained as failed evidence, not a passing run.
- `access_remap_dispatch_after_v2_20260927` and
  `access_binding_complete_20260927`: saved keys, legacy migration, custom
  profiles, all action pages, real GUI Enter/H dispatch and ammo preservation
  pass with exit 0 and no runtime errors.
- `access_context_graphical_v1_20260927`: actual New Game weapon path passes;
  real remapping fails. Rejected as whole-run acceptance.
- `access_context_graphical_v2_20260927`: graphical Compatibility, native
  1280x720, real keyboard menu startup, actual player controller and inventory.
  Y preserves bow; LT aims without Oathfire; RT emits exactly one real shot and
  reduces arrows from 24 to 23; arrow selection preserves camera distance;
  repeated X switches both ways. All six visible remap pages, H assignment,
  Reset Defaults, keyboard fallback after logical disconnect and Resume pass.
  Exit 0; only the existing ANGLE driver advisory, no active/shutdown errors.
  Subsequent ammo-label fix has directly affected isolated contract proof;
  the retained graphical proof does not claim a new final visual/source hash.
- Inspected `access001_real_bow_aim.png`, `access001_real_remap_weapons.png` and
  `access001_real_remap_targets.png`: 1280x720, visible focus and H binding;
  final Back/reset controls fit, longer page uses scroll. Bow/world frame is
  input evidence, not approval of pending world composition or equipment art.
- Ticket `weapon_input` profile and authoritative release list include all
  three new tests; graphical fixture rejects headless substitution. Runner
  parsers and profile JSON pass.

No player transform, quest flag or interaction handler is mutated. Logical
controller notification/input tests detected zero physical devices. Xbox,
PlayStation, Switch and generic physical families remain explicitly untested.
Existing pause/save/dialogue/resize proofs retain their dependency scope.

## Running and Next Dependency

From D:/Projects/AshenOath/outputs/AshenOathTheRoadBetweenCrowns, use an isolated
APPDATA/LOCALAPPDATA child under D:/Temp/AshenOath and a bounded owned process:

```powershell
& $Godot --headless --path . --script tools/verify_access_binding_restore.gd
& $Godot --headless --path . --script tools/verify_access_weapon_context.gd
& $Godot --path . --rendering-method gl_compatibility `
  --script tools/verify_access_context_real_input.gd
```

Native input defects are resolved. Full browser certification is dependency-
blocked by native PERF-001; do not export while it is red. Reuse these proofs
unless their actual dependencies change. After the native blocker clears,
one source-aligned browser artifact must prove pause, remapping, weapon context,
resize, audio/focus and persistence in Chrome, then Edge on the same bytes.
