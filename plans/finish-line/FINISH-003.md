# FINISH-003 - Movement, Camera And Character Integrity

## Current Implementation Delivery - 2026-10-26

Candidate: `finish-implementation-20261026`, continued from published r14
(`4b28d2d`) on the canonical D: development branch.

Retained eight-direction locomotion, first person, bow alignment, stable dialogue framing, materials and all existing weighted facial assemblies. Centralized playback clocks and full dialogue-policy restoration; corrected abandoned boss-strike clock ownership.

Source implementation/reconciliation: complete for this build-only delivery.
Compilation/package/publication: recorded centrally in
[FINISH-000](FINISH-000.md) and the current FINISH-016 publication receipt.
Agent runtime verification: NOT RUN; user acceptance: PENDING.
No historical failure or unplayed case is promoted to passed. The approved
build-and-publish boundary supersedes old intermediate approval/publication holds
below; original runtime/performance contracts remain for the user's acceptance.

## Preserved Contract And Historical Evidence


Parent: [FINISH-000](FINISH-000.md). Dependencies: FINISH-001, FINISH-002.
Implementation: retained movement/material/camera repairs present.
Compilation: baseline recorded; not rerun. User acceptance: Pending.
Publication: baseline only.

## Player Outcome

Kael moves naturally toward travel, the camera follows without fighting input,
and required characters remain complete, textured and recognizable.

## Existing Owners And Evidence

Use player/camera controllers, locomotion/pose drivers, prepared actor/material
records and existing camera placement. Relevant records:
[movement/colour](../../outputs/AshenOathTheRoadBetweenCrowns/CHARACTER_MOTION_COLOUR_RESULT.md),
[atlas delivery](../../outputs/AshenOathTheRoadBetweenCrowns/BOOT_009_RESULT.md),
[camera smoothing](../../outputs/AshenOathTheRoadBetweenCrowns/STARTUP_SMOOTH_001_RESULT.md).
The atlas startup observation did not establish final visible-character approval.

## Remaining Conditions And Bounded Repair

- Keyboard arrows/WASD, touch and available gamepad turn normal locomotion toward
  all travel directions using forward strides; sharp reversal brakes without
  persistent backward sliding, awkward reverse clips or stuck arm overrides.
- Achieved movement drives footsteps; idle/pause do not produce walking sounds.
- Unrestricted yaw, shortest-arc turning, immediate manual look, collision-safe
  follow and zoom-to-first-person survive aim, relocation and zone transitions.
- First-person/bow movement turns body/view as designed without self-fed spinning;
  committed attack/cast direction remains locked through its legitimate phase.
- Zooming out restores Kael. New Game, Continue, quality changes, day/night and
  region returns retain A-set bodies/atlases, Ranger Senn and approved NPC recipes.
- Gameplay and dialogue cameras avoid roofs, walls and the Hart's body, frame
  actual speakers and restore the previous player view afterward.
- Fix bindings/ownership or placement at its source. No generic recolour,
  substitute capsule, forced lighting change or replacement character family.

## User Manual Checklist

1. Walk/run eight directions, reverse repeatedly, stop, then draw/sheath and guard;
   check facing, feet, arm release and footstep timing.
2. Rotate fully, zoom in/out, repeat movement and bow aiming in first person;
   confirm stable heading and arrows follow displayed aim.
3. Continue, change quality and revisit day/night areas; inspect Kael, Anwen,
   nearby villagers, Senn and later Halvern for complete consistent bodies/colours.
4. Enter an interior and talk to a human and the Hart; check framing and camera
   restoration. Gather these checks during the regional route, not a separate tour.

## Delivery Record

Targeted a54 Chrome observation - 2026-10-20, ruins-road candidate, hardware
960x540: real keyboard orbit accumulated 11.37312 radians, zoom input reached
the observed first-person state, and zoom-out restored Kael's ready, visible,
texture-bound A-set body. No captured console errors/warnings. Existing observer
fields supplied these assertions; no new runtime telemetry/candidate was added.
Report/image: D:/Temp/AshenOath/finish-targeted-20261020-a54-chrome-controls/browser.json
and browser_first_person.png. Overall strict browser-memory FAIL 606 MiB.
This observes orbit/first-person/body restoration, not every locomotion/combat/
equipment/actual-phone condition or user acceptance.

2026-10-20 graphical verification 1/1: current native source, 1280x720
Compatibility/ANGLE Intel HD 620. Eight real-key travel directions, forward
locomotion selection, idle settling, retained Kael atlas, unrestricted orbit,
first-person zoom/body visibility and zoom-out restoration had no assertion
failures. One assertion failed after the fixture directly teleported Kael without
resetting physics interpolation. HARNESS correction adds the same reset required
for relocations; the owned watchdog is now stopped/freed at teardown to avoid
its callback retaining the test tree. No gameplay camera code was changed.
Log: D:/Temp/AshenOath/finish-003-20261020/stdout.log. Correction is not rerun.
Full-world NPC/quality/day-night/interior/Hart observations remain Pending;
this graphical component session alone does not accept the whole card.
User verdict/date: Pending. Unavailable physical gamepads remain untested.

