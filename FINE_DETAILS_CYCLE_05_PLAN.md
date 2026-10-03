# Fine details cycle 05: room to ask

Date: 2026-10-03. Starting production package: `cda02e1`, publishing fix `9c38c69`; Vercel deployment `dpl_8BNgf6ffoxZLoV7MabPN6ASmz28o`.

This plan precedes implementation. The continuing autonomous objective includes publishing each coherent improvement and proceeding to the next planned pass. No tests, verification, review passes or approval gates are introduced. Production content generation, compiler/import/export and responding to actual diagnostics remain part of building.

## Intended experience

Let Kael ask people how they are living with events already known to the player. These conversations add personal texture without another quest, reward, morality score or change to consent. Use existing characters, current physical presence and explicit outcomes. Preserve the story's central actions and give the player a reliable way back to the exact conversation they left.

## Writing and catalog

The writing owner creates `data/conversation_topics.json`: version 1, topics array, stable id and revision, exact actor_ids, speaker_id/name/title/summary, positive existing conditions, known_evidence, require_variant, explicit speaker lines and outcome variants. Variants have id/priority/conditions/known_evidence and optional title/summary/lines. Shared outcome topics require a matching variant; there is no uninformed fallback.

Ten topics: Anwen's kept coat after names return; her basket handles after relief and the stopped renewal; Mira's handwriting after kept/confessed/destroyed truth; Rook's memory of Bram after the cart and his boundaries after protected/public/erased disclosure; Tor's grinding stone after each iron decision and his practical teaching after road repair; Edric's seal after renewal and his exact stance; Senn reading the deserters' refusal only in testimony custody; Halvern's preserved words only when the witnessed fragment and command proof are known. Each uses three to five brief turns, Kael and the current NPC only. Retain all existing action IDs, quest branches, outcomes and promises.

## Read-only runtime

The world owner extends `dialogue_manager.gd` and `dialogue_runtime_coordinator.gd` only. Catalog APIs: `load_conversation_topics(path)`, `get_conversation_topics(actor_id, zone_id, seen_keys)`, and `get_conversation_topic(topic_id, actor_id, zone_id, expected_revision)`. Rows contain id/title/summary/revision_key/history_key/visited. Fresh resolution returns a read-only scene with topic_id/topic_revision/topic_history_key/name/scene_id/presentation/pages and an empty actions array. Pages have read_only/topic identifiers and stable revision-based History text IDs. Reading never writes evidence, consent, quest progress or rewards.

The staged actor owns a transient topic context. `bind_topic_context(actor_id, zone_id)` returns an opaque context ID. `get_topic_context(context_id)` succeeds only for the same live, enabled staged actor with the matching interaction ID. Staging and release invalidate prior contexts. Root also compares the current zone and resolves eligibility again for every selected topic. There are no journal-triggered or remote conversations.

## Conversation presentation

The presentation owner extends `hud.gd` and may add a bounded helper. On the final primary page, place one quiet Ask more entry after the main story actions; do not prefer its focus over a story action. No eligible topics means no extra entry. The topic list and topic reader use the existing dialogue layer, subtitle settings, History, page count, release activation and input bindings.

Keep one primary snapshot: pages/session/page, subtitle and choice scroll, decision detail state, and focus. Back from a topic returns to the list; Back from the list restores that snapshot. Returning must not emit dialogue_closed, action_selected or page_changed, add duplicate History, or replay the parent voice. Topic pages are navigation only and contain no action payloads. In-History markers derive from existing displayed History revision keys, never a new story flag or save schema.

Contract: primary data includes topic_context_id and optional_topics. HUD emits `dialogue_topic_requested(context_id, topic_id, revision_key)` and `dialogue_speech_interrupted`; methods are `show_dialogue_topic(scene)`, `dialogue_topic_unavailable(context_id)`, `get_dialogue_topic_seen_keys()`. Coordinate any small signature adjustments before use. Speech stops at subview transitions while the existing conversation pose, pause and audio ducking remain active.

## Root integration and voice publication

Root owns `game.gd`, `runtime_service_registry.gd`, source/voice/build tooling and this ledger. Load the catalog, bind only after staging the actual NPC, add eligible rows to resolved primary dialogue, route topic requests directly to read-only resolution, and stop voice on reading navigation. Existing page handling retains camera, speaker performance and exact text voice playback; topic pages bypass story discovery/evidence registration. Existing History saving remains authoritative.

Include the catalog's title/summary/text/name in generated English source data. Extend exact-text voice collection across base and variant topic lines using explicit speaker IDs and existing hash-cached clips. Add optional `-BuildVoices` to the production builder so new voiced writing, import, packs, export, commit, push and deployment can run in one operation. Publish generated voice assets, production manifest and attribution files only when that option is used. Existing voice provenance and subtitle fallback remain explicit.

Commit integrated source; generate all current dialogue/topic voices; build with a fresh candidate and `-BuildVoices -Publish`. Resolve actual generation/compiler/publishing failures and continue from retained artifacts whenever possible. Record real CLI outcomes without claiming gameplay or listening checks. After publication, prepare and execute the next justified refinement plan.

## Execution record

- Separate prose, runtime and presentation proposals were combined into this written plan before source edits.
- Root connected catalog loading, live actor/zone resolution, page audio and optional-reading History persistence. Topic pages bypass encounter evidence registration. Build tooling now supports topic text extraction and `-BuildVoices` with generated voice/provenance artifacts included in publication.
- The ten-topic catalog and read-only manager/context implementation have landed. Outcome variants retain existing story flags and consent. New voice clips use temporary files before entering their exact-text cache path, allowing interrupted generation to resume without accepting a partial new clip. HUD implements the bounded list/reader and primary restoration; final Back/input routing is being completed.
- HUD implementation is complete, including Back/B/Escape topic-to-list-to-primary navigation, History return position, stale-focus generation guards and speech interruption. The integrated source proceeds to commit and production generation/publication.
- Published source `cd05d25f52a1` as build `story-20261003T140746Z-cd05d25f52a1`, package `d31d19c`. The production command generated 406 exact-text clips, exported all packs and Web, pushed both branches and deployed successfully without a manual handoff. Vercel returned `READY` for `dpl_Hd5jZ7BhQi8rpL9NupUKrVVx7KbH`, aliased to `https://ashenoath.vercel.app`. No tests, listening or post-deployment checks were run. Continuous work proceeds to cycle 06 planning.
