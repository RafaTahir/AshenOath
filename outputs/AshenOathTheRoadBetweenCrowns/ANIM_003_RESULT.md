# ANIM-003 Result — Shared Animation Presentation

## Status

Implemented and verified on `codex/soul-rebuild`. The shared animation driver now owns locomotion, presentation poses, action priority, and explicit action recovery for the route-visible character families.

## Changes

- Added directional locomotion states with safe imported-clip fallbacks for forward, backward, and strafe movement.
- Added action priority so hit/death reactions can pre-empt lower-priority actions while locomotion cannot interrupt an active combat or cast action.
- Added explicit `stop_action()` recovery. Oathfire’s looping cast pose now releases to idle when the beam redraws or the cast is cancelled instead of leaving Kael animation-locked.
- Added dialogue and work presentation modes for named NPCs and Greyfen routines.
- Anwen now enters a stable dialogue pose while her facing lock is active and returns to normal idle on dialogue release.
- Greyfen routines now pass their real travel direction into the driver; the forge helper can use the shared work pose while paused.
- Enemy visual setup now exposes a semantic windup state before attack resolution while retaining the existing attack, hit, stagger, death, leash, and combat behavior.
- Added animation contract telemetry for locomotion state, presentation state, action progress, direction, grounded state, and root-motion policy.
- Added ticket-specific verifier and graphical six-state contact-sheet capture.

## Verification

```powershell
cd "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns"
& .\tools\run_ticket_gate.ps1 -Profiles characters -ChangedViews animation_shared -NoCache
```

Result: `TICKET GATE: PASS`

Passed gates: content integrity, runtime smoke, CHAR-005 through CHAR-009, CHAR-002, CHAR-001, motion quality, ANIM-003, and Greyfen life. Graphical capture also passed at 1280x720.

## Evidence

- `Development_Gallery/screenshots/ANIM_003_01_Kael_Idle.png`
- `Development_Gallery/screenshots/ANIM_003_02_Kael_Walk.png`
- `Development_Gallery/screenshots/ANIM_003_03_Kael_Run.png`
- `Development_Gallery/screenshots/ANIM_003_04_Kael_Light_Attack.png`
- `Development_Gallery/screenshots/ANIM_003_05_Kael_Parry.png`
- `Development_Gallery/screenshots/ANIM_003_06_Kael_Oathfire.png`
- `Development_Gallery/screenshots/ANIM_003_07_Shared_Presentation_Contact_Sheet.png`

## Known Limitations

- The selected shared CC0 outfit remains stylized and compact rather than bespoke occupation clothing.
- The existing sword mesh and combat sweep still read oversized in the contact sheet. COMBAT-005 owns blade attachment/proportions, contact-driven trails, and final attack timing.
- Godot’s dummy renderer continues to print shutdown-only RID/material/ObjectDB cleanup diagnostics after successful headless passes. No new active parser/resource failure was introduced by this ticket.
- No Web export or Vercel deployment was run; this is an ordinary development ticket under the milestone workflow.

## Running Steps

```powershell
cd "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns"
& "C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64.exe" --path . --editor
```

Run the targeted ticket gate:

```powershell
& .\tools\run_ticket_gate.ps1 -Profiles characters -ChangedViews animation_shared -NoCache
```

## Next Ticket

`FACE-003` — Native Faces and Eye Behavior.
