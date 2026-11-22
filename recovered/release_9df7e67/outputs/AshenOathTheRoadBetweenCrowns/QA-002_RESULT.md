# QA-002 Result

## Outcome

The player-driven route harness now treats an unreachable waypoint as a real
failure instead of continuing through the remaining route. That keeps a long
headless run from timing out while hiding the first movement failure.

## Verification

- `tools/verify_gate_transitions.gd`: PASS.
  - Real New Game startup.
  - Full forward and return exterior loop.
  - Castle approach, courtyard, and Record Hall round trip.
  - Physical movement, interaction focus, `E` activation, grounding, velocity,
    and loading-overlay release checks.
- `tools/verify_river_swimming.gd`: PASS.
  - CharacterBody3D crossing in both directions for Greyfen and Wychwood.
  - No jump, river recovery, or below-ground arrival.
- `tools/verify_gate_transitions.gd` parser/runtime output contained no active
  `ERROR:` or `SCRIPT ERROR` lines.

## Changed Files

- `tools/verify_gate_transitions.gd`

## Known Limitations

This checkpoint proves the route harness and live bridge path. It does not
approve the broader visual, startup, performance, campaign, or deployment
requirements tracked by RECOVERY-004.

## Running Steps

```powershell
cd D:\Projects\AshenOath\outputs\AshenOathTheRoadBetweenCrowns
& C:\Temp\AshenOathGodot4.6.3\Godot_v4.6.3-stable_win64_console.exe --headless --path . --script tools\verify_gate_transitions.gd
& C:\Temp\AshenOathGodot4.6.3\Godot_v4.6.3-stable_win64_console.exe --headless --path . --script tools\verify_river_swimming.gd
```
