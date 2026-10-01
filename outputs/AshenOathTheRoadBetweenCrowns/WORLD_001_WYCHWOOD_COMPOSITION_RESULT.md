# WORLD-001 Wychwood Clearing Composition, 2026-09-29

Status: retained partial improvement; WORLD-001 remains pending visual acceptance.

The clearing's square mud slab and six primitive sphere stones were replaced
with an irregular textured clearing floor and one batched Quaternius rock
assembly. The east layby is now a curved, textured mesh rather than a straight
road slab. These are visual-only changes: collision, clue positions, actors,
and the bridge route were not moved.

Affected files: `scripts/game.gd`, `scripts/zones/wychwood_section.gd`, and
`tools/verify_world_013.gd`.

Evidence: the parser/import check exited cleanly; the graphical WORLD-013
verifier passed with no runtime errors; the four-view WORLD-013 capture passed.
Logs are under `D:/Temp/AshenOath/world001_wychwood_composition_20260929/`.
The new 1280x720 combat view is
`.release-gate/world001_wychwood_composition_20260929/WORLD-013_04_Wychwood_Combat_Clearing_20260929_023123.png`;
the same-camera prior view is
`.release-gate/world001_wychwood_frame/WORLD-013_04_Wychwood_Combat_Clearing_20260927_204842.png`.
The clue-route view remains materially unchanged.

Visual decision: retain the replacement. The prior floating black spheres and
large rectangular road slab are no longer present. A smaller hard-edged dark
patch remains visible in the clearing, and the forest floor and encounter
depth still need authored work. The capture is a staged art fixture, not
real-input route or performance acceptance. No FPS or browser claim follows
from it.

Next WORLD-001 action: resolve the remaining Wychwood clearing patch and
floor/depth defects as one scene-level composition pass, then inspect the
same cameras once. Greyfen and cemetery cells remain separately open.
