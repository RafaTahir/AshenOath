# WORLD-001 cemetery glazing, 2026-09-29

Status: one retained visual subcell; WORLD-001 remains pending at 27/37.

The established bell-side gameplay camera showed the fitted chapel window as
a dark recess. The authored two-surface window resource now has restrained
green glazing emission. Its source recipe, generated resource, runtime manifest
hash/size, and direct resource assertion were updated together. No chapel
collision, doorway, quest state, route or other resource was changed.

- `verify_cemetery_architecture.gd`: PASS, 137,315 bytes across all cemetery
  assemblies. Log: `D:/Temp/AshenOath/world001_cemetery_window_verify_20260929.log`.
- Graphical `capture_world_014.gd`: PASS, four 1280x720 staged frames at
  `.release-gate/world001_cemetery_window_final_20260929/`.
- Visual review: the bell-side frame now shows a legible muted green window,
  without the first trial's overbright panel. The entrance camera and route
  remain unchanged. This staged capture does not prove real-input travel or
  performance.

An independent Greyfen tree-threshold and ground-wear candidate was also
captured at `.release-gate/world001_threshold_candidate_20260929/`. It left
the smooth hill, road-end gap and disconnected work areas prominent. Its two
runtime edits were removed; it is rejected evidence, not retained work.

Remaining WORLD-001 blockers: Greyfen and cemetery horizon composition,
Greyfen street/work-area composition, and a grounded distinct Ghoulkin body
in the occupied Wychwood arena. Native PERF-001 is red. Do not export Web or
promote this subcell to ticket acceptance.

Running steps from the project root: use Godot 4.6.3 with
`--headless --path . --script res://tools/build_cemetery_architecture.gd -- --role=memory_window`
only after changing the source recipe, then run
`--headless --path . --script res://tools/verify_cemetery_architecture.gd`.
For the graphical four-view review, run
`--path . --rendering-method gl_compatibility --script res://tools/capture_world_014.gd -- --output-dir=res://.release-gate/<run>`.
