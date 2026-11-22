# REPAIR-002 — Truthful Verification

## Files Changed

- `tools/verify_runtime.gd`
- `tools/verify_render_resources.gd`
- `scripts/game.gd`

## Fixes

- Added a 45-second runtime verifier deadline.
- Settings validation now inspects all paged settings controls.
- Road-critical Sister Anwen, Castle gate, clue, and report interactions now use proximity focus, line-of-sight validation where appropriate, and an `E` input event.
- Added a bounded proximity refresh so valid interactables cannot lose focus after spawn, save/load, or zone arrival timing.
- Ground clues use a raised readability target and do not fail on low decorative ground occlusion.
- Added a render-resource verifier for missing meshes, null mesh surfaces, and incomplete MultiMesh materials.
- Detached interaction candidates are discarded before transform access during zone teardown.

## Verification

- `tools/verify_runtime.gd` — PASS through the first route, five-enemy victory, report, and fall recovery.
- `tools/verify_render_resources.gd` — PASS for Greyfen startup and active geometry.
- `tools/verify_ui_001.gd` — PASS.

Godot's dummy headless renderer still reports resource/RID teardown diagnostics after the verifier's PASS marker. No parser, missing-resource, or active null-surface assertion remains in the checked gameplay frame.

## Running Steps

```powershell
cd outputs/AshenOathTheRoadBetweenCrowns
& "C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe" --headless --path . --script tools/verify_runtime.gd
& "C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe" --headless --path . --script tools/verify_render_resources.gd
```

## Remaining Issues

- Full exported-browser route verification remains a Milestone 1 gate.
- Direct state fixtures remain in several older campaign verifiers outside this ticket.

## Development Checkpoint

Pending the Milestone 1 development branch commit.
