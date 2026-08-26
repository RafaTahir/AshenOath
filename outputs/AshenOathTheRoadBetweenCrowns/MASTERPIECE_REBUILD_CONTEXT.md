# Ashen Oath Masterpiece Rebuild Context

This is the active implementation context for the 66-ticket Masterpiece Rebuild.
The historical production baseline was the synchronized `main` checkpoint
from `RELEASE-004`; the current production checkpoint is recorded below.
The current branch is `codex/masterpiece-rebuild`, and Milestone A is promoted
to production in commit `45e628e`. `origin/main`, tracked `web/`, and Vercel
share the current 89.43 MB, 12-file Web export with root PCK SHA-256
`0E819446442435F703C253D6AD0C3AF892C8D5EA9F680BD7A0DA7AAE6101E6DF`.

## Truth boundary

The game is functionally broad but visually and architecturally provisional.
The following are explicitly unfinished until their rendered and player-facing
acceptance gates pass:

- the cold browser target still needs further loading optimization; the current
  candidate has real relative opening, campaign, character, monster, and audio
  packs beside the root runtime, with the embedded base PCK as fallback;
- the immediate Web boot shell, Crow Flight wait activity, and focused keyboard
  startup path are implemented and pass the current browser gate;
- later-zone visual reconstruction beyond the now-playable seamless exterior
  sectors;
- final human, monster, boss, weapon, and equipment presentation;
- final bow art and animation evidence; the first bow/ammunition/vendor slice is
  implemented on the development branch but still needs graphical and packed-Web
  acceptance;
- PACK-003 produces six real, hash-verified external PCK candidates totaling
  55,217,080 bytes. The current Web candidate stages five streamed packs beside
  the root runtime; the six-pack candidate set remains outside source control;
- STREAM-003 implements the download-to-temp, hash/size validation, cache,
  local mount, retry, cancellation, progress, and embedded-fallback lifecycle.
  The A candidate uses relative pack URLs that resolve beside the Web export;
- the ASSET-005 runtime boundary is now explicit: Captain Senn's processed
  Ranger is the only approved role, while ten route-visible roles remain
  playable but visually blocked fallbacks;
- QA-013 now preserves one reproducible baseline ledger with a current
  identical-camera nine-view recapture, startup, transition, zone FPS, memory,
  and scene counts; final visual approval remains a separate gate;
- authored Greyfen, Wychwood, campaign, river, sky, and interior presentation;
- contact-driven combat and human-reviewed voice delivery;
- complete real-input campaign and final production evidence.

Milestone A's final aggregate implementation/export/browser gate passed on
2026-08-26. Chrome/Edge engine readiness measured 8.30/9.07 seconds and the
candidate reached Greyfen with no browser console or resource errors. The
8-second typical-startup follow-up, software-browser event-to-frame timing,
and later visual quality work remain explicitly documented. See
`MILESTONE-A_RESULT.md` for the current evidence.

Existing result documents are historical evidence only. They do not override a
current `visually_rejected`, `functional_but_incomplete`, or `blocked` status.

## Milestone B working status - 2026-08-26

WORLDGRID-001, SEAM-001, SEAM-002, NAV-002, SAVE-004, and INTERIOR-001 are
implemented on `codex/masterpiece-rebuild`. The player-driven SEAM-QA-001
verifier passes the complete Greyfen -> Wychwood -> Deep Woods -> Old Mill ->
Burned Farmstead -> Marsh -> Bandit Road -> Vargan Approach circuit in both
directions, with grounded arrivals, no exterior OathGatePortal nodes, and no
full-screen loading layer. Castle approach to courtyard is retained as a
physical-door route. Legacy interior save coordinates now migrate to the
correct world cells.

The Milestone B structural gates, export, packed startup, and browser route
checks pass. The final authoritative profile also passed both browser smoke
tests after the lazy pack handoff: Chrome reached a 1280x720 WebGL2 canvas with
engine-ready `28.04 s` and New Game `6.64 s`; Edge reached the same canvas with
engine-ready `25.63 s` and New Game `7.86 s`. Both had no browser console or
resource errors. The candidate is `80.95 MB` total, with a `43.81 MB` main
PCK (`FB90BA224A97BC01341755198A2D0FC61847D534A750245FFBA38CF25D30991B`) and
`packs/campaign.pck` at `884,856` bytes with SHA-256
`E3773163700109A7E2195E485A41BA46461220445CE645878CD583825A383D8E`.
Fresh seam captures are current at `20260826_161353`. The main PCK no longer
preloads campaign builders; the campaign pack mount verifier proves the lazy
builder is available before later-zone construction. The broader product cold
startup target remains above target in this software-browser environment, and
Godot still emits shutdown-only allocator/ObjectDB diagnostics after passing
isolated graphical gates. Those remain follow-up work for the loading and
lifecycle tickets; they do not invalidate the passed Milestone B route gates.
The verified candidate is now promoted to `origin/main` and Vercel; the live
main and campaign-pack hashes match the local export, and Chrome/Edge
production smoke tests reached Greyfen without console errors.

## Locked product decisions

- Exterior regions become one continuous walkable world. Interiors may stream
  behind ordinary physical doors.
- Oath Gates are optional late-game fast travel after physical discovery, never
  required for ordinary exterior travel.
- Bow combat uses hybrid over-shoulder manual aim with optional soft lock.
- Tor sells weapons and ammunition; Mira sells consumables and alchemy stock.
- Standard, Bodkin, and Ashfire arrows are the first supported arrow families.
- Voice uses offline, licensed, pre-rendered synthesis only when it passes a
  naturalness gate. There is no browser speech fallback in production.
  Subtitles remain authoritative.

## Acceptance floor

Balanced native 1280x720 must average at least 32 FPS with a 30 FPS 1% low.
Memory remains below 450 MB and the complete Web delivery remains below 100 MB.
Cold startup is targeted below 12 seconds, repeat startup below 3 seconds, and
New Game below 750 ms after Greyfen is ready. No black frame, permanent input
lock, active renderer error, parser error, browser console error, or stale PCK
may pass a milestone.

## Ticket discipline

Each ticket owns a bounded result document, targeted verifier profile, changed
views, save/load checks where relevant, and one development-branch checkpoint.
Milestone releases run the full relevant gate, export the verified build, sync
`web/`, push `main`, compare the local/live PCK hash, and smoke-test production.
