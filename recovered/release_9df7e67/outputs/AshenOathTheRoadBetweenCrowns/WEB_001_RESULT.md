# WEB-001 Result - Production-Preset Browser Certification

Status: accepted on 2026-09-21.

## Delivered

- The production `Web Browser` preset is exercised through read-only runtime
  observation and real browser input; no route mutation, teleport, story flag,
  or direct interaction handler is available to the harness.
- Chrome and Edge both start New Game, walk a real CharacterBody across the
  Greyfen bridge, focus and speak with Sister Anwen, release dialogue input,
  persist a checkpoint, reload the same browser profile, and Continue into
  controllable Greyfen.
- The browser server mirrors production delivery: text, JavaScript, WebAssembly,
  and JSON may be gzip encoded, while already-packed PCK octet streams remain
  raw. This avoids false StreamPeerGZIP errors when a live page is reloaded
  during a background pack transfer.
- Persistence timing accounts for dialogue-paused scene time, so the test waits
  for the game's 30 seconds of active checkpoint time instead of assuming wall
  time and engine time are identical.

## Verified Candidate

- Build ID: `recovery004-web001-v110`
- Artifact: `D:\Temp\AshenOath\recovery004_web001_v110\web`
- Artifact shape: 15 files, 96.5 MB
- Root PCK SHA-256:
  `be94dd543d23d55c73dbc93b57994186c8ba89b5709a096bf93325ef9b1f08f1`
- Packed startup: PASS; runtime ready in 115 ms.
- Chrome: PASS at 1280x720 WebGL2; engine ready 13,780 ms, New Game
  69.2 ms internal / 298 ms visible wall time, JS heap 10.8 MB, zero console
  errors.
- Edge: PASS at 1280x720 WebGL2; engine ready 10,989 ms, New Game
  84.6 ms internal / 311 ms visible wall time, JS heap 14.8 MB, zero console
  errors.

## Verification

- `tools/verify_web_001.py`: PASS.
- `tools/verify_web_export.py`: PASS for the exact v110 artifact.
- `tools/verify_packed_startup.gd`: PASS.
- Chrome complete production-preset browser route: PASS.
- Edge complete production-preset browser route: PASS.
- Both isolated browser profiles were created under `D:\Temp\AshenOath` and
  cleaned after successful runs.

Detailed reports and screenshots are under
`D:\Temp\AshenOath\recovery004_web001_v110`, especially
`web001_chrome_full.json` and `web001_edge_full_v2.json`.

## Remaining Scope

This ticket certifies the local production-preset candidate. It does not claim
live Vercel identity, full-campaign traversal, final performance, or release
approval; those remain owned by `CERT-001` and `RELEASE-001`.

## Running Steps

```powershell
node .\tools\verify_web_browser.mjs `
  --export D:\Temp\AshenOath\recovery004_web001_v110\web `
  --browser chrome --renderer hardware `
  --bridge-crossing --interaction-smoke --persistence-smoke `
  --timeout 150000 --report <report.json>
```

Replace `chrome` with `edge` for the second browser acceptance run.
