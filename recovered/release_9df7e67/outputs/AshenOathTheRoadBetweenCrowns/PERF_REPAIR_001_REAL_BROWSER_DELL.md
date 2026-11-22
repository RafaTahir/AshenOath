# PERF-REPAIR-001 — Real Browser and Dell Performance

## Scope

Raised the native 1280x720 Balanced performance gate without changing gameplay, resolution, or the Web export. Work stayed inside Greyfen routine ticking, ambient NPC ticking, and distant animation suspension.

## Changes

- Greyfen simulation updates at 10 Hz in Balanced and 15 Hz in Quality.
- Greyfen routine animation drivers update at 12 Hz in Balanced and 20 Hz in Quality.
- Far ambient NPC presentation ticks at 10 Hz instead of 20 Hz.
- Distance-suspended character animation disables the node process and animation player together.
- Existing route actors, combat actors, collision, and quest logic remain active and visible.

## Graphical Compatibility Result

| Zone | Average FPS | 1% low | Static memory |
|---|---:|---:|---:|
| Greyfen | 46.73 | 30.25 | 71.4 MB |
| Wychwood | 60.00 | 47.08 | 75.9 MB |
| Wychwood combat | 57.83 | 38.27 | 76.3 MB |
| Castle courtyard | 60.00 | 56.05 | 73.1 MB |
| Record Hall | 59.99 | 52.61 | 70.2 MB |
| Hart Glade | 60.01 | 54.22 | 70.0 MB |

- Average threshold: `>= 32 FPS` — PASS.
- 1% low threshold: `>= 30 FPS` — PASS; Greyfen is the floor at `30.25 FPS`.
- Warm return: `318.7 ms` — PASS (`<= 350 ms`).
- Cold transitions: `157.2–457.2 ms` — PASS (`<= 900 ms`).
- Static memory: below `450 MB` in every sample — PASS.
- Report: `.release-gate/perf_001_report.json`.

## Verification

- Graphical `verify_perf_001.gd`: PASS.
- `verify_greyfen_life.gd`: PASS.
- Parser checks for all changed scripts: PASS.
- Known Godot shutdown diagnostics from imported resources remain tracked by `ENGINE-REPAIR-001`; no active-frame assertion failed.

## Running Steps

From the project folder:

```powershell
& "C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64.exe" --path . --rendering-method gl_compatibility --display-driver windows --script res://tools/verify_perf_001.gd
```

For normal play, open the Web output with the project’s documented local server instructions; no export was performed for this ordinary ticket.

## Remaining Issues

The strict screenshot approval and full release suite still need to run. The production Web output remains unchanged until the repair milestone is complete.

## Next

`QA-REPAIR-001` — capture and approve current menu, route, character, combat, Castle, Hart, day, and night views.
