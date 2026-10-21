# FINISH-001 - Reliable Launch And Menu

Parent: [FINISH-000](FINISH-000.md). Dependencies: current baseline.
Implementation: early usable menu and selected-destination preparation implemented 2026-10-21.
Compilation: startup-menu-20261021 production import, eight packs and Web export completed.
User acceptance: Pending. Publication: explicitly authorized 2026-10-21; see FINISH-001 publication receipt.

## Player Outcome

A fresh launch reaches an immediately usable main menu. Only the selected New
Game or Continue starts a journey, with truthful preparation and actionable Retry.

## Existing Owners And Evidence

Extend the existing runtime pack manager, journey flow/load owners, game startup,
HUD/menu layout and Web shell, not another loading framework.
[Startup repair](../../outputs/AshenOathTheRoadBetweenCrowns/NEW_GAME_STARTUP_REPAIR_RESULT.md),
[menu/runtime smoothing](../../outputs/AshenOathTheRoadBetweenCrowns/STARTUP_SMOOTH_001_RESULT.md)
and [body-readiness repair](../../outputs/AshenOathTheRoadBetweenCrowns/BOOT_009_RESULT.md)
are historical scoped evidence. Use the
[current package record](../six-worlds/IMPLEMENTATION.md) for this candidate.

## Remaining Conditions And Bounded Repair

- Cold and warm launch remain at the main menu until an explicit journey action.
- Menu reveal requires working handlers and save summaries, independently of
  world preparation. Complete scenery, population, collision and the actual
  gameplay-camera render remain mandatory before first control.
- New Game uses one prepared world. Selected Continue loads that selected save's
  destination, not a different journey or a mandatory Greyfen detour.
- Persisted Quality and quality changes during preparation load the required packs;
  failed/cancelled attempts cannot activate obsolete worlds.
- Interrupted downloads or preparation produce a visible reason and Retry.
  Retry retains successful downloads/resources without clearing settings or saves.
- Progress follows actual phases, never announces 100% early and never brings
  back Crow Flight, an extra launch button or an inert artwork-only screen.
- Returning to a suspended existing session pauses safely; it does not start a
  second journey or leak an outgoing menu click into gameplay.

Repair only a reported failing owner. Timing compliance belongs to FINISH-014;
this ticket supplies its functional start/end boundaries, not a speed claim.

## User Manual Checklist

1. Fresh and warm launch: use Settings, Controls and saved-journey selection as
   soon as the menu appears. Queue and cancel New Game, then request it once;
   confirm complete Greyfen, visible Kael and functioning movement at first control.
2. Reload and explicitly Continue a named earned save; confirm its world/location.
3. Open settings, select each retained quality preset and return; interrupt one
   preparation by selecting Continue and confirm only that journey starts.
4. Interrupt the connection during a required download, restore it and use Retry;
   confirm recovery with the same saves/preferences and no duplicated world.
5. Switch away/back and use pause/resume; confirm the menu never dismisses itself.

## Delivery Record

2026-10-21 build-only candidate: startup-menu-20261021. Menu visibility no longer
depends on completed Greyfen preparation. New Game queues visibly and can be
cancelled; Retry and byte-based pack progress remain inside the menu. Continue
invalidates obsolete Greyfen work before downloading its selected destination.
Gameplay service creation is sliced and services stay inactive until configured;
required gameplay initialization still completes before control. Prepared actor
requests use the actual crowd visual-role/variant policy, retaining authored
recovery bodies and texture validation. Obsolete callbacks cannot publish a world.
The complete first-camera render is reused without a second completion draw or
rebuilding the menu when preparation ends, so Settings/save browsing keeps focus.

Optional chapter artwork moved from root to campaign; all artwork/content remains.
Root transport: 6,579,567 -> 4,175,575 bytes (36.5% smaller). Opening transport:
32,503,408 -> 32,503,403 bytes; its native PCK is unchanged at 35,474,180 bytes.
Engine transport is unchanged. Complete export including release_manifest.json:
104,691,963 bytes, 165,637 below the strict 104,857,600-byte cap. Root SHA-256:
f8a2e1b5fc32b897a9cf11a946408f9b0c12dae01f4e21831cba063a9732ac41.
Package: D:/Projects/AshenOath/.release-gate/startup-menu-20261021/export.
Source: cumulative worktree based on 9d4609b. Publication of these existing bytes
was explicitly authorized on 2026-10-21; the FINISH-001 publication receipt owns
the resulting commit/deployment identity. Static diff
review and production compilation/package generation completed. No gameplay,
browser QA, benchmark, profiling or screenshots were run. Startup gains, Retry,
selected Continue and actual phone behavior require user testing. No acceptance
cell or historical performance failure is promoted to passed by this build.

2026-10-20 build-only repair (user-candidate): the deferred pack-ready callback
carries the preparation generation and requires an active wait; failed/cancelled
attempts and expired old waiters cannot start or fail a replacement attempt.
Preparation failure discards partial Greyfen/player/camera state so Retry cannot
early-out on an abandoned zone_root. Quality changes also restart a failed
preparation, without clearing preferences/saves. Resource failure detail is shown
in the existing Retry presentation. Every opening detail stage, navigation and
resource validation completes before the final camera render; completion metadata
prevents the former delayed no-op detail scheduler/full-tree audit after control.
Runtime activation and required arrival finalization now precede the playable
marker. Compilation/package status is recorded in FINISH-000; no agent runtime
checks are authorized or performed. Timing and user acceptance remain unverified.

2026-10-20 authorized verification attempt 1/1: finish-line-20261019-oils,
hardware Chrome, normal opening/Save/Continue route. HARNESS FAIL before game
navigation: blank-tab Page.enable and the other renderer-domain enables timed out
after 15 seconds. Total 19,513 ms, no engine/game observation. Report:
D:/Temp/AshenOath/finish-001-20261020/browser.json.
Correction: move the existing data-page renderer bootstrap before domain enables.
No game or candidate bytes changed; this ticket's attempt is not repeated.
Unchanged candidate's earlier mouse New Game/complete opening route observations
remain valid at their limited scope; Quality/Retry/warm checks remain unobserved.
Agent verification: incomplete. User verdict/date: Pending.

Subsequent targeted browser cells: a23 proved normal earned Quick Save/durable
reload/Continue; a45/a47/a49 proved normal selected-destination Continue into
campaign districts; a54 fresh Chrome at 960x540 reached the menu and started only
after real mouse New Game, with complete ready/textured Kael and movement. Its
normal durable Save/reload/Continue/settings restoration also completed. No console
errors/warnings captured. Timings (36.55s menu /39.29s control /2.105s handoff) miss
strict goals owned by FINISH-014. Persisted Quality, cancelled preparation/Retry,
and the a50 interrupted automatic-pointer boundary remain separately unverified.

a60-a62 targeted the persisted-Quality dependency cell on unchanged prompt-verbs
bytes (104,688,170 complete bytes). a60 never navigated because Fetch rejected
Chrome's OS-selected DevTools port 4045. The loopback-only transport now uses
node:http and the existing pinned ws client, not Fetch/native WebSocket. a61
selected Quality but its UI acknowledgement waiter expired during pack loading;
the committed preference was preserved. a62 resumed it without another selection.
Normal Continue then loaded Greyfen with quality_materials ready and Kael's actual
atlas/body bindings valid. Balanced was restored durably; unrelated preferences,
supplies, health and the genuine Quick Save were unchanged. No console errors or
warnings. Overall FAIL remains strict browser-private memory 515.5 MB, not an
accepted performance result. This closes the persisted-Quality/normal Continue
cell only; Retry/cancellation and other listed conditions are not inferred.
Evidence: D:/Temp/AshenOath/finish-targeted-20261020-a62-quality/browser.json.

