# Soul Rebuild Completion Status

Date: 2026-08-21

## Current Truth

The cumulative Soul Rebuild work is locally release-verified on
`codex/soul-rebuild`. It has not been published to production yet in this
checkpoint. The authoritative release runner completed with `PASS` after the
full browser tail was rerun against the corrected QA export.

## Completed

- Full runtime, content, story, save, character, animation, combat, AI,
  Oathfire, river, navigation, Greyfen, Castle, audio, visual, lifecycle,
  material, and budget gates passed.
- Graphical native-720p Compatibility performance passed every required zone
  and combat sample above the 32 FPS average / 30 FPS 1% low contract.
- Current screenshots passed capture, freshness, dimensions, nonblank, and
  Codex visual review gates.
- Packed startup, production Web export, Chrome, Edge, Chrome mobile emulation,
  and Edge mobile emulation passed. The full route reached Hart Glade through
  37 browser checkpoints without console or network errors.
- QA browser staging now uses the playable side of a gate, not the next zone's
  destination spawn. Headless SwiftShader performance is reported as a
  diagnostic; graphical Compatibility remains the performance acceptance gate.

## Artifact

- Seven-file Web artifact: `97,898,609` bytes (`93.36 MiB`).
- PCK: `59,841,788` bytes.
- Local PCK SHA-256:
  `98AA203BA4EC02991DCDD75FEE8BE5A7F34DE5D4E706F53F96264C4F565FFC6C`.

## Remaining Release Actions

1. Stage the verified source, documentation, screenshots, export configuration,
   and synchronized `web/` artifact while excluding development-only raw files.
2. Commit and push `codex/soul-rebuild`.
3. Fast-forward and push `main`.
4. Wait for Vercel, compare the live `index.pck` hash, and smoke-test the
   cache-busted production URL.

## Known Limitations

- Stylized low-poly presentation remains the shipped art direction; this is
  not a photoreal or AAA claim.
- Shutdown-only Godot allocator diagnostics remain classified warnings after
  passing runtime checks. No active-frame renderer or browser-console error
  blocked the release suite.
- Firefox and physical-controller certification remain untested on this
  Windows environment; native Android/iOS/store work remains deferred.

## Local Running Steps

```powershell
cd "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns"
cmd.exe /c Export_Web_Build.bat
cd ..\AshenOath_Web
& "C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" -m http.server 8787 --bind 127.0.0.1
```

Open `http://127.0.0.1:8787/`, click `Enter`, then `New Game`.
