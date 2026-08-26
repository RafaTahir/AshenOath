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

## Honest limitations

The route and artifact gates pass, but the broader product contract is not
finished by this milestone. Fresh-profile browser engine readiness remains
above the later `<12 s` cold-start target, and Godot emits shutdown-only
allocator/ObjectDB diagnostics after isolated graphical verifier teardown.
Later-zone art and character presentation also remain procedural/blockout-grade
and are intentionally deferred to the visual and campaign milestones.

## Promotion status

Before promotion, production `main`, tracked `web/`, and Vercel remain on the
previous release. The milestone release step must copy the verified candidate
including `packs/campaign.pck`, commit the cumulative branch, push `main`,
compare the live PCK hash, and run the production smoke test.

## Running

```powershell
cd C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns
$env:GODOT_BIN='C:\Users\User\.cache\codex-runtimes\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe'
$env:ASHEN_OATH_PACK_DIRECTORY='C:\Users\User\.cache\codex-runtimes\ashenoath-packs-v2'
powershell -ExecutionPolicy Bypass -File .\tools\run_ticket_gate.ps1 -Profiles milestone_b -ChangedViews seamless -NoCache
```
