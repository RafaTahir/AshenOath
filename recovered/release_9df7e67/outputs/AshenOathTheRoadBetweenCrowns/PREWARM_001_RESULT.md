# PREWARM-001 Result

Status: **accepted** on 2026-09-20.

## Completed Work

- Removed the nine-role Castle queue from Greyfen startup and unrelated
  wilderness travel.
- Added destination-adjacent prewarm sets:
  - Bandit Road warms Vargan wall, arch, roof, and lantern assets.
  - Vargan Approach warms Record Hall furniture and weapon dressing.
- Preserved one-role-per-settled-frame execution and transition/pause guards.
- Added generation-based cancellation when the source sector changes or when a
  zone has no predictive role set.
- Registered a `predictive_prewarm` targeted gate profile.

## Verification

- `D:\Temp\AshenOath\prewarm001_native.log`
  - Cold role import: 287.0 ms.
  - Worst observed frame: 291.2 ms.
  - Cancellation after one role: PASS.
- `D:\Temp\AshenOath\prewarm001_graphical.log`
  - Intel HD 620, ANGLE D3D11, Compatibility renderer.
  - Warm role import: 22.7 ms.
  - Worst observed frame: 34.5 ms.
  - Cancellation after one role: PASS.
- `D:\Temp\AshenOath\prewarm001_load_regression.log`
  - Menu-covered Greyfen prewarm: 2177 ms.
  - Cached New Game handoff: 35.4 ms.
  - `LOAD-001`: PASS.

All measured prewarm frames remain below the 350 ms transition budget. This
ticket does not rebuild Web; production browser certification remains owned by
`WEB-001` and `CERT-001`.

## Running Steps

```powershell
cd D:\Projects\AshenOath\outputs\AshenOathTheRoadBetweenCrowns
& 'C:\Users\User\.cache\codex-runtimes\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe' --path . --script res://tools/verify_prewarm_001.gd
& 'C:\Users\User\.cache\codex-runtimes\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --script res://tools/verify_load_001.gd
```
