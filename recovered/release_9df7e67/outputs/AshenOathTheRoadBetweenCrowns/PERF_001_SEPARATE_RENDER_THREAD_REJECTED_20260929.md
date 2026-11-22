# PERF-001 Separate Render Thread Rejected

Status: diagnostic only; PERF-001 remains pending and Recovery-004 remains
27/37 accepted. No game, renderer setting, verifier limit, export or production
artifact changed.

The unmodified Godot 4.6.3 native executable ran the existing graphical
Greyfen verifier at 1280x720 Compatibility with only the command-line
`--render-thread separate` override. On this Dell Intel/ANGLE path, the
engine warned that the separate rendering thread is experimental, then
failed before the game started with `Error initializing GLAD`.
There is no FPS or visual comparison to infer from this failed initialization.
Full log: `D:/Temp/AshenOath/perf_render_thread_separate_20260929.log`.

The separate-thread mechanism is therefore unavailable for the required
Compatibility/ANGLE runtime and is not a candidate fix. Do not retry it as a
scene scheduling variant. Preserve the mixed draw/link/process attribution;
the remaining systemic render solution must work on the actual backend and
pass complete startup, hydration, settled FPS, transitions and memory gates.
