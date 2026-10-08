# LR-009 - A Companion Who Keeps Up

Status: implemented_local_awaiting_user. Local production packaging completed.
Per the 2026-10-08 amendment, no per-ticket push or deployment is authorized.
This work remains local until the combined final release after LR-028.

## Implemented

- Adopted Bracken follows from a rear/side offset, stops short of Kael and moves
  through CharacterBody physics. Bounded steering checks live obstacles and floor
  support; route construction uses the existing zone spatial/bridge authority.
  River crossings route through bridges, including approaches, never across water.
- Actual horizontal motion drives walk/idle blending, playback speed and yaw.
  The model and complete skeleton remain the LR-008 runtime asset. Bracken has no
  hostile health/damage receiver and never becomes permanent ordinary-combat loot.
- Follow, wait and recall commands use the existing menu/input system. Default V
  opens commands; D-pad Down tap does the same after adoption. Its existing zoom-out
  remains on a 450 ms hold. Before adoption zoom behaves as before. Mouse wheel,
  Page Down, first person and full orbit remain unchanged.
- Companion command is remappable. Existing custom V/D-pad assignments take
  precedence; context/focus resets cancel incomplete presses. Pause also exposes
  Bracken's commands for pointer, keyboard, controller and touch navigation.
- Command, sector and last supported position save additively in story state.
  Old adopted saves default to follow without replacing rescue/refusal outcomes.
  Waiting survives departure/reload. The outgoing actor is removed before zone
  caching; installation creates only the active zone's appropriate instance.
- Arrivals use validated support/occupancy behind Kael. Invalid resting positions
  use existing same-bank recovery rules while preserving wait/follow intent. Zone
  failure restores presence in the returned zone. Loading another save does not
  capture the departing journey's position over the restored state.
- A stuck follower can recover only when his whole sampled bounds and a clear,
  same-bank destination are outside the gameplay camera. Remote recall also waits
  for an unseen supported arrival. No clear anchor means waiting, not collision
  bypass or visible teleportation. Ordinary travel to a new sector stages the
  actor behind Kael rather than pretending both local coordinate spaces are one.
- The discarded harness now belongs to the Greyfen scene, not the moving body.
  Companion coordinates are excluded from geometry-cache signatures because the
  actor is restored separately; moving him does not invalidate authored scenery.

## Files And Static Review

`scripts/companion_controller.gd`, `zone_runtime_coordinator.gd`, `save_manager.gd`,
`input_router.gd`, `camera_controller.gd`, `game.gd`, `hud.gd`; project/ticket
records and generated Web/pack data. Existing spatial service is reused unchanged.

Static review covers dialogue focus retention, spatial route queries, body-only
retirement, save ordering, default/custom binding conflict handling, menu Back,
normal zoom/first-person ownership, wait persistence and guarded recovery.
No tests, game launches, browser QA, screenshots or performance runs executed.
Minimum production packaging completed. The initial import found two
uninferred local Node types; explicit Node declarations corrected those compiler
errors. The required build was retried successfully; no runtime tests followed compilation.

## Local Artifact

- Build: `lr-009-20261008-companion-travel`.
- Source: `9a279c44a4a2187740117a842b302eb75b02a5e2` plus dirty working changes.
- Build directory: `D:\Projects\AshenOath\.release-gate\LR-009-20261008-build`.
- Full `web/` including manifests: 92,023,442 bytes, below 104,857,600 bytes.
- Stored root PCK SHA-256: `43494ecf2e56ffd83c1c89bc53553e9ba9c5f9376b7499c54941faff8dda1a12`.
- Decoded root PCK SHA-256: `627cd16e317c2e5ba83d3db63119124b8c32de09598b07392bb81433ee31cce2`.
- No ticket commit, push, main integration or deployment. Production remains LR-008.
- The build manifest retains its original source provenance. Later local tickets
  will require the final combined export, not relabelling these bytes.

## Unverified

UNVERIFIED - REQUIRES USER TESTING: bridge/path movement, crowd avoidance, camera
visibility during recovery, waiting/recall through sectors and interiors, input
focus/remapping and Save/Continue. Complex scenery can make Bracken wait until an
unseen clear anchor is available; no arbitrary teleport is used to hide that.

## Manual Test Checklist

1. Adopt Bracken, walk both directions across Greyfen/Wychwood bridges, then enter
   and leave an interior. Confirm walking/facing, safe routes and one visible hound.
2. Use V or tap D-pad Down to wait/follow/recall; hold D-pad Down to zoom out.
   Remap the command, use Pause > Bracken, and confirm Back resumes normally.
3. Leave him waiting, change zone, Save/Continue, then return or recall. Confirm
   his command/location persist, recovery stays out of view and the harness stays
   beside Greyfen's road.
