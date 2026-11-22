# INPUT-003 Result — Universal Gamepad Core

## Status

Implemented on the cumulative `codex/soul-rebuild` branch. The existing semantic `InputMap` remains authoritative, while the router now exposes a normalized controller profile and safely handles Xbox/XInput, DualShock 4, DualSense, Switch Pro, and generic recognized gamepads.

## Changes

- Added `GamepadProfile` with family detection, glyph theme, semantic binding summary, deadzone values, axis inversion, sensitivity, vibration capability, and rumble policy.
- Added configurable radial stick deadzones with response remapping, per-device center calibration, X/Y inversion, and controller look sensitivity.
- Lowered device-activity detection to recognize a deliberate stick movement without allowing sub-deadzone drift to select or move the player.
- Hardened disconnect/reconnect behavior: virtual input clears on disconnect, the active device falls back to keyboard/mouse when no controller remains, and the next connected controller becomes active when available.
- Guarded rumble against disconnected/unsupported devices, capped amplitude and duration, and applied the persisted rumble strength limit.
- Added save-safe settings fields for deadzone, axis inversion, and rumble strength with bounded migration defaults.
- Added a synthetic-device verifier covering profile shape, family detection, action-based bindings, deadzone response, calibration, inversion, hotplug fallback, settings persistence, and no-op rumble safety.

## Verification

```powershell
cd "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns"
& .\tools\run_ticket_gate.ps1 -Profiles input -NoCache
```

Direct gate passed:

`INPUT-003 VERIFIER: PASS - universal gamepad profile, calibration, hotplug, and guarded rumble`

No screenshot capture was required because this ticket changes input behavior and settings state, not rendered world presentation. Physical controller certification remains part of `CHAR-QA-001` and `ACCESS-003` for devices available to test.

## Honest Limitations

- Godot/SDL and the browser remain responsible for physical device recognition and platform-specific button ordering. The game uses normalized semantic actions and family glyph metadata rather than hard-coding one vendor’s raw device IDs.
- Full controller glyph artwork, remapping UI, conflict resolution, and controller-only menu navigation belong to `INPUT-004`.
- This ordinary ticket does not export or deploy Web production.

## Running Steps

```powershell
cd "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns"
& "C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe" --headless --path . --script tools\verify_input_003.gd
& .\tools\run_ticket_gate.ps1 -Profiles input -NoCache
```

For normal play, connect a controller before launch or hot-plug it while the game is running; use `A/Cross/B` for interaction according to the detected family, the left stick for movement, and the right stick for camera look.

## Next Ticket

`INPUT-004` — Glyphs, Remapping, and Navigation.
