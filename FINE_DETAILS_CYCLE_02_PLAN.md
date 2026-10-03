# Fine details cycle 02: the people and the road ahead

Date: 2026-10-03. Starting published package: `5cc787f`; Vercel deployment `dpl_6Xz2GWt1oXjDxkDyxpPoTAofTyeC`.

Cycle 01 is published. Continuous autonomous work remains authorized. This plan precedes cycle 02 implementation. The standing instruction excludes tests, verification, review passes and approval pauses. Production import/export and handling its actual compiler diagnostics remain part of producing the release.

## Intended experience

When returning to Ashen Oath, the player should quickly recover who matters, what they promised, what they know and the next useful action. Story guidance should occupy a stable space in the HUD. The journal should preserve discovered people and practical commitments without implying that a completed quest grants someone's consent.

Build on the existing state, authored quest beats, menu continuity and notice queue. Keep a bounded scope: journal organization, HUD information hierarchy and discovered-route presentation. No new campaign branches, morality score or progression layer.

## A. A journal for people, evidence and unfinished work

Owner: story/player-experience implementer. Files: `scripts/story_journal.gd`, new `data/journal_people.json`, new `data/journal_work.json`, and a small model helper if needed. The HUD is owned by package B.

1. Expose `sections(quests, state, zone_id) -> Array[Dictionary]` with stable section identities: On Return, People & Promises, Evidence, Unfinished Work, and Preparation. Each section has a title and bounded entries with stable IDs and readable text. Keep `build_from_state` as the compatible plain-text formatter.
2. Add authored People & Promises records for known characters. Gate discovery by actual encounter evidence or explicit, relevant decisions in older saves. Present known facts, committed promises and participation as voluntary, protected, compelled, refused, unavailable or unknown. Keep unknown people hidden; never infer consent from generic objective completion.
3. Add `recap_model(quests, state, zone_id) -> Dictionary`: current promise, last recorded commitment and next known action with its location and reason. On Return remains available after the arrival notice. Ending recaps direct attention to remaining return activities using actual ending state.
4. Keep observed facts, testimony and inference distinct with known source/location. Model practical obligations such as repairs, deliveries, worker rescue, records and aftermath in the new work catalog. Only expose work once its context is known. A missing flag means unresolved knowledge, not an invented failure.
5. Supply `encounter_record(speaker_id, zone_id) -> Dictionary` returning an evidence ID and metadata for a recognized character, or an empty dictionary. Root owns the actual state mutation when that speaker's page is displayed. Preserve conservative identity labels when a character's name has not yet been revealed.

Model contract: sections include `id`, `title`, `body` and optional `entries`; each entry includes `id`, `title`, `body`. Additional fields can describe a known status without changing the existing save schema. Inform the HUD owner of the final contract before integration.

## B. A steady story-first HUD

Owner: presentation implementer. Files: `scripts/hud.gd`, optional small layout/attention helper. Own all HUD integration for A and C; retain cycle 01 focus, scroll, draft, History and notice behavior.

1. Split tracker presentation into a quiet chapter title and a fixed Next step region. Keep `set_tracker(text)` compatible and reserve space for useful wrapped objective text. Show the current Journal binding in a fixed footer.
2. Use separate information bands for location, enemy/target information, guidance, interaction and notices. Reserve heights so changes do not move nearby controls. Hide stale gameplay hints while dialogue, History, menus or loading own attention.
3. Give resource numbers stable alignment and compact equipment rows with current controls and count columns. Keep critical health/stamina information visible. Use short attention intervals on meaningful resource/target events; exploration returns to a quieter treatment without scanning the world.
4. Preserve the notice queue and reading deferral. Add restrained category labels and a consistent notice area. Coalesce generic combat cues so actionable messages remain legible. Extend contrast and reduced-motion/flash treatment to all affected labels and panels; steady text communicates low health or exhaustion.
5. Integrate A's stable journal sections with section-specific focus/scroll memory. Remove duplicate physical-work prose after the model owns those entries. Keep People & Promises and the persistent return recap easy to reach. The chapter atlas remains supportive rather than taking over the reading area.

## C. Directions grounded in the current story

Owner: world/input implementer. Files: `scripts/objective_view_model.gd`, `scripts/quest_presentation_state.gd`, `scripts/quest_hud_coordinator.gd`, narrow `scripts/quest_beat_director.gd` and `scripts/story_activity_director.gd`, and authored metadata where necessary. Root owns `game.gd`; B owns HUD.

1. Extend the existing objective view with destination zone, interaction target IDs and guidance scope. Derive directions from the current authored beat and actual objective state. Preserve quest progression ownership and stable quest IDs.
2. Distinguish nearby work from another named destination. Show metres only for an actual eligible local target; use clear destination wording for travel. Prefer the relevant nearby target or real exit rather than an unrelated interaction.
3. Use `world_sector_manifest.json` and actual gate targets for current route presentation. Preserve discovery by exposing only a justified next step and destinations the character already knows.
4. Expose read-only started-work and discovered-waypost models for journal/HUD reuse. Keep current travel eligibility, encounter restrictions and arrival locations. Add useful labels and concise availability reasons rather than changing the travel rules.
5. Provide guidance for remaining ending return activities and a deliberate explore/return state when no obligation is currently selected. Do not manufacture an objective failure or a future revelation from absent flags.

Coordinate exact extended HUD interfaces with B and root before wiring. Presentation consumers must remain compatible with the existing view fields and `set_tracker`/`set_compass` calls.

Agreed navigation API: `quest_presentation.setup(quests, beats, story_state = null)` and `get_navigation_view_model()`. Extend objective fields with `destination_zone`, `destination_name`, `target_ids`, `guidance_scope`, `route_hint` and `purpose`. `quest_hud_coordinator.build_navigation_model(player, zone_id, candidates)` returns `primary`, `action`, `scope`, `distance_m`, `route_hint` and at most two `nearby_work` reminders. HUD accepts `set_navigation_model(model)` while retaining the old setters. `StoryActivityDirector.get_waypost_model(game)` exposes discovered routes; `get_started_work(state, zone_id)` exposes only explicitly started local obligations. Preserve manually tracked quests. Pending covenant ritual instructions precede ending return guidance; the return sequence is Greyfen, names, workbench, road.

## D. Root integration and publication

Owner: root. Files: `scripts/game.gd`, `scripts/runtime_service_registry.gd` as needed, `tools/build_source_catalog.py`, export/pipeline files if required, this plan and the execution ledger.

1. On actual dialogue page display, request A's encounter record for the current speaker. Store first discovery through existing `StoryState.record_evidence`, then schedule existing story persistence. Do not pre-discover every participant when a conversation opens.
2. Add the people/work catalogs and their text fields to source-language generation. They remain ordinary included `data/*.json` resources.
3. Wire current zone, story and route context to the existing quest/HUD services according to C's explicit interface. Preserve save/replay and cycle 01 input handoff behavior.
4. Commit source, generate a fresh production package, handle actual build failures, commit generated files, push the two authorized branches and deploy the existing Vercel project. Record CLI publication results without post-deployment checks.
5. Keep the continuing objective active. Write the next justified refinement plan after this release before its implementation.

## Completion and limits

This cycle's implementation milestone consists of integrated source, completed production packaging and successful publication commands. It does not certify visual perfection, accessibility, performance, gameplay or a reviewed narrative experience. Those verification activities remain excluded by the user's instruction.

## Execution record

- Plan written before code changes, following independent source-context planning for journal, HUD and routes.
- Implementation started under the ownership and interface contracts above.
- Root now records first speaker encounters on actual page display, defers their existing save persistence until dialogue closes, supplies story state to quest presentation, and includes the two new catalogs in source-language generation.
- Root also coalesces story changes into a deferred tracker/compass refresh so practical work and aftermath directions can change while the player is stationary.
- Package B is implemented: fixed story/navigation card, separate gameplay information bands, stable resource rows, event-based emphasis, steady accessibility warnings, sectioned journal with reading memory, and preserved full Quest Record. Packages A and C remain in progress; production compilation waits for their completed interfaces.
- Package A is implemented: structured journal model and authored people/work catalogs, persistent state-based recap, neutral speaker-account discovery, conservative identity visibility and explicit consent/assistance distinctions. Package C's route/waypost implementation is in its final integration stage.
- Package C is implemented: shared `story_route_catalog.gd`, explicit destinations and local targets, eligible immediate exits, continuation/aftermath priority, remembered wayposts and explicitly started work. A narrow interaction-focus extension uses authored target IDs. Current root APIs suffice. The English source catalog has been generated with 1,283 entries; production packaging follows the last HUD distance-contract integration.
