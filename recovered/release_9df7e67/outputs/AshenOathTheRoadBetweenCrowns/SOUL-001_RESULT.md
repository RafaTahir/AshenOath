# SOUL-001 Result

## Files changed

- `SOUL_REBUILD_CONTEXT.md`
- `asset_acceptance_manifest.json`
- Runtime character overlay contract and gamepad foundation files.
- `web_boot_shell.html` and Web export preset.
- `scripts/oath_gate_portal.gd` and `scripts/zone_streaming_service.gd`.
- `scripts/game.gd` and `scripts/runtime_service_registry.gd` for portal/service ownership.

## Completed

- Locked the original Ashen Oath creative direction and measurable release rules.
- Catalogued the selected CC0 Quaternius source families without pretending the current temporary mappings are final.
- Disabled generated root-mounted character and monster anatomy that caused neck humps and animation desynchronization.
- Added a custom Web shell with immediate title/atmosphere, progress, and an interactive Crow's Crossing wait activity.
- Added gamepad family detection, hotplug/reconnect handling, and PlayStation/Nintendo/Xbox-aware labels.
- Replaced the plain gate marker with a lightweight animated Oath Gate visual while preserving the existing trigger and transition logic.
- Added a threaded resource request service with progress, cancellation, readiness, failure, activation, and retirement APIs for future packed zones.

## Verification

- `verify_runtime.gd`: PASS.
- `verify_input_001.gd`: PASS.
- `verify_char_001.gd`: PASS.
- `verify_motion_quality.gd`: PASS.
- `verify_anim_001.gd`: PASS.
- `verify_web_export.py`: PASS - 7 files, 65.8 MB, PCK 29.5 MB.
- Local Web export: PASS. Generated `index.html` contains the Ashen Oath shell and Crow's Crossing activity.
- Godot headless shutdown still reports renderer RID/ObjectDB cleanup warnings. These are recorded as the next lifecycle ticket; no active gameplay parser/resource failure was observed.

## Running steps

```powershell
cd "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns"
& "C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe" --headless --path . --quit-after 3
```

Export and verify locally:

```powershell
.\Export_Web_Build.bat
& "C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" tools\verify_web_export.py ..\AshenOath_Web
& "C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" -m http.server 8787 --bind 127.0.0.1 --directory ..\AshenOath_Web
```

Open `http://127.0.0.1:8787/index.html` in a browser. The HTML shell appears before Godot starts; click `Enter the Road` to begin the engine handoff.

## Remaining

The replacement humanoid and monster GLBs, authored world construction, boss encounters, full streaming packs, campaign beat staging, and final performance gate remain subsequent tickets. They must not re-enable procedural face or costume overlays.
