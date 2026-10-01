# WORLD-002 Assembly and Hart Composition Pass

## Outcome

Retained partial native/camera evidence. WORLD-002 remains visually rejected
at its complete campaign scope; progress remains 26/37 accepted. No Web,
performance, full-route or release acceptance is claimed.

## Changes

- Assembly: four CC0 settlement buildings, four native benches and three
  native reading tables in one two-surface baked mesh. Supported backdrop
  terrain, metre-scaled civic paving and flush dais replace the empty court.
- Every bench/table has matching collision. Outer benches move 0.6 m outward
  to retain a genuine player-sized eastern aisle. Witness positions stay intact.
- Four previously incorrect generated witness IDs now match existing Mira,
  Rook, Anwen and Record dialogue data. Humans use their existing approved
  bodies, identity palettes and animation; written evidence uses supported books.
- Focal assembly humans retain a 32 m mesh range. The generic 14 m crowd cutoff
  previously made Mira and Rook disappear from the normal court camera.
- Hart: irregular approach/clearing, distant terrain bank and tapered weathered
  witness stones replace the rectangular road and box monoliths. Four ritual
  collider footprints and rune emission are preserved. Focal stones remain
  governed by the existing unresolved/combat/aftermath branches. Stag, arena,
  actors, enemies, gates, four covenant choices and rewards are unchanged.
- Generated asset source/bytes/hashes and campaign export ownership are
  registered. No export was executed.

## Evidence

- `world002_finale_contract_v2.log`: clean native capsule sweeps along three
  eastern aisle offsets in both directions, address/return approaches, physical
  table tops, meshes/materials and real skeleton role resolution.
- `world002_finale_contract_v3.log`: clean PASS, including current manifest
  and export inclusion checks, with clean shutdown.
- `world002_finale_determinism_v1.log`: all three rebakes byte-identical, clean.
  Assembly 472,675 bytes / 30,334 triangles / two surfaces; Hart landscape
  4,680 bytes / 204 triangles / two surfaces; focal stones 2,082 bytes /
  32 triangles / one surface.
- `.release-gate/world002_finale_current/40_greyfen_assembly.png` and
  `41_white_hart_glade.png`: fresh grounded 1280x720 camera views inspected by
  Codex. Retained improvement in furniture, visible witnesses, supporting
  terrain and Hart depth; not final full-gallery approval or exact pixel-baseline
  certification. Existing camera smoothing produces a small framing variation.
- `world002_finale_route_v2.log`: clean graphical native Continue from the
  genuine prior assembly save, physical W/A/S/D approaches, E/Enter for all
  four correctly named conversations, witness-record clue, public testimony,
  pause-menu save/resume, Hart gate travel, finale save, Witness resolution and
  ending checkpoint with five epilogue cards. No teleport, flag mutation,
  direct handler or direct damage shortcut. Only the known Intel ANGLE advisory.
- Assembly route activation 862.0 ms; Hart 4,007.9 ms fails the 900 ms cold
  ceiling. A later capture's cached Hart activation of 394.0 ms does not erase
  that failure. PERF-001 remains native-red.

## Rejected Runs / Remaining Work

- Contract v1 caught bench snags; widening the real aisle fixes the cause.
  Its direct legacy helper call also produced fallback warnings; the final
  contract uses the same approved visual path as gameplay instead.
- First camera capture hid Mira/Rook and exposed unsupported backdrop houses;
  it is not accepted current evidence.
- Real-input v1 heard three real witnesses but missed the Record after dialogue
  changed camera bearing. v2 restores bearing with real keyboard input and keeps
  the physical front aisle, then passes all four conversations and the ending.
- Full campaign wilds, time/aftermath views, return routes, graphical performance,
  browser proof and final semantic visual approval remain open.

## Running Steps

From `D:/Projects/AshenOath/outputs/AshenOathTheRoadBetweenCrowns`:

```powershell
& 'C:/Temp/AshenOathGodot4.6.3/Godot_v4.6.3-stable_win64_console.exe' `
  --headless --path . --script res://tools/verify_finale_composition.gd
```

Graphical route uses an isolated copy of the genuine assembly save under
`D:/Temp/AshenOath/world002_finale_route`, child-only APPDATA/LOCALAPPDATA, and
`verify_opening_real_input_native.gd -- --continue-assembly-choice --finale-composition-proof`.
This scratch save has now advanced to the Witness ending; restore only a fresh
isolated copy of the genuine prior assembly fixture to rerun that leg.

No commit, push, merge, export or deployment. Production unchanged.
