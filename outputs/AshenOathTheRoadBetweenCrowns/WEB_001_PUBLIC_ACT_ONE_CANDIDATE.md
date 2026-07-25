# WEB-001 Public Act One Candidate

## Result

WEB-001 hardens the development Web candidate without changing production.
The export is single-threaded, uses Godot's Compatibility renderer, contains
exactly seven runtime files, and remains below the 100 MB release ceiling.

## Changes

- Added a strict export verifier with hard payload limits, SHA-256 hashes, and
  a machine-readable report.
- Added a preset/hosting verifier covering the single export preset, native
  1280x720 project viewport, slim filters, and Vercel revalidation headers.
- Added dependency-free Chrome and Edge automation using the DevTools protocol.
  It loads the actual PCK/WASM, verifies WebGL2, activates the launch screen,
  starts New Game, reaches Greyfen, checks browser errors and memory, and saves
  nonblank screenshots.
- Added the Web checks to targeted ticket gates and the authoritative milestone
  release runner.
- Updated the main-menu build identifier to `WEB-001 ACT ONE CANDIDATE`.

## Verification

- Static Web configuration: pass.
- Export: 64.0 MB total; 27.7 MB PCK.
- PCK SHA-256:
  `9beffd8697a5a312f24a3858a6cb242230082a94ce50df6c47ed2af6f79d8727`.
- Chrome: 1280x720 WebGL2, engine ready in 17.3 seconds, New Game reached
  Greyfen in 14.2 seconds, no console errors.
- Edge: 1280x720 WebGL2, engine ready in 17.2 seconds, New Game reached
  Greyfen in 14.5 seconds, no console errors.
- Runtime JavaScript heap remained 10.2-10.6 MB in both browsers.
- Packed startup and the targeted Web/UI gate passed.

Initial engine startup under headless software WebGL takes roughly 17 seconds.
This includes loading and compiling the 64 MB candidate in an isolated cold
browser profile. The final cold-profile test required another 14-15 seconds for
New Game to reach Greyfen. This is accepted as a known WEB-001 limitation, not
misreported as instant startup; later loading optimization remains necessary.

## Deployment

This is a development-branch checkpoint. It does not modify tracked `web/`,
push `main`, or deploy Vercel. Production remains unchanged until `MOBILE-001`
completes the roadmap milestone.

## Run Locally

```powershell
cd "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOath_Web"
& "C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" -m http.server 8787 --bind 127.0.0.1
```

Open `http://127.0.0.1:8787/index.html?v=web001`, click the game, press
`Enter`, then choose `New Game`.

## Remaining Roadmap

1. `INPUT-001`
2. `MOBILE-001`

The milestone production deployment follows `MOBILE-001`.
