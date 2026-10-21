# Finish-Line Candidate: User Testing And Release Handoff

Candidate: `startup-menu-20261021` (2026-10-21).
Package: `D:/Projects/AshenOath/.release-gate/startup-menu-20261021/export`.
Publication of these exact bytes was explicitly authorized on 2026-10-21.
The FINISH-001 publication receipt records the resulting commit/deployment.
Runtime acceptance remains user-owned; publication does not establish a pass.

Production compilation/package generation succeeded. Complete package:
104,691,963 bytes including the manifest (165,637 bytes below 100 MiB).
Root transport SHA-256:
`f8a2e1b5fc32b897a9cf11a946408f9b0c12dae01f4e21831cba063a9732ac41`.
The manifest records its build-time dirty source based on `9d4609b`. The publication
receipt records the commit that includes this implementation and exact package.
Agent runtime testing of this candidate: NOT PERFORMED. User acceptance: 0/16.

Desktop preview: http://127.0.0.1:5466/ (local machine only, while the preview
process is running). This serves the frozen export with its declared gzip headers;
do not open index.html directly or use a plain server without those headers.
Preview logs: D:/Temp/AshenOath/startup-menu-20261021/preview.*.log (PID 6644).
It serves files only; no browser, game or automatic QA has been launched.
The preview has its own origin/storage, not the production origin's saves. Keep
production saves intact; use normal new saves here or explicitly import a copy.
This desktop-only address does not establish actual-phone or production coverage.

## What Changed

- The usable menu no longer waits for all of Greyfen. New Game queues visibly
  with inline progress/Retry/Cancel; selected Continue supersedes unused Greyfen
  work. Gameplay services prepare in slices and activate before control.
- Startup preloads resolve the actual prepared actor/crowd resources. A completed
  Greyfen is retained through handoff without another completion draw or forced
  menu rebuild. Settings/save browsing keeps its surface and focus.
- Optional chapter art moved to the campaign pack, reducing the initial game
  transport from 6,579,567 to 4,175,575 bytes. Opening, engine, character and
  environment content remain; no measured loading-speed improvement is claimed.
- Stale preparation callbacks cannot resurrect cancelled/failed attempts; Retry
  discards partial worlds while keeping loaded resources, saves and preferences.
- Greyfen's complete scenery/navigation and actual camera are prepared before
  readiness; required arrival finalization no longer runs after returned control.
- Duplicate arrival audits are removed. Unowned animation-cache variants release
  their helper references; live/cached actors keep their own resources.
- New Continue records contain their exact selected data in the same atomic file
  as the selection. Separate interrupted slot writes cannot substitute another
  journey. Old saves, schema 13, preferences and recovery choices remain.
- Web save messages distinguish a session write from pending browser persistence.

## Consolidated Checklist

1. **Launch and Retry (001):** cold/warm launch reaches a usable menu before the
   world finishes; check Settings/Controls immediately. Queue/cancel New Game,
   then request it once and confirm complete Greyfen. It never starts a journey
   without that request. Check
   Balanced/Quality and changing quality. Interrupt a download, restore connection
   and Retry. A cancelled preparation must not replace a selected Continue world.
2. **Saves (002/017):** note location, health, supplies, XP, Marks, learned practice,
   oil timer and one changed binding/volume. Save, allow browser storage to finish,
   then reload and Continue; repeat after browser restart. On a disposable journey,
   also check an interrupted autosave, old pointer-only save, corrupt-copy recovery,
   unfinished wave, partial escort and phased-boss death recovery. Never damage
   your only save. Check that no rewards/choices/health refills are invented.
3. **Controls and combat (003-006):** eight-direction movement, reversals,
   footsteps, full camera yaw/first person, visible textured Kael/NPCs, draw/sheath,
   light/heavy, guard/parry, bow and Oathfire. Check Use matches its prompt,
   settings/remapping persist, menus/pause/focus/resize work and XP/Marks match.
4. **Regions and story (007-012/015):** reuse completed unchanged checks. Check
   affected Greyfen/zone arrivals and returns, required interactions, saved ongoing
   encounters, aftermath and homecoming. All four endings and regional content
   have historical observations, not blanket acceptance of this candidate.
5. **Actual phone and audio (005/013):** phone landscape entry/Continue, simultaneous
   move/look, Use, combat, short menus/dialogue, orientation/focus and persistence
   after browser restart. Listen for missing/doubled/desynchronized footsteps or
   combat sounds; check audio unlock, pause and saved volumes. Desktop resizing
   does not prove iPhone/WebKit support. Unavailable controllers remain untested.
6. **Strict reference-PC performance (014):** use the existing Intel HD 620,
   native 1280x720 Balanced/full content procedure. Required: average >=32 FPS,
   1% low >=30, actual owned-process peak private memory <450 MiB; cold/warm
   transitions <=900/350 ms. Web first paint <=0.75 s; cold/warm menu <=12/6 s;
   navigation-to-control <=15/7 s; prepared New Game <=750 ms. Include first
   playable frames and slow frames; report phone results separately. No new
   measurements or numerical improvement are claimed by source compilation.

## Returning Results And Publication

Send the candidate ID, device/browser, failed step, what happened versus what you
expected, and any timings/screenshots you choose to collect. Missing checks remain
unverified. Explicit acceptance, compilation and publication are separate.

Strict performance remains unresolved, not declared impossible. The last valid
pre-experiment native baseline was Greyfen 15.71 FPS average / 11.27 FPS 1% low,
with 828.54 MiB peak private memory. It does not measure this new candidate.
The later dispatcher-only experiment was rejected and its source removed; its
26.27/15.87 FPS result and 777.70 MiB are not a retained performance claim. If your
measurements still fail strict targets, the next strategy is measured owner-level
resource/render-cost work, not another dispatcher-only lazy-loading change. Any
change to hardware support or numerical guarantees needs your explicit decision.

After mandatory results pass and you approve release, publish these exact bytes
once: sync web, commit/push development, integrate main, deploy and reconcile live
hashes. You then confirm production New Game and the live-origin saved Continue.
Do not rebuild merely for publication or treat provider READY as gameplay proof.
