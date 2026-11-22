# WORLD-001 Greyfen social square (2026-09-29)

Status: retained bounded composition improvement, not WORLD-001 acceptance.
Recovery remains **27/37**.

The original fixed spawn and social-table views placed the table and chairs at
the river lip; the complete mesh extended beyond the interaction center's
river-safety margin. The second board table had the same footprint problem.
The two complete setups are now located on worn village-side ground, with the
existing minigame interactions, opponents, board geometry and navigation
preserved. Ground vertex tint connects the sites to the existing street
without new materials, meshes, collision or draw calls.

Files changed: `scripts/zones/greyfen_section.gd`, `scripts/game.gd`,
`tools/verify_minigame_presentation.gd`, and `tools/capture_world_012.gd`.
The verifier now checks every authored seating footprint corner against the
Greyfen river. Its previous board, skeleton and minigame checks remain.

Direct evidence:

- Graphical minigame presentation verifier: PASS, including both river
  footprints. Log: `D:/Temp/AshenOath/world001_greyfen_social_verify_20260929.log`.
- Graphical WORLD-001 structural and route verifier: PASS, 857 nodes, 183
  meshes, four lights. Log:
  `D:/Temp/AshenOath/world001_greyfen_street_verify_20260929.log`.
- Same-camera spawn, former table location, and new table/barrel views:
  `.release-gate/world001_greyfen_social_square_20260929/`. All are 1280x720,
  nonblank, and were visually inspected. The fixed spawn-frame SHA-256 is
  `018990e2e2bb2515627b94c375f0c6739446eb12f1296aa15b8f5353daa4a68a`.
- No active parser, material, resource, renderer, or shutdown error appeared
  in affected runs. ANGLE emitted its pre-existing Intel driver advisory.

The table and board cells are visibly better supported, but the broad Greyfen
street and synthetic skyline remain unaccepted. The Wychwood occupied arena
still needs a final grounded Ghoulkin asset, and the cemetery backdrop remains
parked after rejected approaches. This result is neither full visual approval
nor native performance or real-input browser acceptance. No Web export,
commit, push, merge, or deployment was performed.

Running steps from the project root: run Godot 4.6.3 Compatibility with
`--script res://tools/verify_minigame_presentation.gd`, then
`--script res://tools/verify_world_001.gd`; capture with
`--script res://tools/capture_world_012.gd --
--output-dir=res://.release-gate/<run> --social-only`.
