# Milestone 4 - AI, Navigation, Physics and Camera

OPT-025 through OPT-032 implementation is present. Compilation and packaging
follow; gameplay and performance acceptance remain user-owned.

- OPT-025: active encounter registrations share an XZ spatial index. Enemy
  movement updates its registration before/after body movement. Separation and
  attack-lane broad phases retain their exact distance, state and lane checks;
  attack reservations still use the complete owned encounter peer list.
- OPT-026: bounded deterministic routes are cached by validated endpoints,
  clearance and spatial data revision. Endpoints still receive fresh occupancy
  checks, and actual actor movement still validates against live colliders.
- OPT-027: equivalent perception results can be reused within the same physics
  step and positions; camera visibility is shared only inside one synchronous
  read-only view update. Damage/contact rays always remain fresh.
- OPT-028: static exclusion rectangles, reserved corridors and bridge spans
  use a broad-phase bounds grid. The original exact containment and bridge-only
  crossing contract remains authoritative. Registration invalidates route caches.
- OPT-029: enemy, combat, camera and occupancy owners reuse private ray/shape
  query objects, resetting every mutable field before each request. Camera
  obstruction exclusions now explicitly use the player's physics RID.
- OPT-030: identical data-only segment checks within the same physics step are
  reused with bounded storage and immediate registration invalidation. Live
  occupancy and authoritative collision/contact queries are not cached.
- OPT-031: target filtering shares view-update visibility results and computes
  angular/distance sort keys once per candidate. Orbit collision checks remain
  immediate on actual rotation/position changes; 360 yaw/first person are retained.
- OPT-032: initial enemy perception/repath deadlines and crowd decision deadlines
  are staggered without lengthening their existing periods. Movement, collision,
  damage, attack timing and active animation physics cadence are unchanged.

## User Checks

1. Cross bridges both ways, including off-center and backward travel.
2. Check crowd approaches and five-enemy spacing/reservations near obstacles.
3. Rotate the camera, target/switch enemies, zoom into first person and enter rooms.
4. Use melee, parry, bow and Oathfire; contact must respect live obstructions.
5. Pause/return, reload saves and revisit cached zones after consequences.

## Build / Publication

Build-only production compilation and packaging succeeded:
`opt-m4-20261018-2b1a54a` at
`D:\Projects\AshenOath\.release-gate\opt-m4-20261018\export`.
Manifested artifacts: 104180777 bytes, strictly below 104857600.
Root PCK: 9023521 bytes; SHA-256
`a363742d831bf77edfb40a8f74a0f5283abf6b3b37ed2cd34c53213c1914195e`.
Publication uses the OPT-032 receipt. No runtime test, browser, benchmark,
automated gameplay or screenshot capture was executed; acceptance remains yours.
