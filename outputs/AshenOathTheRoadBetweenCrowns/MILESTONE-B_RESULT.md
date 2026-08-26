# Milestone B Result

## Scope

Milestone B establishes a seamless exterior atlas and keeps interiors behind
ordinary physical doors. It covers `WORLDGRID-001`, `SEAM-001`, `SEAM-002`,
`NAV-002`, `SAVE-004`, `INTERIOR-001`, `SEAM-QA-001`, and the supporting
streaming/lifecycle regressions.

## Implementation

- Added the Greyfen -> Wychwood -> Deep Woods -> Old Mill -> Burned Farmstead
  -> Marsh Crossing -> Bandit Road -> Vargan Approach coordinate circuit.
- Replaced exterior transition panels with continuous route boundaries and
  retained a physical Castle approach-to-courtyard door.
- Added bridge-aware navigation, same-bank recovery, cross-sector save
  migration, transactional zone activation, and route-safe arrivals.
- Removed the campaign builder from the boot preload graph. Campaign zones now
  request `packs/campaign.pck` before the lazy builder is loaded on Web.
- Made the Web export verifier strict about seven root runtime files while
  allowing only the validated `packs/` runtime subdirectory.
- Added reproducible campaign-pack staging to `Export_Web_Build.bat` and
  cache-safe `/packs/*` hosting headers.

## Verification

The no-cache `milestone_b` ticket profile passed:

- content integrity and runtime smoke
- world atlas, seamless lifecycle, route composition, navigation, save
  migration, and interior-door gates
- player-driven exterior traversal in both directions
- runtime pack, scene, zone-builder, and navigation regressions
- Web export, packed startup, and strict nested-pack validation
- Chrome and Edge desktop WebGL2 smoke tests at 1280x720
- fresh seamless changed-view capture

The campaign mount follow-up also passed from the reduced main PCK: mounting
`campaign.pck` exposed and instantiated `campaign_section.gd` successfully.

Browser results from the authoritative profile:

| Browser | Canvas | Engine ready | New Game | Console/resource errors |
|---|---:|---:|---:|---:|
| Chrome | 1280x720 WebGL2 | 28.04 s | 6.64 s | none |
| Edge | 1280x720 WebGL2 | 25.63 s | 7.86 s | none |

Artifact results:

- Total: `84,886,834` bytes / `80.95 MB`
- Main PCK: `45,942,372` bytes / `43.81 MB`
- Main PCK SHA-256: `FB90BA224A97BC01341755198A2D0FC61847D534A750245FFBA38CF25D30991B`
- Campaign pack: `884,856` bytes
- Campaign pack SHA-256: `E3773163700109A7E2195E485A41BA46461220445CE645878CD583825A383D8E`

Fresh changed-view captures:

- `Development_Gallery/screenshots/SEAM_001_01_GreyfenBoundary_20260826_161353.png`
- `Development_Gallery/screenshots/SEAM_001_02_WychwoodArrival_20260826_161353.png`

## Production verification

The verified candidate artifact was promoted in commit `0b4e317` (`MILESTONE-B:
publish verified Web candidate`). The final evidence and live-browser tooling
checkpoint is `59e982a` (`MILESTONE-B: record production promotion and live
smoke`); the cumulative branch and `origin/main` now point to that checkpoint.
Tracked `web/` contains the same seven root runtime files plus the staged
`packs/campaign.pck`.

The deployed artifact matches the local export:

- Live main PCK: `45,942,372` bytes, SHA-256
  `FB90BA224A97BC01341755198A2D0FC61847D534A750245FFBA38CF25D30991B`
- Live campaign pack: `884,856` bytes, SHA-256
  `E3773163700109A7E2195E485A41BA46461220445CE645878CD583825A383D8E`

The same isolated browser smoke was run against Vercel after deployment:

| Browser | Canvas | Engine ready | New Game | Console/resource errors |
|---|---:|---:|---:|---:|
| Chrome | 1280x720 WebGL2 | 24.39 s | 8.86 s | none |
| Edge | 1280x720 WebGL2 | 20.56 s | 4.46 s | none |

Both production runs reached Greyfen, accepted the New Game input, and
produced nonblank screenshots.

## Honest limitations

The route and artifact gates pass, but the broader product contract is not
finished by this milestone. Fresh-profile browser engine readiness remains
above the later `<12 s` cold-start target, and Godot emits shutdown-only
allocator/ObjectDB diagnostics after isolated graphical verifier teardown.
Later-zone art and character presentation also remain procedural/blockout-grade
and are intentionally deferred to the visual and campaign milestones.

## Promotion status

Promotion is complete. Commit `59e982a` is pushed to
`codex/masterpiece-rebuild` and `origin/main`; Vercel serves the matching main
PCK and campaign pack. The cache-busted production smoke URL is:

`https://ashenoath.vercel.app/?v=milestone-b-59e982a-live`

## Running

```powershell
cd C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns
$env:GODOT_BIN='C:\Users\User\.cache\codex-runtimes\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe'
$env:ASHEN_OATH_PACK_DIRECTORY='C:\Users\User\.cache\codex-runtimes\ashenoath-packs-v2'
powershell -ExecutionPolicy Bypass -File .\tools\run_ticket_gate.ps1 -Profiles milestone_b -ChangedViews seamless -NoCache

node .\tools\verify_web_browser.mjs --url "https://ashenoath.vercel.app/?v=milestone-b-59e982a-live" --browser chrome --renderer software --timeout 180000 --report .release-gate\ticket\live_web_browser_chrome.json
node .\tools\verify_web_browser.mjs --url "https://ashenoath.vercel.app/?v=milestone-b-59e982a-live" --browser edge --renderer software --timeout 180000 --report .release-gate\ticket\live_web_browser_edge.json
```
