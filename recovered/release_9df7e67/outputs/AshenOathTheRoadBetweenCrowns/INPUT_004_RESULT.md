# INPUT-004 Result — Glyphs, Remapping, and Navigation

## Status

Implemented on the cumulative `codex/soul-rebuild` branch. The existing menu and semantic input actions now expose a controller-aware remapping surface without adding a second input system.

## Changes

- Added a `Customize Controls` menu reachable from the Controls screen and usable from the pause/main-menu flow.
- Added paginated binding rows for interaction, movement/combat, Oathfire, inventory, and pause actions.
- Added keyboard, mouse, controller-button, and controller-axis remapping with input-type-aware conflict detection.
- Conflicting bindings swap the displaced action’s binding instead of silently leaving an action unusable.
- Added reset-to-default behavior and persisted custom keyboard/mouse bindings plus per-device gamepad profiles.
- Added family-aware glyph labels for Xbox, PlayStation, Nintendo, and generic controllers, including face buttons, shoulders, triggers, sticks, D-pad, menu, and view/touchpad labels.
- Preserved existing focus-first behavior so menu rows remain keyboard/controller navigable.

## Verification

```powershell
cd "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns"
& .\tools\run_ticket_gate.ps1 -Profiles input -NoCache
```

Result: `TICKET GATE: PASS`

Passed gates: content integrity, runtime smoke, INPUT-001, INPUT-003, INPUT-004, runtime regressions, and UI-001. The direct `verify_input_004.gd` gate also passed.

No screenshot capture was required; this ticket changes input configuration and menu interaction rather than world rendering.

## Honest Limitations

- Glyphs are text labels rather than bespoke icon textures; the device-family contract is in place for a later visual glyph pass.
- Browser/controller behavior still depends on the controller exposed by the OS, browser, and Godot/SDL. Physical DualShock 4, DualSense, Switch Pro, and generic hardware certification remains part of the later QA/accessibility tickets.
- This ordinary ticket does not export or deploy Web production.

## Running Steps

```powershell
cd "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns"
& "C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe" --headless --path . --script tools\verify_input_004.gd
& .\tools\run_ticket_gate.ps1 -Profiles input -NoCache
```

For normal play, open Controls → Customize Controls, choose a binding row, press the desired key/button/axis, and use Reset Defaults when needed. Escape cancels a pending remap.

## Next Ticket

`MAT-003` — Unified Material Library.
