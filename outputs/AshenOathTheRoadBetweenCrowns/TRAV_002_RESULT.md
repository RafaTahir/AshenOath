# TRAV-002 Result

Status: **accepted** on 2026-09-20.

## 2026-09-26 Regression Closure

Reopened after genuine story traversal reached an unbroken end wall in front of
the assembly gate. Both undercroft end walls now retain their original envelope
with gate-aligned piers and lintels; the rear visible stone matches its opening.

`D:/Temp/AshenOath/undercroft_doorways_native_v1.log` passes real-input walk-throughs
of both openings in both directions without jumping and the public-record choice.
`D:/Temp/AshenOath/undercroft_return_native_v1.log` passes focused E travel through
assembly, undercroft, Record Hall, undercroft and assembly, plus consequence save
round trip. Both exit cleanly except the environmental ANGLE driver advisory.
Current gameplay-camera images under the same directory, named
`undercroft_record_door_gameplay.png` and `undercroft_assembly_door_gameplay.png`,
were inspected for route clearance. They do not approve the unfinished interior
art. Cold undercroft construction measured 5621.6 ms and remains a PERF-001 failure.
The public-record run resumed a genuine undercroft save; it is not uninterrupted
full-campaign proof. Historical unaffected route checks are preserved.

## Completed Work

- Replaced fixed-frame bridge assumptions with bounded destination-bank and
  genuine-stall detection in `tools/verify_river_swimming.gd`.
- Aligned reciprocal exterior arrivals with their destination lanes and kept
  them clear of transition trigger radii in `world_sector_manifest.json`.
- Added manifest assertions for reciprocal arrival lanes and trigger separation
  to `tools/verify_gate_transitions.gd`.
- Made the route audit follow declared authored approach legs where a sector's
  road bends around scenery instead of requiring one empty diagonal across the
  entire zone.
- Moved two Wychwood ritual stones west of the reserved north-arrival corridor
  while retaining the clue cluster and combat clearing.

## Root Cause

The campaign's reciprocal arrivals were historically centered even where the
physical destination lane was offset. After those arrivals were corrected, the
old gate verifier still swept a direct diagonal from Wychwood's north arrival
to its south boundary. That diagonal crossed legitimate ritual-clearing props
and trees rather than the authored side road. The final contract records and
physically drives the intended road legs before crossing the sector boundary.

## Verification

- `D:\Temp\AshenOath\trav002_gate_route_contract_v2.log`
  - Complete exterior and Castle route in both directions: PASS.
  - Wychwood north arrival through the authored return road to Greyfen: PASS.
- `D:\Temp\AshenOath\trav002_river_final.log`
  - Greyfen and Wychwood physical bridge crossings and river recovery: PASS.
- `D:\Temp\AshenOath\trav002_navigation_final.log`
  - Navigation routes, bridge-only crossing, pursuit, and recovery: PASS.

No Web artifact was rebuilt because this ticket changes route data, verifier
behavior, and Wychwood scenery only. Production-browser certification remains
owned by `WEB-001` and `CERT-001`.

## Running Steps

```powershell
cd D:\Projects\AshenOath\outputs\AshenOathTheRoadBetweenCrowns
& 'C:\Users\User\.cache\codex-runtimes\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --script res://tools/verify_gate_transitions.gd
& 'C:\Users\User\.cache\codex-runtimes\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --script res://tools/verify_river_swimming.gd
& 'C:\Users\User\.cache\codex-runtimes\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --script res://tools/verify_navigation_001.gd
```
