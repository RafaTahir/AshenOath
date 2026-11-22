# PERF-008 Result

## Changes

- Added a product performance contract gate for native render scale, Potato/Balanced/Quality determinism, 30 FPS target telemetry, foliage, visual density, and shadow budgets.
- Updated the ticket runner so every Godot gate receives an isolated engine log instead of sharing the redirected summary file.
- Preserved existing zone budget and performance telemetry sources.

## Verification

- verify_perf_008.gd: PASS
- verify_zone_budgets.gd: PASS
- Product ticket gate: PASS

## Known limitation

This ticket gate validates budget configuration and telemetry contracts. The Dell 7280 hardware/browser 1% low acceptance is still a release gate and is not claimed here.

## Running steps

    .\tools\run_ticket_gate.ps1 -Profiles product -NoCache

## Runtime follow-up

The ticket now includes concrete runtime lifecycle and performance work:

- `PerformanceBudgetMonitor` is bound to zone activation, transition timing,
  quality preset, lifecycle snapshots, and explicit budget refreshes.
- Compass updates reuse the indexed interaction-area cache instead of scanning
  a complete procedural zone.
- Ambient prop motion is centralized and distance-bounded with deterministic
  Potato/Balanced/Quality caps; interactive state components no longer run a
  duplicate per-prop process loop.
- Bone-attached equipment remains under skeleton control, enemy peer lists and
  camera enemy candidates are cached, stale freed actors are ignored, and
  cosmetic player foot probes run at 30 Hz while movement/combat stay full-rate.
- Temporary benchmark-only process disabling and timing hooks were removed;
  the graphical gate measures the runtime path directly.

The final clean graphical Compatibility run passed native 1280x720 Balanced:
Greyfen `59.9 / 34.0`, Wychwood `59.9 / 33.5`, Wychwood combat `55.3 / 30.1`,
Vargan courtyard `60.0 / 40.5`, Record Hall `60.0 / 52.1`, and Hart Glade
`60.0 / 46.7` FPS average/1% low. Static memory stayed below 106 MB, cold
transitions stayed below 264 ms, and the warm return was 60 ms.

No active gameplay parser, resource, material, or camera errors were emitted.
Known Compatibility renderer/RID/ObjectDB messages remain shutdown-only
diagnostics for `ENGINE-004`; they are documented rather than suppressed.

This remains a development checkpoint. Browser/Web export, complete campaign
real-input coverage, final visual approval, and production deployment remain
open.

## Runtime follow-up - 2026-08-21

- Combat feedback now reuses shared meshes and cached materials for ground rings,
  impact shards, parry/block flashes, blade contact, Oathfire endpoint pieces,
  and enemy warning markers. Wave activation prewarms the same resources used by
  the live combat path, preventing first-use VFX allocation during a fight.
- Non-boss enemy decision work is capped at a stable 30 Hz while collision,
  attack timing, animation state, and boss phase processing remain authoritative.
- The graphical Compatibility benchmark is paced at 60 Hz to match the Web
  compositor budget. The acceptance thresholds remain unchanged: 32 FPS
  average and 30 FPS 1% low.
- Isolated native 1280x720 Balanced run passed: Greyfen `56.5 / 35.4`,
  Wychwood `59.4 / 35.5`, Wychwood combat `58.0 / 34.0`, Vargan courtyard
  `60.0 / 50.8`, Record Hall `60.0 / 51.6`, and Hart Glade `60.0 / 52.0`
  FPS average/1% low. Static memory remained below 106 MB and all measured
  transitions stayed below the 350/900 ms limits.
- Targeted combat, world, and navigation gates pass after this follow-up.
  Shutdown-only renderer diagnostics remain classified after verifier pass
  markers; no active gameplay renderer/material error was observed.
