# RELEASE-003 Result

## Status

The complete Soul Rebuild release gate has passed against the verified current
worktree and is deployed to production. The generated authoritative report is
`release_reports/latest.json` with 92 passing gates and zero failures.

The runner records `d16ea7efffbb795da576c09dd6e1306dc7a0c2da` as its source
commit because the final browser/performance run was executed from that commit
plus the uncommitted, now-reviewed corrections in this result. No source file
was changed after that passing run; the release commit below will capture the
exact verified worktree.

## Verification

- Authoritative release runner: `PASS` (`92` gates, `0` failures).
- Runtime, story, save migration, character, animation, combat, AI, Oathfire,
  river, navigation, Greyfen, Castle, audio, material, lifecycle, and world
  gates: `PASS`.
- Fresh screenshot capture, dimensions, nonblank, freshness, visual-quality,
  Codex review, and all changed animation/world/boss suites: `PASS`.
- Graphical Compatibility performance passed at native 1280x720 Balanced:
  Greyfen `56.71 / 36.32`, Wychwood `60.00 / 44.88`, Wychwood combat
  `59.89 / 37.48`, Vargan Court `60.00 / 54.60`, Record Hall `60.00 / 55.17`,
  and Hart Glade `60.01 / 56.85` FPS average/1% low.
- Static memory stayed below `105 MB`; no slow-frame failures were recorded.
- Packed startup, Chrome/Edge desktop WebGL2 startup, full-campaign browser
  routes, and Chrome/Edge mobile emulation: `PASS`, with no console or network
  errors. Mobile results are Web emulation, not native mobile certification.
- Shutdown-only Godot allocator/RID/ObjectDB diagnostics are classified by
  `verify_qa_005`; no active-frame renderer/material/resource error failed the
  release gate.

## Artifact

- Export folder: `outputs/AshenOath_Web`.
- Shape: exactly seven files.
- Payload: `93.9 MB` (`93.36 MiB`), below the `100 MB` limit.
- PCK: `60,353,288` bytes.
- Local PCK SHA-256:
  `E4A0BB7AFC47A5EE3E5690E0645CCDF8A4A491F9F310877A4BD96CD5FEEDBE62`.
- Production export excludes QA telemetry and development-only tools.

## Known Limitations

- Firefox and physical-controller certification are not available in this
  Windows run; generic gamepad mappings remain enabled.
- The game remains grounded stylized dark fantasy rather than photoreal or AAA.
- The final browser process-memory diagnostic includes Chromium child-process
  overhead; acceptance uses the measured tab JavaScript heap and graphical
  Compatibility performance, both within their limits.

## Git and Deployment

- Development branch: `codex/soul-rebuild`.
- Release commit: `13465620581c2817e3fc455f938afbf5debf059f`.
- Development push: `PASS` (`origin/codex/soul-rebuild`).
- Production `main` push: `PASS` (`origin/main`).
- Live Vercel PCK SHA-256:
  `E4A0BB7AFC47A5EE3E5690E0645CCDF8A4A491F9F310877A4BD96CD5FEEDBE62`.
- Local/live PCK comparison: `PASS`.
- Production smoke endpoint: `HTTP 200`.
- Production URL: `https://ashenoath.vercel.app/?v=soul-rebuild`.

## Exact Local Running Steps

```powershell
cd "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns"
cmd.exe /c Export_Web_Build.bat
cd ..\AshenOath_Web
& "C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" -m http.server 8787 --bind 127.0.0.1
```

Open `http://127.0.0.1:8787/`, click `Enter`, then `New Game`.
