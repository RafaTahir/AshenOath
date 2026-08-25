# Ashen Oath Masterpiece Rebuild Context

This is the active implementation context for the 66-ticket Masterpiece Rebuild.
The production baseline is the synchronized `main` checkpoint from `RELEASE-004`.
The current branch is `codex/masterpiece-rebuild`.

## Truth boundary

The game is functionally broad but visually and architecturally provisional.
The following are explicitly unfinished until their rendered and player-facing
acceptance gates pass:

- real split Web packs and low-startup boot;
- seamless exterior sectors;
- final human, monster, boss, weapon, and equipment presentation;
- final bow art and animation evidence; the first bow/ammunition/vendor slice is
  implemented on the development branch but still needs graphical and packed-Web
  acceptance;
- the ASSET-005 runtime boundary is now explicit: Captain Senn's processed
  Ranger is the only approved role, while ten route-visible roles remain
  playable but visually blocked fallbacks;
- QA-013 now preserves one reproducible baseline ledger for historical images,
  startup, transition, zone FPS, memory, and scene counts; fresh graphical
  recapture remains required when Godot is available;
- authored Greyfen, Wychwood, campaign, river, sky, and interior presentation;
- contact-driven combat and human-reviewed voice delivery;
- complete real-input campaign and final production evidence.

Existing result documents are historical evidence only. They do not override a
current `visually_rejected`, `functional_but_incomplete`, or `blocked` status.

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
