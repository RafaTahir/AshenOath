# Fine details cycle 06: follow the recorded account

Date: 2026-10-03. Starting production package `d31d19c`, deployment `dpl_Hd5jZ7BhQi8rpL9NupUKrVVx7KbH`.

This plan precedes implementation. Continue autonomous work and publication under the existing instruction. No tests, verification, reviews or approval gates. Source reads inform design; actual production compiler/export diagnostics remain part of building.

## Intended experience

Replace the Evidence section's long combined reading area with a discovered-record list and a focused reader. Help the player understand what an object or testimony establishes, what remains an interpretation, and which already-known lead is relevant. Preserve the player's position through related reading, section changes and reopening. Keep all story choices, evidence acquisition, quest tracking and consent under their existing ownership.

## A. Authored records

The writing owner creates only `data/journal_evidence_details.json`: version 1 and a details array. Twelve existing IDs: bram, sella, oren, vargan_wire, drag_marks, grave_harl, grave_child, grave_soldier, mill_accounts, senn_account, command_proof and renewal_order. Retain their actual discovery gates from the current campaign; no new clue or discovery criterion.

Entries use id, source, record_ids, related_ids, related_quests, related_entries and sections. A section has id/kind/title/body and an optional existing-syntax gate. Kinds: observation, testimony, interpretation, limit and relevance. Two to four concise sections per detail distinguish attributed material, interpretation and limits. Avoid claiming verbatim quotation. Command proof concerns copied documents until halvern_is_fragment is explicitly true; only then add the bounded account. The renewal's outcome paragraph requires renewal_stopped. The three uncovered campaign records retain their present fallback.

Provenance aliases such as corpse, black_feathers, oren_token, claw_marks, tracks and millstones locate an existing saved record only. They never reveal a detail. Related links need independent discovery; a related quest does not imply a new obligation. No spoken dialogue changes or additional voices this cycle.

## B. Read-only detail model

The world owner edits only `story_journal_model.gd` and `story_journal.gd`. Add `StoryJournal.evidence_model(quests, state, zone_id)` returning body/entries/filters, and `StoryJournal.evidence_detail(entry_id, quests, state, zone_id)` returning a fresh known detail or empty. Keep ordinary sections and stable evidence:<id> keys compatible.

Entries include id/detail_id/title/body/kind/kind_label/source/place/place_label/recorded_text/text_label, blocks [{id,kind,title,body}], known_relevance [{id,title,body}], and links [{section_id,entry_id,label}]. Filters include only discovered kinds and their recorded counts. Reuse the existing discovery floor: explicit state evidence or current journal objective/flag gates. Whole quest completion grants nothing new; absent dependencies fail closed.

Eligible authored observation/testimony sections supply compact and detail text. Keep interpretation and record limits visibly labeled. Prefer explicitly saved record locations with Recorded at; fallback campaign locations use Associated place. Never invent a discovery date, possession or chain of custody. Source overrides may correct overly broad provenance before later testimony is known.

Resolve related evidence against independently discovered records and People/Preparation links against entries actually present in the current journal. Expose at most one current lead from an active related quest, preferring the already tracked related quest. Use its current active objective only. Ordinary routes may use StoryRouteCatalog; grouped evidence objectives retain their existing objective text so the reader does not identify a hidden fragment. Do not change tracking or create pins, coordinates, progress or consent.

## C. Evidence navigation

The presentation owner edits `hud.gd` and a new bounded `journal_evidence_navigation.gd`. Reuse the current inventory layer, typography, contrast controls and release activation. Keep journal section navigation; add populated All/Observation/Testimony/Inference filters and stable record rows. The initial reader is a concise overview; selecting a record displays its provenance, account, labeled detail blocks and relevant known lead. Show recorded counts only.

Keep filter, selected ID, list focus/scroll and per-entry reading offsets. Related links resolve again against current visible models before navigation. Evidence links open a detail; People/Preparation links open the known journal entry internally. Use an eight-entry identifier/position return trail, with no retained old story snapshots. Back restores the prior reader/list before closing; provide a visible Back to Evidence control for touch. Keyboard/controller navigation must reach the reader and related links without dismissing the journal. Empty filters offer All records. Defer text search: kinds and the bounded discovered list cover this pass.

Clear evidence navigation during `clear_journey_transients(true)` so another save/replay/new journey does not inherit a prior timeline's selected record. Preserve it during ordinary section switches and reopening. Leave preparation operations, saves, History and optional conversations on their existing paths. No automatic opening from an evidence pickup and no new world input binding.

## D. Root and release

Root adds the new catalog and authored source field to English source extraction, integrates necessary agreed contracts, and records work. No new runtime/root world hook is needed because the HUD already receives current quests, story state and zone context.

Commit integrated source, run production packaging with a fresh cycle06 candidate and `-Publish`, handle actual compiler or publishing failures, and record the returned Git/Vercel outcome. Existing 406 voiced clips are retained; do not rerun voice generation for this written-journal pass. Continue with the next justified written refinement plan after publication.

## Execution record

- Content, model and presentation proposals were reconciled into this written plan before source edits.
- Root took ownership of the new `journal_evidence_navigation.gd` helper before it was started, allowing HUD implementation to proceed in parallel. Its agreed API retains only filter/selected IDs, sanitized focus/index/scroll positions (bounded to 40) and an eight-entry identifier-only return trail. HUD owns fresh model resolution. The source catalog now includes authored evidence details and attribution strings.
- The twelve-entry writing catalog and read-only model have landed. `evidence_model` and `evidence_detail` preserve discovery, expose current known links, label actual versus associated location, and use only an active related quest's current objective. The HUD is completing list/detail and return navigation against these APIs.
- HUD integration is complete: discovered list and kind filters, fresh selected reader, known related links, bounded Back positions, visible return control, keyboard/controller reader handoff and new-timeline reset. No new root runtime hook was required. Integrated source proceeds to production compilation and publication.
- Published source `9b9f0ca33cd6` as build `story-20261003T143831Z-9b9f0ca33cd6`, package `62692a9`. The production command completed import, seven packs and Web export, pushed both branches and deployed. Vercel returned `READY` for `dpl_C5sh21nAQzAEiwoz1xJ2NRqoDCK8`, aliased to `https://ashenoath.vercel.app`. No tests or post-deployment checks were run. Continuous work proceeds to cycle 07 planning.
