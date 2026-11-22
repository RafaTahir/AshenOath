# RECOVERY-004 Traversal and World Gate Result

## Scope

This checkpoint repairs the real-player route failure discovered during the
authoritative release run. It is limited to startup handoff, gate-test
positioning, Greyfen route dressing, and the paving density assertion.

## Changes

- Deferred the desktop launch-screen menu rebuild until the accept event ends,
  preventing the same keyboard accept from activating New Game.
- Made the gate verifier wait for the menu-hidden Greyfen prewarm before
  measuring the warm New Game handoff.
- Moved the collidable shrine barrel out of the diagonal Greyfen-to-Castle
  approach corridor.
- Kept route sweep targets inside the authored boundary-wall clearance.
- Increased the single Greyfen paving MultiMesh from 80 to 144 staggered,
  low-profile cobbles without adding collision nodes or draw calls.
- Removed temporary walk-debug logging after the route passed.

## Verification

- `verify_gate_transitions.gd`: PASS; bidirectional real CharacterBody route
  traversal through Greyfen, Wychwood, the campaign road, Castle approach,
  courtyard, and Record Hall.
- `verify_world_001.gd`: PASS; 1099 nodes, 336 meshes, 2 lights, 144 paving
  instances.
- Full source gate sequence through `verify_perf_003.gd`: PASS.
- Graphical Compatibility `verify_perf_001.gd`: PASS; approximately 60 FPS
  average in all sampled zones, 30.8-32.7 FPS 1% lows, 34.9 ms warm return,
  and 84.2-430.1 ms cold transitions.

## Remaining

The final export, screenshot, packed-startup, and fresh Chrome/Edge checks are
still required before promotion. Registry categories that remain explicitly
visually rejected or incomplete are not reclassified by this route fix.

## Running

From `D:\Projects\AshenOath\outputs\AshenOathTheRoadBetweenCrowns`:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\run_release_gate.ps1 -SkipExport -SkipPerformance -SkipScreenshots
```
