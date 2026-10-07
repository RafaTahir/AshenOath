# LR-003 - Draw, Sheathe and Interrupt

Status: implemented and packaged; publication pending. User acceptance pending.

## Implemented

- EquipmentLoadout owns bounded draw (0.64 seconds) and sheath (0.58 seconds)
  phases. Hand/back visibility transfers once at the contact fraction; switching
  returns the old weapon before drawing the requested one.
- H toggles draw/sheath. Tap the controller weapon-cycle binding to select the
  next weapon; hold for 0.45 seconds to toggle sheathing, without a second action
  on release. Existing saved key remaps retain precedence over H's new default.
- Retained compatible animation clips support stationary transfers; existing
  skeleton arm handling supplies the reach and leaves moving locomotion intact.
  Live spine/hand transforms guide equipment orientation, with no root motion.
- The existing bow now has a bone-attached back presentation and explicit drawn
  state; its quiver remains present. Existing first-person body hiding excludes
  held equipment and still includes back gear. Camera controls are unchanged.
- Attacking from a sheathed state queues the initial strike until draw recovery.
  Manual draw intent replaces the old automatic 3.2-second re-sheath timer.
- Dodge, damage, death, dialogue/context changes, zone locks and Oathfire clear
  pending equipment actions. An interrupt keeps the last contact-resolved state,
  not a half-animation, invisible selected blade or delayed weapon swap.
- Equipment schema 3 saves settled selection/draw intent and a bow_drawn field.
  Old bow saves default to drawn; other inventory, quest and oil data are retained.

## Files And Static Review

Runtime: scripts/equipment_loadout.gd, player_controller.gd, input_router.gd,
character_animation_driver.gd and hud.gd. Source review covers cancellation,
input release, weapon ownership, saved intent, body hiding and socket frames.
No new animation ecosystem or downloaded equipment asset; no damage rebalance.

Production build: `lr-003-20261008-draw-sheath`, source `4e1fbf9` plus this
ticket's dirty implementation and generated manifests. Complete Web directory:
**91,921,171 bytes** (87.66 MiB); artifact-only total 91,914,499 bytes.
The initial build reported an inferred-Boolean compiler error; the explicit type
fix is included. The required retry compiled and exported successfully.
Build logs: `.release-gate/LR-003-20261008-build-r2/logs/`.
Stored root PCK SHA-256:
`d8328591165ae0325374f768b72a722d761d0ff8be8cb93f6895b56d6eca4dc5`.
Decoded root PCK SHA-256:
`0e96c63508b56005eefaf6ffc954a5e8a65664dfbbad92e16e4df5a85ba6088b`.
Static source diff and packaging checks completed; deployment identity pending.

## Unverified

UNVERIFIED - REQUIRES USER TESTING: reach/contact visual alignment, clipping,
first-person presentation, timing feel, all interruption paths, controller
tap/hold, remaps and Save/Continue. Retained clips plus arm posing are not a
claim of new bespoke motion capture. No game, browser, tests, screenshots or
performance measurement were run. User acceptance remains 0/28.

## Manual Test Checklist

1. Use H and controller tap/hold to draw, sheath and switch Steel/Oathblade/Bow
   while idle, walking and turning. Confirm no tap fires after a hold.
2. Interrupt with dodge, damage, dialogue and Oathfire. Attack from sheathed;
   confirm no damage before the blade is ready and movement stays available.
3. Repeat in first person; Save/Continue after switching and while sheathed.
   Confirm the selected weapon and supplies survive and scabbards stay present.
