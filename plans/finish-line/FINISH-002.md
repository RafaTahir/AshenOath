# FINISH-002 - Durable Saves And Recovery

Additional earned runtime cell - 2026-10-20 a38: normal Continue restored the
selected primary unfinished Old Mill worker escort, matched to its pre-click
pointer timestamp/journey/save rather than a later autosave. Saved progress
0.27953 advanced to observed 0.62927 within the measured active interval; it was
not reset or automatically completed. Both workers then reached the south yard
through ordinary following. a36 had created the genuine interrupted checkpoint.
This adds an interrupted regional-work case to a23's exact general save/settings
proof; it does not certify unobserved corrupt/legacy/death cases. a38's later
numerical memory failure is retained separately.

Parent: [FINISH-000](FINISH-000.md). Dependencies: FINISH-001.
Implementation: existing save/encounter and additive saga persistence present.
Compilation: baseline recorded; not rerun. User acceptance: Pending.
Publication: baseline only.

## Player Outcome

Continue returns to the exact earned journey after reload, browser restart, death
or an interrupted task, without replacing choices, supplies or unfinished progress.

## Existing Owners And Evidence

Use existing SaveManager, saved-journey/load/continuity owners, StoryState,
QuestManager, InventoryManager, ProgressionManager and encounter restoration.
[PLAYFIX save scope](../../outputs/AshenOathTheRoadBetweenCrowns/PLAYTHROUGH_REPAIRS_STATUS.md),
[save-system record](../../outputs/AshenOathTheRoadBetweenCrowns/SAVE_001_RESULT.md)
and [saga compatibility](../six-worlds/IMPLEMENTATION.md) identify retained work.
Historical durable-save proof is not automatic acceptance of new saga fields.

## Remaining Conditions And Bounded Repair

- Confirm durable browser storage through actual reload and full browser restart,
  then normal Continue. An in-memory save message alone is insufficient.
- Preserve slot identity, location, supplies, equipment/oil selection, XP, Marks,
  skills, secrets, pending deliveries, partial work, companions and recorded choices.
- An unfinished Wychwood wave and phased boss restore their earned remaining state.
  Death uses safe authored arrivals without free healing, refills or invented kills.
- Legacy saves retain completed encounters/quests; moved Bog and settled Senn do
  not replay or duplicate rewards. Missing historical choices remain unknown.
- Recovery copies disclose location/time/source and never silently select another
  journey. Invalid positions and corrupt data follow the existing explicit recovery.
- Keep atomic/versioned save ownership. Do not replace the schema to solve an
  isolated missing field or store stale scene-node references.

## User Manual Checklist

1. Save a recognizable earned state, noting slot, world, supplies, XP, learned
   practice and one changed setting; reload and Continue, then repeat after restart.
2. Save mid-wave and during partial regional work/escort; resume and finish without
   lost progress, duplicate enemies, repeated rewards or an automatic task completion.
3. Die during an encounter; check safe arrival and the recorded supplies/phase.
4. Continue an actual older save before/after moved Bog or settled Senn; verify
   retained progress. Keep missing legacy fixtures explicitly blocked, not fabricated.
5. Using only a disposable copy of your save, exercise the existing corrupt-save
   recovery path and check clearly identified choices; never corrupt your sole save.

## Delivery Record

2026-10-20 build-only repair (user-candidate): the recorded a50 discrepancy proves
the pointer and slot can describe different persisted generations, but does not
establish the precise browser flush/interruption sequence. The new Continue JSON
adds the exact selected payload to its existing version-1 identity record, so a
durable selection has its own data in the same atomic file. Snapshot loading uses
the existing prepared-load flow and validates slot, journey, replay, game/version,
location, full state token and selection token again before acceptance. Future-
version slots remain blocked; another journey is never automatically substituted.
Same-second differing states prefer the exact embedded state rather than guessing
which write was newer. Old pointer-only saves retain their previous behavior.
Slot data/schema 13 are unchanged; there are no manufactured choices or rewards.
The bounded resume record retains the existing 2-MiB read limit. Browser messages
state synchronization is pending, not acknowledged durable completion, and do not
mask an unsuccessful Continue-pointer write with a later generic success toast.
No agent runtime test was run. Interrupted storage, old records, death/recovery
and normal Save/Continue belong to the user's checklist and remain unverified.

a59-growth decisively passed a controlled automatic-save durability boundary on
tracker-lines: actual practice purchases and respec wrote the earned autosave
and matching pointer to IndexedDB before reload. Normal Continue (without a
Recovery substitute) restored the purchased chain, then the refunded 17 Marks.
XP, supplies, health and fitting entitlements were unchanged; the genuine Quick
Save was not overwritten. No console errors/warnings. Overall run FAIL remains
strict browser-private memory 566.1 MB. This is a normal paired-durability pass,
not a claim about arbitrary forced shutdown or proof of a50's exact interrupted
owner. Legacy/death/corrupt-copy gaps and user acceptance remain separate.
Evidence: D:/Temp/AshenOath/finish-targeted-20261020-a59-growth/browser.json.

a50 ending-branch reload exposed an interrupted automatic-selection boundary:
the durable resume pointer described Autosave at 09:43:50 while its stored payload
still had 09:41:09. Main menu correctly offered explicit same-journey Recovery and
Saved Journeys, with Continue disabled. Do not count that reload as a normal-
Continue pass or erase the discrepancy. Its owner (reload before paired durability
versus persistence defect) is not yet established by this snapshot. The separate
earlier a23 exact earned Quick Save/durable/reload/Continue proof remains scoped
and valid. FINISH-012's ending branches now select the genuine pre-choice Quick
Save through ordinary Saved Journeys; that is branch coverage, not a persistence
fix or substitute. Report:
D:/Temp/AshenOath/finish-targeted-20261020-a50-endings/browser.json.

2026-10-20 verification attempt 1/1 on finish-line-20261019-oils: GAME FAIL.
Mouse New Game and ordinary movement worked. A quick save and settings were
confirmed in durable IndexedDB, but Continue became disabled after reload.
The retained LevelDB write batches show the delayed opening checkpoint replaced
the Continue pointer while that checkpoint's file was absent from durable storage;
the earned quick save remained available as recovery. No game-console/network errors.
Report: D:/Temp/AshenOath/finish-002-20261020/browser.json. Profile preserved on D:.

Repair: background checkpoints no longer retarget an explicit quick/manual/backup
selection of the same journey. Atomic save and pointer renames request one
coalesced deferred Web filesystem sync using JavaScriptBridge.force_fs_sync().
No implicit different-save fallback or save deletion. The existing browser check
now requires durable pointer and selected-file agreement, not just quick-save bytes.
Runtime source changed: a replacement package is required before subsequent
ticket checks; this ticket is not rerun under its consumed allocation.
Agent verification: failed then repaired, unverified repair. User verdict: Pending.
Legacy, death/partial-wave, corrupt-copy and restart coverage remain incomplete.

Shared later observations on finish-line-20261020-final: 009/010 normal Continue
after browser restart restored the earned four-kill Wychwood wave with only the
brute remaining. Saved health was preserved; no automatic healing or fabricated
enemy deaths. 010 defeated that final enemy and completed the private report.
012 again restored the road-complete Greyfen journey. This supplies real unfinished-
wave durability evidence, but does not replace the still-unreached explicit quick-
save/settings/oil reload check or approve all legacy, death and regional-work cases.

Targeted a2 exposed a further GAME Continue defect, independent of file durability:
the saved open-chapel Bell encounter rebuilt before its monster model pack mounted.
The zone arrival now carries encounter-specific pack requirements through the
existing request/readiness/failure wait, without adding campaign dependencies to
fresh Greyfen menu preparation. New encounter candidate compilation is in progress;
its actual saved-encounter restoration passed in a3 without resource/runtime
errors, followed by the real Bell fight/aftermath/shrine in later checks.

Targeted a18-save exposed a separate GAME settings ownership defect: normal
Continue replaced newer global volume/subtitle/reduced-motion/F9 preferences
with the older journey snapshot. The journey loader now imports embedded
preferences only as a fallback without current settings; post-startup edits
become authoritative even before restart. First-launch platform defaults and
legacy fallback remain. Replacement preferences candidate compiling; exact
Quick Save durability/preferences recheck pending. No journey restart or
settings/save injection. Evidence: D:/Temp/AshenOath/finish-targeted-20261020-a18-save/browser.json.

a19 observed the repaired offscreen Controls focus, then stopped on HARNESS
rejection of equivalent pinned/list Resume buttons. a20 normal Continue retained
the scalar preferences but lost the most recent F9 binding. Settings writes now
request the same deferred browser filesystem persistence used by saves. a21-save
uses compiled finish-line-20261020-settings-sync and first requires F9 in durable
IndexedDB before saving/reloading, separating write durability from journey load
ownership. Passed scalar settings/resize are reused; original a16 preferences
are restored through normal UI afterward. Whole-ticket verdict remains pending.

a23-save: PASS for the targeted explicit Quick Save durability boundary. The
visible same-journey recovery was deliberately selected after forced-cleanup
interrupted an earlier autosave; that selection is not called normal Continue.
A new real Quick Save then reached IndexedDB. Reload and normal Continue restored
quick/primary journey 1792429317-53995, health 24.8704, position/objectives and
earned inventory/story exactly, plus volume/subtitle/reduced-motion/F9 settings.
F9 was durable before saving. No console/resource/network errors captured.
Subsequent HARNESS navigation to Anwen failed; it does not invalidate these
completed cells. Original run remains failed overall. a24 combines remaining F9
execution/restoration with the required Mira briefing rather than repeating
durable-save proof. Legacy/death/corrupt/remaining partial-task cases stay pending.
Evidence: D:/Temp/AshenOath/finish-targeted-20261020-a23-save/browser.json.

