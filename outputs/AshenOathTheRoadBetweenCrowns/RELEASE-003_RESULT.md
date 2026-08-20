# RELEASE-003 Result

## Status

Local release suite passed on 2026-08-21. Production deployment is the remaining
step in this checkpoint; no live deployment is claimed until the commit, push,
Vercel response, and live PCK comparison succeed.

## Verification

- Authoritative release runner: `PASS`.
- Runtime, story, save, character, animation, combat, AI, Oathfire, river,
  navigation, Greyfen, Castle, audio, materials, visual, lifecycle, and budget
  gates: `PASS`.
- Graphical Compatibility performance: `PASS` at native 1280x720 Balanced.
  Greyfen averaged 59.996 FPS with a 48.47 FPS 1% low; Wychwood averaged
  59.998 FPS with a 45.11 FPS 1% low; Wychwood combat averaged 56.83 FPS with
  a 30.69 FPS 1% low; Castle Court averaged 60.003 FPS with a 53.35 FPS 1%
  low; Record Hall averaged 60.003 FPS with a 55.05 FPS 1% low; Hart Glade
  averaged 60.000 FPS with a 55.33 FPS 1% low.
- New Game measured 56 ms in the graphical gate; cold transitions stayed below
  261 ms and the warm return measured 60 ms.
- Screenshot capture, dimensions, nonblank, freshness, and Codex visual review:
  `PASS` for the current required gallery.
- Packed startup: `PASS`.
- Chrome and Edge desktop full-campaign browser route: `PASS`; 37 checkpoints
  reached from Greyfen through Hart Glade with no console or network errors.
- Chrome and Edge mobile emulation full-campaign route: `PASS`; no console or
  network errors. This is Web emulation, not native mobile certification.
- Headless browser FPS is recorded as a SwiftShader diagnostic only. The
  hardware acceptance threshold is the graphical Compatibility gate above.
- QA log classification: `PASS`; shutdown-only Godot allocator diagnostics are
  retained as warnings and are not active-frame failures.

## Artifact

- Export folder: `outputs/AshenOath_Web`.
- Shape: seven files.
- Payload: `97,898,609` bytes (`93.36 MiB`), below the 100 MB limit.
- PCK: `59,841,788` bytes.
- Local PCK SHA-256:
  `98AA203BA4EC02991DCDD75FEE8BE5A7F34DE5D4E706F53F96264C4F565FFC6C`.
- Production export excludes QA telemetry and development tools.

## Known Limitations

- The game remains grounded stylized dark fantasy rather than photoreal or AAA.
- Godot can print shutdown-only RID/ObjectDB/resource cleanup diagnostics after
  successful isolated verifier runs; active rendering and browser logs passed.
- Firefox and physical-controller certification are not available in this
  Windows-only run. Generic gamepad mappings remain in the project.

## Git and Deployment

- Development branch: `codex/soul-rebuild`.
- Final release commit and push are performed after this document and the
  synchronized Web folder are staged.
- Production target: `https://ashenoath.vercel.app/?v=soul-rebuild`.

## Exact Local Running Steps

```powershell
cd "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns"
cmd.exe /c Export_Web_Build.bat
cd ..\AshenOath_Web
& "C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" -m http.server 8787 --bind 127.0.0.1
```

Open `http://127.0.0.1:8787/`, click `Enter`, then `New Game`.
