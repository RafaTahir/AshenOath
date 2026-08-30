# PRODUCTION-STARTUP-A-SET-001 Result

Date: 2026-08-30
Branch: `codex/masterpiece-rebuild`

## Changes

- Reworked `web_boot_shell.html` so boot state, progress, Retry, optional Crow Flight, build ID, and runtime-pack contract are explicit.
- Kept New Game visible and clickable while Greyfen prewarms; a click is queued and starts as soon as preparation completes.
- Added visible recovery for pack failure, timeout, and Greyfen prewarm failure instead of leaving the menu disabled.
- Restored the preferred A-set composition for Kael and Sister Anwen and retained deterministic Universal-family variation for the crowd.
- Kept Captain Senn on the Ranger mapping.
- Added exact encounter-role aliases for the retained validated Bat, Dragon, and Skeleton enemy families so portrait capture does not silently use primitive placeholders.
- Rebuilt the local Web candidate and synchronized its runtime-pack URLs to the A-set release identity.

## Artifact

- Candidate: `outputs/AshenOath_Web`
- Shape: 12 files, including five external runtime packs
- Total: 93,388,231 bytes (89.1 MB by `verify_web_export.py`)
- Root PCK: 1,869,552 bytes
- Root PCK SHA-256: `494ef4c3a52d9bc8977aaae4f4fac1e3ca1f967f0e96780bb518367ac43adea9`
- Shell ID: `A-SET-RESTORE-001`
- Pack contract: `a-set-20260830`

## Screenshots

Fresh 1280x720 portrait and gameplay-distance captures are in:

- `Development_Gallery/screenshots/CHARACTER_REAL_001_kael.png`
- `Development_Gallery/screenshots/CHARACTER_REAL_001_sister_anwen.png`
- `Development_Gallery/screenshots/CHARACTER_REAL_001_villager_male.png`
- `Development_Gallery/screenshots/CHARACTER_REAL_001_villager_female.png`
- `Development_Gallery/screenshots/CHARACTER_REAL_001_castle_guard.png`
- `Development_Gallery/screenshots/CHARACTER_REAL_001_road_ranger.png`
- `Development_Gallery/screenshots/CHARACTER_REAL_001_ghoul_gaunt.png`
- `Development_Gallery/screenshots/CHARACTER_REAL_001_ghoul_stalker.png`
- `Development_Gallery/screenshots/CHARACTER_REAL_001_ghoul_brute.png`
- `Development_Gallery/screenshots/CHARACTER_REAL_001_bog_wretch.png`
- `Development_Gallery/screenshots/CHARACTER_REAL_001_gravebound_knight.png`
- `Development_Gallery/screenshots/CHARACTER_REAL_001_ashwing.png`
- `.release-gate/current/a_set_restore_local_chrome_retry_chrome.png`
- `.release-gate/current/a_set_restore_local_edge_edge.png`

## Verification

Passed:

- Content integrity and runtime smoke.
- Web identity, runtime-pack metadata, external pack hashes, and Web export shape.
- Packed PCK startup.
- BOOT-003, LOADGAME-002, LOAD-QA-001, and LOAD-QA-002 contracts.
- Asset acceptance, ASSET-005, PIPE-003, character-role, face, animation, motion, and visible-quality gates.
- CHAR-005 through CHAR-009 and CHARACTER-REAL-001.
- Fresh Chrome and Edge at 1280x720 WebGL2, real New Game click, Greyfen startup, and zero console errors.
- Greyfen-life route checks and character portrait capture.

The targeted ticket runner passed its `web`, `assets`, and `characters`
profiles. `QA-013` historical baseline evidence was not included because
`.release-gate/qa_soul_001_runtime.json`, `.release-gate/perf_001_report.json`,
and `.release-gate/opening_final.out` do not exist. This is recorded as an
evidence limitation, not converted into a false pass.

## Browser Measurements

- Chrome: 1280x720 WebGL2, engine-ready 10,591 ms, New Game ready 8,057 ms,
  JavaScript heap 11.5 MB, no console errors.
- Edge: 1280x720 WebGL2, engine-ready 18,110 ms, New Game ready 17,162 ms,
  JavaScript heap 11.5 MB, no console errors.

The startup path is reliable but remains slower than the long-term cold-boot
target. The timings are retained for the next loading-optimization pass.

## Known Limitations

- The restored A-set is cohesive stylized low-poly content, not photoreal
  character density.
- The preserved Godot shutdown-only ObjectDB/RID diagnostics remain outside
  active rendering; browser console checks are clean.
- The unavailable historical QA-013 evidence is not regenerated or guessed.
- Full campaign visual polish and deeper startup optimization remain later
  work; this ticket is limited to startup recovery, artifact alignment, and
  preferred character restoration.

## Running Locally

```powershell
cd "D:\Projects\AshenOath\outputs\AshenOathTheRoadBetweenCrowns"
cmd /c Export_Web_Build.bat
& "C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" tools\verify_web_export.py ..\AshenOath_Web
node tools\verify_web_browser.mjs --export ..\AshenOath_Web --browser chrome
node tools\verify_web_browser.mjs --export ..\AshenOath_Web --browser edge
```

Deployment promotion and the final live PCK comparison are recorded after
the checkpoint is pushed.
