# BOOT-001 / BOOT-002 Result

## Scope

This checkpoint adds the immediate browser boot surface and the lightweight Crow's Crossing wait activity. It does not change quest logic, zone construction, saves, or combat.

## Changes

- Added `web_boot_shell.html` as the Web Browser custom shell.
- Added an original Ashen Oath title/crest, progress status, accessible status text, and no-black-frame background before WASM initialization.
- Added a small canvas activity controlled by keyboard, pointer, touch, and basic gamepad input.
- Added reduced-motion behavior and an `Enter the Road` handoff button.
- Enabled the shell in the production Web preset only; the QA preset remains a separate telemetry build.

## Verification

- Web export completed successfully: 7 files, 65.8 MB total, 29.5 MB PCK.
- `verify_web_export.py`: PASS.
- Generated HTML inspection: PASS; the custom shell, canvas, progress bar, and engine startup code are present.
- Browser visual smoke test: not run in this checkpoint. The next Web gate must verify first paint, input response, engine readiness, and Greyfen entry in Chrome and Edge.

## Known limitations

- The current engine still has a long cold startup on the Dell/browser path. The shell improves perceived wait but does not yet split or stream the PCK.
- The existing headless renderer reports shutdown RID/ObjectDB cleanup warnings.

## Running steps

```powershell
cd "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns"
.\Export_Web_Build.bat
& "C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" -m http.server 8787 --bind 127.0.0.1 --directory ..\AshenOath_Web
```

Open `http://127.0.0.1:8787/index.html` and click `Enter the Road`.
