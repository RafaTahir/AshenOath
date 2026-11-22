# REPAIR-001 — Menu, Settings, And Input

## Files Changed

- `scripts/hud.gd`
- `tools/verify_ui_002.gd`
- `tools/verify_runtime_regressions.gd`

## Fixes

- Replaced the overloaded settings screen with three navigable pages.
- Added visible Previous Page, Next Page, and Back controls.
- Added keyboard focus, mouse-stop behavior, and pointing-hand feedback to menu buttons.
- Renamed browser-unsafe `Exit Game` actions to `Return to Launch Screen`.
- Updated runtime checks to validate settings values across all pages.

## Verification

- `Godot_v4.6.3-stable_win64_console.exe --headless --path . --script tools/verify_ui_002.gd` — PASS.
- `Godot_v4.6.3-stable_win64_console.exe --headless --path . --script tools/verify_runtime_regressions.gd` — PASS.
- `Godot_v4.6.3-stable_win64_console.exe --headless --path . --script tools/verify_ui_001.gd` — PASS.

The dummy/headless renderer still prints teardown RID warnings after successful exit; they are classified as teardown diagnostics, not active gameplay failures.

## Running Steps

```powershell
cd outputs/AshenOathTheRoadBetweenCrowns
& "C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe" --path . --editor
```

Or run the Web preview from `AshenOath_Web` with `Serve_Web_Build.bat` from the project root.

## Remaining Issues

- Full browser mouse-click acceptance belongs to REPAIR-002 and the Milestone 1 browser gate.
- Visual quality remains below the intended dark-fantasy benchmark.

## Development Checkpoint

Pending the Milestone 1 development branch commit.
