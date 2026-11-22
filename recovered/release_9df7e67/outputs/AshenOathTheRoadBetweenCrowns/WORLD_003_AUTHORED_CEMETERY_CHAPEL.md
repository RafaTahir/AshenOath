# WORLD-003 Authored Cemetery and Crow Chapel

## Result

Greyfen Cemetery is now an authored investigation quarter rather than a perimeter shell. The approach, grave court, ruined chapel, bell frame, Crow Shrine, and sealed ossuary have distinct silhouettes while preserving every existing quest interaction.

The Greyfen road to Castle Vargan was repaired at the same time. The collapsed berm that occupied the transition was removed, the east fence now leaves a full opening, and the route is reserved by `ZoneSpatialService`.

## Files Changed

- `scripts/zones/cemetery_section.gd`: WORLD-003 environment ownership and composition.
- `scripts/zones/greyfen_section.gd`: authored Castle road and open east boundary.
- `scripts/game.gd`: unobstructed, correctly oriented Castle transition.
- `scripts/zone_spatial_service.gd`: persistent Castle gateway reservation and safe arrival.
- `tools/verify_world_003.gd`, `tools/capture_world_003.gd`, and `tools/run_release_gate.ps1`: mandatory route, interaction, transition, and graphical acceptance.

## Acceptance

- All cemetery clues remain present and outside structural walls.
- The cemetery approach and chapel threshold remain navigable.
- The Castle Vargan gateway is accessible from a fresh New Game without a quest-state lock.
- No berm, fence, tree, or prop collider occupies the Castle road corridor.
- Interacting with the Greyfen gate reaches the verified Vargan approach spawn.
- Native 1280x720 proof captures are stored in `Development_Gallery/screenshots/`.
- Graphical acceptance passed at 37.6 FPS average, 36.5 FPS minimum, and 150 ms warm transition on Intel HD 620/ANGLE.
- The verified production Web payload remains 63.4 MB.

## Known Limits

WORLD-003 authors the existing cemetery and chapel content; it does not add a new quest or enemy. The existing Bell Beneath Greyfen interactions remain responsible for narrative progression.
