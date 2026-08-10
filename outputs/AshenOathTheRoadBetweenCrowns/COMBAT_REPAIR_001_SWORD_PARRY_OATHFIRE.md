# COMBAT-REPAIR-001: Sword, Parry, and Oathfire Presentation

## Files changed

- `scripts/player_controller.gd`
- `Development_Gallery/screenshots/Capture_13_player_light_attack_arc_*.png`
- `Development_Gallery/screenshots/Capture_14_player_heavy_attack_arc_*.png`
- `Development_Gallery/screenshots/Capture_76_oath_001_charge_hands_*.png`
- `Development_Gallery/screenshots/Capture_77_oath_001_release_contact_*.png`
- `Development_Gallery/screenshots/Capture_78_oath_001_wall_impact_*.png`

## Repairs

- Initialized the bone-attached Oathblade in its authored ready pose before the first physics tick, removing the upright pole caused by the imported hand axis.
- Reduced the authored blade to a grounded gameplay proportion while retaining a readable hand-to-tip segment and sword socket.
- Adjusted light-attack windup/strike directions so the blade travels forward through Kael's combat space.
- Widened the measured blade ribbon along the active camera's screen axis. The slash remains driven by blade base/tip movement rather than a detached primitive cone.
- Preserved the existing sword contact trace, parry timing, Oathfire direction lock, sheathing, hand glow, wall clipping, and cleanup behavior.

## Verification

- `tools/verify_combat_001.gd`: PASS.
- `tools/verify_oath_001.gd`: PASS.
- `tools/capture_slice_screenshots.gd -- --combat-only`: PASS.
- `tools/capture_slice_screenshots.gd -- --oath-only`: PASS.
- Manual capture review confirms grounded sword, visible light/heavy strike feedback, hand charge glow, sheathed Oathfire state, beam release, and wall impact.

Known shutdown diagnostics remain in graphical Godot runs: null-material and renderer allocator messages are emitted during teardown by existing imported resources. They remain tracked for `ENGINE-REPAIR-001`; they did not cause an active-frame assertion or parser failure in this ticket.

## Running steps

```powershell
cd "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns"
& "C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe" --headless --path . --script tools/verify_combat_001.gd
& "C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe" --headless --path . --script tools/verify_oath_001.gd
& "C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe" --path . --rendering-method gl_compatibility --script tools/capture_slice_screenshots.gd -- --combat-only
```

## Remaining issues

The underlying character bodies are still stylized low-poly assets, and the light ribbon is intentionally restrained. A later character/world pass must replace weak visible mappings and improve monster identity without changing the verified combat contract.
