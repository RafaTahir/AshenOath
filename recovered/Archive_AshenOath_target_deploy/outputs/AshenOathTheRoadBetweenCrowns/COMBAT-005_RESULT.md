# COMBAT-005 Result

## Files changed

- `scripts/player_controller.gd`
- `scripts/combat_manager.gd`
- `scripts/combat_feedback.gd`
- `scripts/game.gd`
- `scripts/sky_backdrop.gd` (parser correction discovered by the targeted runtime gate)
- `tools/capture_slice_screenshots.gd`
- `tools/verify_combat_005.gd`
- `tools/gate_profiles.json`
- `tools/run_ticket_gate.ps1`
- `PROJECT_STATE.md`

## Combat changes

- Blade contacts now carry the animation contact phase, measured blade travel, blade direction, and the closest point on the actual sweep.
- Hit results expose the true blade contact distance instead of only the candidate score.
- Contact feedback now uses the current and previous blade base/tip transforms, producing a measured `BladeSweepRibbon` plus the contact flash/ring at the impact point.
- Hit rumble and camera response are scaled to light versus heavy contact.
- Parry feedback can anchor at the actual weapon contact point instead of a fixed player offset.
- Kael now uses the neutral UAL2 `Idle_Loop` for the ready stance; the existing light/heavy attack clips and bone-attached Oathblade remain unchanged.
- The capture harness resets stale jump/compression state and reasserts grounded idle presentation so combat evidence reflects the runtime pose.

## Verification

Passed with isolated Godot logs:

- `content_integrity`
- `runtime_smoke`
- `verify_motion_quality`
- `verify_combat_001`
- `verify_ai_001`
- `verify_oath_001`
- `verify_combat_005`
- `git diff --check`

Graphical capture passed on the Compatibility renderer and produced fresh 1280x720 evidence:

- `Development_Gallery/screenshots/Capture_15_player_sword_ready_2026-08-20_160029.png`
- `Development_Gallery/screenshots/Capture_13_player_light_attack_arc_2026-08-20_160029.png`
- `Development_Gallery/screenshots/Capture_14_player_heavy_attack_arc_2026-08-20_160029.png`
- `Development_Gallery/screenshots/Capture_73_combat_001_blade_contact_2026-08-20_160029.png`

## Payload and deployment

No Web export, `web/` synchronization, `main` push, or Vercel deployment was performed. `COMBAT-005` is an ordinary development ticket; production remains on the existing deployed opening build until the Milestone E gate.

## Known limitations

- The graphical capture process still reports existing Godot renderer/RID/ObjectDB teardown warnings after successful screenshots. They are retained in `.release-gate/combat-005/` and are not suppressed.
- The current Ghoulkin and later-world art remains below the locked visual bar; this ticket improves combat contact presentation, not monster-family replacement.
- Full Web/browser combat smoke testing remains a Milestone E acceptance task.

## Running steps

From `C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns`:

```powershell
$godot = "C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe"
& $godot --headless --path . --script tools/verify_combat_005.gd
powershell -ExecutionPolicy Bypass -File .\tools\run_ticket_gate.ps1 -Profiles @('combat') -NoCache
& $godot --path . --rendering-method gl_compatibility --script tools/capture_slice_screenshots.gd -- --combat-only
```

To exercise it manually, start New Game, travel to Wychwood, use left mouse for light attack, right mouse for heavy attack, tap `Q` during a Ghoulkin windup to parry, hold `Q` to block, and hold `C` for Oathfire. `Esc` returns to the menu.
