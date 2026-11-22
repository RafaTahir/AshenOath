# INPUT-002 - Centralized Input Context and Focus Ownership

## Status

Completed on `codex/soul-rebuild` as a development checkpoint. Production
`main`, tracked `web/`, and Vercel remain unchanged.

## Changes

- Added an explicit `InputRouter` context contract for menu, gameplay, pause,
  dialogue, journal, settings, controls, remapping, minigame, death, and
  transition states.
- Centralized pointer ownership behind `set_context`, `set_ui_context`, and
  `set_gameplay_context`; UI contexts release the pointer and gameplay requests
  capture through the existing Web-safe pointer path.
- Added shared focus helpers so menu and remap navigation can focus the first
  enabled action and clear stale focus when a panel closes.
- Updated HUD screens, minigames, pause/resume, and camera pointer handling to
  delegate to `InputRouter` instead of independently changing pointer state.
- Kept the existing semantic remapping, conflict swap, gamepad family, and
  settings persistence behavior intact.
- Added `verify_input_002.gd` for context transitions, pointer ownership,
  controller focus, invalid-context fallback, and remap persistence.
- Registered INPUT-002 in the `input` ticket profile.

## Verification

- `verify_input_002.gd`: PASS.
- `verify_input_003.gd`: PASS.
- `verify_input_004.gd`: PASS.
- `run_ticket_gate.ps1 -Profiles input -NoCache`: PASS.
- `content_integrity`: PASS.
- `runtime_smoke`: PASS.
- `verify_input_001`: PASS.
- `verify_runtime_regressions`: PASS.
- `verify_ui_001`: PASS.
- `git diff --check`: PASS.

The exact captured-pointer assertion is skipped only by the new verifier when
Godot reports the headless display driver; context changes and UI release are
still asserted. Graphical/browser gates remain the authority for actual Web
pointer-lock behavior.

## Screenshots

None. INPUT-002 changes input ownership and focus behavior without changing a
player-facing world view; the existing UI-001 graphical gate remains passing.

## Known limitations

- Physical controller certification is still limited to devices available for
  testing; generic SDL/Godot mappings remain the fallback.
- The broader Soul Rebuild visual, full-route, performance, export, and live
  deployment gates remain open.

## Running steps

```powershell
cd C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns
$env:GODOT_BIN = 'C:\Temp\AshenOathGodot4.6.3\Godot_v4.6.3-stable_win64_console.exe'
& .\tools\run_ticket_gate.ps1 -Profiles input -NoCache -ChangedFiles scripts/input_router.gd,scripts/hud.gd,scripts/minigame_manager.gd,scripts/camera_controller.gd,scripts/game.gd,tools/verify_input_002.gd,tools/gate_profiles.json
```
