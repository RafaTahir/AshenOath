# Fine details cycle 04: returning to the road

Date: 2026-10-03. Starting published package: `7634f08`; Vercel deployment `dpl_rstRtgGDvV7FVwPyqqWpiM8z4coL`.

This plan precedes implementation. Continuous autonomous work, publishing and deployment remain authorized. No tests, verification or review passes are part of the work; production import/export and handling actual command failures remain necessary release steps.

## Intended experience and approach

Continue should describe the exact journey it loads. Returning from a save, a defeat or a journey between places should quickly restore the current promise and next known action. A failed destination download should leave the current session intact. Recovery copy must describe the recorded state, without promising that unsaved decisions survive a rollback.

Use one shared save-selection model, a staged load handoff and the existing persistent story recap. Retain schema 10, stable quest IDs, legacy backups, protected decisions and isolated replay. Avoid a new save format, extra confirmation modal or a second quest-tracking system. Source reads for this design identified the relevant ownership boundaries; they are not a verification pass.

## A. Saved journeys and exact selection

Owner: player-experience implementer. Own `save_manager.gd` and new `saved_journey_model.gd`; root owns runtime integration.

1. Create read-only summaries from saved values and isolated quest/story views using the current journal model. Include recorded place/chapter, promise, last commitment, next known action, resources and available timestamps. Distinguish saved UTC from world time. Missing fields remain unknown; migration defaults do not manufacture recorded facts or playtime.
2. Add a small resume pointer at `user://ashen_oath_resume.json` for the last successfully saved or loaded gameplay source and its journey/replay identity. Rename/import and protected captures do not redirect Continue. The first successful New Game save establishes its pointer. Initial fallback uses ordinary dated campaign saves, then deterministic undated priority; replay remains separate. A missing/corrupt pointed source does not silently switch to an unrelated journey.
3. Expose `continue_model()` and `checkpoint_model()` with `{available, selection, summary, status, reason, recovery}`. Selection is opaque `{slot_id, source, token}` bound to exact source contents. HUD displays this model and emits that same selection for loading. Distinguish empty, ready, recoverable, unavailable and newer-version records; backups have their own truthful summary.
4. Extend existing slot/replay models compatibly with summaries, status, reasons and exact selections. Keep original atomic writes, backups, future-version preservation, protected-slot rules and manual-slot limits.
5. Add staged loading: `prepare_load(selection)` validates the selected data without replacing the session; `accept_prepared_load(request_id)` performs required replay-copy/legacy-archive writes after destination content is ready; `finish_load(game, request_id, success, reason)` publishes journey/replay/history/pointer only after the player handoff succeeds. A new ticket supersedes the prior ID. Failed or cancelled preparation releases the gate without replacing current identity/history.
6. `request_load(selection)` emits `load_prepared_requested(prepared)` and reports only request acceptance. Route legacy load wrappers through it. Gate ordinary saves, autosaves, checkpoints and protected captures while a prepared load is pending; required internal archive/copy writes remain explicitly owned by acceptance. Do not report a successful load at queue time.

Summary contract: `title`, `place`, `chapter`, `promise`, `last_commitment`, `next_action`, `saved_at`, `saved_at_known`, `resource_lines`, `time_label`, `world_clock_label`, `replay`, `journey_id`. `set_summary_definitions(quest_definitions, item_definitions)` supplies read-only catalogs. `SavedJourneyModel.describe(data, recorded, quest_defs, item_defs)` generates the summary.

Prepared-load contract: `{ok, request_id, data, summary, source, message, reason}`. Accept returns `{ok, request_id, message, reason}`. Finish returns `{ok, request_id, summary, source, message, reason}`. A pointer-write failure after a successful handoff is a storage note on that success, not a false claim that the old session was preserved.

## B. Return, recovery and save presentation

Owner: presentation implementer. Own `hud.gd` and a small journey presentation helper if needed. Preserve previous cycles' History, input release barriers, preparation actions, selected entries and navigation memory.

1. Add a Continue card with source, recorded place/chapter, timestamp or unknown wording, promise and next known step. Enable from the selected model rather than file existence. Prefer Continue focus on first menu entry when available; preserve explicit focus on later returns. Display backup/replay labels only from the model.
2. Keep a compact current-journey recap in Pause and provide direct On Return journal access. Replace lengthy arrival toast dependence with a short notice plus persistent pause/journal context. Update save feedback and the card in place without resetting reading or focus.
3. Make defeat recovery describe and load the exact available recorded source. Clearly state that its recorded story state returns; do not claim all current quest progress survives. Give unavailable sources a useful reason and access to Saved Journeys or a new journey without a confirmation modal.
4. Add readable slot summaries and source/status labels to existing pagination and slot details. Keep edited names, selected rows, page and reader position during updates. Manual/protected/replay controls remain faithful to service capabilities.
5. Expose `set_journey_models(models)` with `continue`, `recovery`, `current`; emit `journey_load_requested(selection)` and `journal_section_requested(section_id)`. Root refreshes these models before relevant surfaces and after save-library changes. HUD owns presentation, not source ordering or path parsing.
6. Loading and recovery presentation should retain an explicit cancellation/return path while destination content is preparing, following C's final handoff contract. Cancellation is navigation, not an approval dialog.

## C. Staged destination preparation and arrival continuity

Owner: world/story implementer. Own a dedicated journey-handoff helper and an arrival model helper if separation is useful; root owns `game.gd` integration. Coordinate with A and B before finalizing APIs.

1. Stage the destination's required runtime packs before applying incoming inventory, quests, story, settings, history or journey identity. Retain the current world and menu while this read/preparation phase runs. Use existing pack readiness/failure APIs and a bounded time-based wait; guard late callbacks with request generation.
2. Cancellation, superseding requests, failed downloads and shutdown invalidate the pending handoff. Keep failure messages scoped to the attempted journey. Restore the prior input/menu context and release the save gate. A pack becoming ready after cancellation cannot load its abandoned save.
3. Once required content is ready, accept the prepared save and let root apply its state through the existing zone transition. Finish only once the destination/player restore is ready. Preserve replay isolation and saved settings ownership.
4. Provide one short arrival model from the actual restored story context for a new journey, Continue, recovery or travel. Use known route/recap facts and current bindings. Defer the notice during dialogue or another reading surface; retain the full account in On Return and Pause. Avoid duplicate arrival messages or stale interaction targets.
5. Preserve existing world progress, encounter state, safe spawn rules, campaign arrivals and peaceful covenant behavior. This cycle protects the pre-mutation download phase; it does not claim rollback after arbitrary engine failures during scene construction.

## D. Root integration and publication

Owner: root. Own `game.gd`, `runtime_service_registry.gd`, narrow runtime integration and build/catalog tooling where necessary, plan and ledger.

1. Supply save-summary definitions and connect the prepared-load signal. Exact HUD selections flow into `request_load`; remove hidden Continue/checkpoint ordering from current UI handlers.
2. Stage required content through C's helper, apply data only after acceptance, and report completion at the actual player restore/handoff. Suppress automatic writes during pending loads and invalidate pending work on New Game/shutdown/cancellation. Keep direct compatibility entry points deliberate and truthful.
3. Refresh Continue/recovery/current models after library changes and before main/pause/death screens. Open On Return through existing journal navigation. Replace the misleading generic defeat copy and delayed long recap toast with the shared models.
4. Commit integrated source, run the corrected production builder with a fresh candidate and `-Publish`, handle actual compiler/command failures, and record Git/Vercel results. Retain completed artifacts on failure. No test, browser or post-deploy commands are introduced.
5. After publication, continue the active goal with the next justified written refinement plan.

## Completion and limits

This cycle completes when source is integrated and the production package is published. It does not claim measured performance, gameplay testing, visual perfection, accessibility certification or reviewed save migrations. The continuing objective remains active.

## Execution record

- Written before code changes after separate save-model, HUD and lifecycle planning.
- Lifecycle helper: `JourneyContinuityCoordinator.stage_restore(prepared, origin) -> int`, `restore_request()`, `claim_restore(generation)`, `cancel_restore(generation, reason)`, `finish_restore(generation)`, `begin_arrival(reason, target_zone, context) -> int`, and `take_arrival(generation, actual_zone, objective_view, recap)`. It is transient and data-only; SaveManager retains identity/history and root owns runtime-pack waiting/state application.
- Arrival fields are `id`, `context_id`, `reason`, `title`, `body`, `zone_name`, `next_action`, `destination_name`, `journal_section` and `announce`. Root consumes a cue once after actual player readiness. Same-zone refreshes remain quiet; ordinary travel announces only a useful changed story step.
- Missing legacy save timestamps remain unknown instead of becoming the current read time; missing journey identity is derived deterministically from original content. This preserves truthful recency and stable recovery identity.
- Root introduced `journey_load_runtime.gd` to keep download waiting, cancellation, acceptance, player-ready completion and arrival publication out of the large game script. `game.gd` exposes narrow routing methods. The current session remains paused and resident through preparation; only an accepted content-ready request reaches `_apply_loaded_journey`.
- New requests may supersede a ticket only while it is preparing. Accepted/applying tickets remain authoritative until completion. HUD `set_journey_load_applying()` removes cancellation at this boundary; arbitrary scene-construction rollback is outside scope.
- Root wired exact-selection signals, summary definitions, coalesced library model refreshes, persistent On Return access and recovery copy. The former delayed dialogue-close recap is replaced by a one-use cue after restoration. Ordinary pack failures now use one scoped message.
- HUD and transient coordinator are implemented. Continue/recovery/slot/replay buttons retain opaque selections; menu cards and save results update without resetting their place. The retained loading surface supports cancellation before application, and arrival notices wait for reading surfaces. Save-manager implementation is the remaining package before production compilation.
- SaveManager and saved-journey summaries are implemented. Legacy aliases become canonical prepared destinations; unknown destinations fail before application. The resume pointer uses a name-independent state identity so renaming retains Continue while importing different contents requires explicit loading. Prepared tickets cannot be superseded after acceptance. Root, HUD and service contracts are integrated; source commit and production packaging follow.
- Production import initially reported an unresolved journey-menu helper; its missing closing parenthesis was corrected in `e11e1de`. All seven packs and the Web export then completed: build `story-20261003T132623Z-e11e1de24966`, candidate `.release-gate/fine-details-cycle04-02`. Automation committed package `cda02e1` and pushed both branches. The Vercel stage reported a Windows command-tail quoting error; that invocation was corrected and deployment continues from the existing package.
