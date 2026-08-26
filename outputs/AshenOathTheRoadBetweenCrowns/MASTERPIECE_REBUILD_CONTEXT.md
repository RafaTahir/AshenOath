# Ashen Oath Masterpiece Rebuild Context

This is the active implementation context for the 66-ticket Masterpiece Rebuild.
The production baseline is the synchronized `main` checkpoint from `RELEASE-004`.
The current branch is `codex/masterpiece-rebuild`.

## Truth boundary

The game is functionally broad but visually and architecturally provisional.
The following are explicitly unfinished until their rendered and player-facing
acceptance gates pass:

- real split Web packs and low-startup boot;
- the immediate Web boot shell and Crow Flight wait activity are now implemented
  and have dedicated acceptance gates; the current embedded-PCK fallback remains
  deliberate until hosted pack URLs are promoted;
- seamless exterior sectors;
- final human, monster, boss, weapon, and equipment presentation;
- final bow art and animation evidence; the first bow/ammunition/vendor slice is
  implemented on the development branch but still needs graphical and packed-Web
  acceptance;
- PACK-003 produces six real, hash-verified external PCK candidates totaling
  80.52 MB. They remain outside the shipped Web artifact while the loading
  candidate decision is open;
- STREAM-003 implements the download-to-temp, hash/size validation, cache,
  local mount, retry, cancellation, progress, and embedded-fallback lifecycle.
  The manifest still has empty production URLs, so the current candidate uses
  the embedded PCK fallback;
- the ASSET-005 runtime boundary is now explicit: Captain Senn's processed
  Ranger is the only approved role, while ten route-visible roles remain
  playable but visually blocked fallbacks;
- QA-013 now preserves one reproducible baseline ledger with a current
  identical-camera nine-view recapture, startup, transition, zone FPS, memory,
  and scene counts; final visual approval remains a separate gate;
- authored Greyfen, Wychwood, campaign, river, sky, and interior presentation;
- contact-driven combat and human-reviewed voice delivery;
- complete real-input campaign and final production evidence.

Milestone A's aggregate implementation/export/browser gate passed on
2026-08-26. It is still not release-ready: Chrome/Edge cold engine readiness
measured 42.94/27.11 seconds, New Game measured 4.79/6.22 seconds after the
Greyfen readiness point, and production pack URLs remain empty. See
`MILESTONE-A_RESULT.md` for the current evidence and blockers.

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
checks pass. The first two-browser run hit an Edge CDP screenshot timeout after
Chrome passed; the same export passed an isolated Edge retry. The clean-source
seven-file candidate is `87.30 MB` with PCK SHA-256
`D9BC435932A644F1BAA7D7DE8A1F1252F2E639320DF07C9523E4AAC22AB734BB`.
Fresh seam captures are current at `20260826_150551`. Noncritical audio and
heavy script-level asset preloads are deferred or moved to first use; this
keeps warmed headless boot near `0.53 s`, but fresh-profile graphical browser
measurements remain variable at Chrome `30.79 s` and Edge `26.29 s` to
engine-ready, with New Game at `4.17 s` and `5.11 s`. Production `web/`,
`main`, and Vercel remain unchanged because cold browser readiness is still
above the product target and shutdown-only Godot allocator/ObjectDB
diagnostics remain visible in graphical verifier teardown. This milestone is
therefore a verified development checkpoint, not a final production release.

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
