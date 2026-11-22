# Ashen Oath — final delivery changelog

Subsequent release: the user later requested a Witcher-inspired HUD redesign. That additional work is now pushed and deployed; its complete changes and release identity are recorded in [Witcher-inspired HUD release](WITCHER_INSPIRED_HUD.md). The story-overhaul delivery recorded below remains its original historical release.

Date: 4 October 2026  
Game: **Ashen Oath: The Road Between Crowns**  
Repository: [RafaTahir/AshenOath](https://github.com/RafaTahir/AshenOath)  
Production address: [ashenoath.vercel.app](https://ashenoath.vercel.app)  
Release status: **Complete - final package pushed and deployed; development stopped at the requested endpoint.**

The delivery endpoint is fixed: finish the current story overhaul and all seven refinement cycles, push the completed work, deploy the production package, list the delivered changes, and stop. No further improvement cycle is included.

The completed delivery includes the story overhaul and all seven refinement cycles. Source `0297582170b5356972ca3a3c84d61d8a71515c6d` produced build `story-20261003T185007Z-0297582170b5`; packaged commit `5a27c7cc189a24f2ac40479c2fa69154ed1bd287` was pushed to both `main` and `codex/story-centered-overhaul`. Godot import, all seven runtime packs and Web export completed. Vercel deployment `dpl_Ag4e31kFjbxMhyZLJcPbnPSpGvBi` returned `status: ok`, `readyState: READY` and production alias `https://ashenoath.vercel.app`. The deployment uploaded 87.9 MB; its unique address is [the final production deployment](https://ashenoath-gttfet7qw-rafaeitahir-5792s-projects.vercel.app).

The pipeline's first deployment attempt returned `Not authorized`. A direct retry using the existing signed-in CLI succeeded with the same completed package; no game export was repeated. This delivery record and changelog are pushed as documentation after the deployed package. No post-deployment requests or checks were performed.

This changelog consolidates documented implementation. The master plan supplies creative direction; its proposed playtime, performance, production-quality and acceptance targets are not presented as delivered measurements.

## Story and character overhaul

- Retained Kael, Greyfen, Anwen, the White Hart, the concealed massacre and the central relationship between denied memory and monsters. Rewrote main-campaign and optional-story material around the living consequences of that history.
- Reworked ten main quests, six substantial optional stories and four shorter interludes around the central story, preserving stable quest/action identities.
- Made the present road-renewal conflict part of the campaign: Edric's attempt to connect household assent to grain and protection gives the historical mystery a current political consequence.
- Connected investigation, preparation, practical help, confrontation and return scenes. Recovering an account now has consequences for the people who receive it and the work required afterward.
- Kept responsibility specific. Documents, remembered acts, voluntary testimony, protected participation, compelled admissions and refusal remain distinct. Finding evidence or finishing a generic objective does not supply another person's consent.
- Preserved Kael's personal admission about abandoning civilians on a different road. His responsibility is expressed through his own commitments rather than by making him the hidden cause of Greyfen's history.
- Kept Halvern's surviving memory bounded by sanctuary, refusal and execution. It does not become an all-knowing account of later events or a consenting living witness.
- Reworked character consequences around Anwen's concealment, Mira's treatment and disclosure, Rook's family privacy, Tor's marked iron, Senn's accountability and Edric's stance. Existing quest and action IDs remain anchors for progression and older saves.

## Playable consequences, encounters and endings

- Added event-driven story staging and visible local aftermath, including participation that reflects whether a witness is willing, protected, compelled, absent or unavailable.
- Added physical village and road work: carried grain, household deliveries, drainage and road repairs, mill aid, discovered wayposts and a Vargan shortcut.
- Added encounter-specific environmental actions: the Bell-Eater's shelter rhythm and named rope; Rootbound root redirection and testimony recovery; Ashwing's sluice, worker escort, record rescue and perch interaction; protected Halvern surrender; and Senn's evidence-or-relief stand-down.
- Connected recovered evidence to combat preparation and openings. Journal preparation notes explain already discovered advantages without requiring a particular purchase.
- Implemented the Witness, Mercy, Duty and Ash resolutions through three peaceful covenant rituals and the Ash confrontation. Choosing an intention and carrying out its resolution are separate recorded events.
- Added three return activities for each covenant outcome, bringing the player back to names, ordinary work and the road. Individual epilogues follow those return scenes and use recorded decisions and practical outcomes.

## Persistent story state, saves and replay

- Separated evidence discovery from consequential decisions, with batched publication of accepted story actions.
- Advanced the save implementation to schema 10 while retaining legacy preservation, backups and explicit unknown outcomes. Older progress does not silently invent a missing choice or witness agreement.
- Added six named manual save slots, protected decision checkpoints and a pre-covenant save.
- Added browser import/export with input/schema validation and recoverable replacement backups.
- Added chapter replay through copied campaign state, keeping replay identity and ordinary campaign saves separate.
- Added persistent conversation History, including accepted-decision receipts and current-page reading records.
- Added local downloadable problem reports and accessible credits. Reports are exported locally; the game does not automatically send them to another party.

## Preparation, progression and accessibility

- Integrated supplies, emergency medicine and the existing nine-practice progression with the story-centered experience.
- Kept authoritative item effects and economy rules in their owning services. Preparation presentation now describes the actual implemented action rather than an independent estimate.
- Added or extended difficulty, audio mix, subtitle size, subtitle background opacity, speaker labels, high contrast, reduced motion, reduced flash, hold/toggle block and sprint, and bounded targeting assistance.
- Added English source-text preparation with stable catalog identities and a glossary. **The delivered language is English only.** No translated language release is claimed.

## Character presentation, illustration, music and speech

- Added ten character presentation profiles with keepsakes, restrained speaking/listening movement and character-specific conversation rhythm. Existing complete rigs, anatomy, clothing atlases and compatible assets remain in use.
- Added an illustrated chapter atlas for journal headers, generated with OpenAI image generation.
- Added seven original procedural musical motifs for story states and covenant outcomes, with dialogue ducking and continued quiet ambience. Existing combat music retains its role.
- Included **406 synthetic exact-text voice clips** in the current voice package, with model/source attribution retained. The optional-conversation release added 71 clips to the preceding 335-clip set.
- Bound voice lookup to the current narrative revision, speaker and exact text. A missing or mismatched clip leaves the subtitle authoritative; changing pages interrupts the previous page's speech.
- Paused current-page speech while reviewing History and preserved its playback position on return. Optional-topic navigation interrupts speech without replaying the parent page automatically.

These are generated performances. No human listening or performance review was carried out in this session. The presentation does not claim bespoke performance capture, newly replaced character anatomy or synchronized lip animation.

## Refinement cycle 01 — keep the player's place

- Added bounded screen navigation memory, stable action identities, consistent parent Back behavior and restored menu/journal/shop focus and scroll.
- Retained edited save names and pasted import drafts across related screens, with operation-specific results shown locally.
- Preserved dialogue page, subtitle position, choices and focused action through History, without adding duplicate reading entries or restarting the current page.
- Added wrapped, padded controls and visible focus treatment.
- Replaced competing toast updates with categorized, prioritized notices, including coalesced saves, deferred story messages and expiring combat guidance.
- Added binding-aware interaction prompts, explicit availability and stable target selection that remains subject to actual range and eligibility.
- Added fresh-press/release barriers across dialogue, menus, travel, focus loss and input-device changes.
- Refined browser startup with optional Crow Flight, truthful download versus preparation stages, focused recovery actions and a deliberate foreground input handoff.
- Deferred new-journey identity and History reset until the accepted world handoff.

## Refinement cycle 02 — people and the road ahead

- Organized the journal into On Return, People & Promises, Evidence, Unfinished Work and Preparation, while retaining the full Quest Record.
- Added a persistent recap of the current purpose, last recorded commitment and next known action, including remaining covenant return work.
- Added discovered-character records and authored practical-work records. Unknown identities and unrecorded outcomes remain unknown.
- Recorded character knowledge when an actual speaker page is displayed, using neutral account wording that also accommodates recollection and quoted testimony.
- Gave story guidance, location, targets, resources, interactions and notices separate HUD areas, with quieter exploration presentation and steady critical-resource cues.
- Added explicit destinations, actual eligible local distances, discovered-waypost availability and reminders for work already begun. Manual quest tracking remains authoritative.

## Refinement cycle 03 — preparation and deliberate choices

- Added selected item, vendor and practice details with owned quantities, capacity, active coating or arrow, actual effects and relevant comparisons.
- Added crafting quotes covering ingredients, shortages, output and applicable refunds; vendor quotes covering quantity, price, remaining coins, stock and capacity; and practice details covering benefits and requirements.
- Kept unavailable actions visible with reasons and returned purchase, craft, use, selection and learning results to a stable local feedback area.
- Added public ammunition selection and prevented wasting a health or stamina remedy when its corresponding resource is already full. Existing tonic and bomb effect values were preserved.
- Added a focused choice-detail reader for immediate commitments, known facts, costs and supported uncertainty.
- Added accepted-decision receipts to History, with covenant intention clearly separated from enactment.
- Preserved the selected item and navigation position during deferred operation refreshes.

## Refinement cycle 04 — return to the same journey

- Added saved-state summaries for place, chapter, promise, last commitment, next known action, resources and recorded time. Missing legacy metadata stays unknown; save time and world time are distinguished.
- Made Continue, checkpoint recovery, manual slots and replay load the exact source shown by their selection model.
- Added a stable resume pointer. Renaming a slot retains journey identity; importing different contents does not silently redirect Continue to them.
- Added explicit empty, unavailable, newer-version and recoverable-backup presentation. A missing pointed source does not silently choose an unrelated journey.
- Staged destination content before replacing current inventory, quests, story, settings, History or journey identity. Preparation can be cancelled; late content callbacks cannot revive an abandoned request.
- Suppressed ordinary save writes during pending loads and reported load completion only after the accepted player/destination handoff.
- Added persistent Pause/On Return cards, concise arrival guidance and truthful defeat recovery wording about the recorded state being restored.

This protection covers content preparation before incoming state is applied. It does not promise rollback after arbitrary engine failures during scene construction.

## Refinement cycle 05 — room to ask

- Added ten optional, player-initiated conversation topics for present characters, gated on explicit existing outcomes and completed practical work.
- Topics concern Anwen's kept coat and basket handles; Mira's medicine labels; Rook's memory of Bram and disclosure boundaries; Tor's grinding stone and hammer teaching; Edric's seal; Senn's reading of refusal; and Halvern's preserved words.
- Added outcome-specific variants and explicit speaker identities. Topics contain no rewards, quest mutations, new promises or consent changes.
- Added Ask more, topic lists and topic reading within the existing dialogue surface, with a return to the exact primary conversation and its story choices.
- Derived read badges from displayed History revisions, keeping topics available to read again without a new story-state schema.
- Extended English source extraction and exact-text voice generation to the new material.

## Refinement cycle 06 — follow the recorded account

- Added a discovered-evidence list and focused reader with populated Observation, Testimony and Inference filters.
- Authored twelve detailed records: Bram, Sella, Oren, Vargan wire, drag marks, three graves, mill accounts, Senn's admission, command proof and the renewal order.
- Separated recorded material, interpretation, limits and practical relevance. Command proof remains a document account until Halvern's bounded memory is explicitly known; the renewal's removal appears only once recorded.
- Distinguished actual recorded locations from associated places. No discovery date or chain of custody is invented.
- Added links only to independently known evidence, people and preparation entries, plus at most one current lead from an active related quest.
- Preserved filters, selected entries and reading positions through related reading with a bounded Back trail. A different journey or replay clears the prior timeline's navigation trail.
- Added visible return controls and keyboard/controller access to the reader without creating new world pins or changing quest tracking.

## Refinement cycle 07 — keep the story within reach

- Added a shared layout policy using actual displayed game dimensions and safe/visible insets while preserving the fixed 1280×720 render canvas.
- Added wide and compact layouts, display-aware typography and control-size budgets, and scrolling when the available reading area cannot hold the content.
- Reflowed live HUD, menu, dialogue, journal and loading controls without rebuilding the current story page or discarding its selection.
- Added compact journal reader/list panes with persistent navigation, stacked preparation actions and short-layout dialogue body scrolling beneath fixed navigation.
- Added a reflow-state helper retaining weak control references and numeric focus, scroll, caret and selection positions. It stores no copied story content or draft text.
- Added event-driven browser/native display metrics and safe-area delivery, including changes in the visible browser viewport.
- Added shared touch geometry, explicit finger ownership, cancellation at context changes, release-inside navigation, emulated-mouse isolation and intentional device switching.
- Positioned critical vitals above touch controls and kept central prompts/status clear of the reserved control area, quieting secondary tracker and supply details in compact gameplay layouts.
- Retained Pause and Journal navigation when touch combat cannot fit. Unusable touch geometry pauses gameplay, explains the restriction and guards Resume; recovering sufficient space does not resume automatically.

These are implemented sizing and input policies. They are not a claim of perfect portrait gameplay, universal device compatibility or measured accessibility compliance.

## Build and publication work

- Reconnected the existing Vercel project after the interrupted login/link/build sequence.
- Restored omitted companion assets and normalized author-local material references needed by the existing asset set. One optional legacy `Chest_Wood.mtl` source remained unavailable; the documented preceding production exports completed without it.
- Kept the existing Godot 4.6.3 and seven-runtime-pack/Web export foundation. Addressed actual compiler, import, command-quoting and publication-path diagnostics as release work.
- Added build-duration sleep inhibition, retained prior artifacts, and added explicit `-Publish` and optional `-BuildVoices` production paths with local phase receipts.
- Published the expanded story package and all seven refinement cycles to the authorized GitHub branches and existing Vercel project. The final cycle 07 production identity and successful publication result are recorded at the top of this document.

## Delivery limits

At the user's instruction, this implementation session included no tests, QA, gameplay sessions, screenshots, previews, performance measurements, listening passes, post-deployment verification or review passes. Production compilation/import/export is necessary artifact generation and is not presented as a substitute for those activities.

No measured campaign duration, frame-rate guarantee, exhaustive ending/save coverage, accessibility certification or visual perfection is claimed. The master plan's playtime and quality targets remain targets, not release facts. Existing assets were reused alongside new staging, keepsakes, illustration and generated audio; this is not a replacement of every asset. English is the only delivered language, and synthetic voice/music performances remain unreviewed.

## Documentation basis

- [Execution ledger](OVERHAUL_PROGRESS.md)
- [Story overhaul master plan](STORY_OVERHAUL_MASTER_PLAN.md), used for creative direction and explicit target boundaries
- [Story art and sound direction](STORY_ART_AND_SOUND_BIBLE.md)
- [Cycle 01](FINE_DETAILS_CYCLE_01_PLAN.md), [cycle 02](FINE_DETAILS_CYCLE_02_PLAN.md), [cycle 03](FINE_DETAILS_CYCLE_03_PLAN.md), [cycle 04](FINE_DETAILS_CYCLE_04_PLAN.md), [cycle 05](FINE_DETAILS_CYCLE_05_PLAN.md), [cycle 06](FINE_DETAILS_CYCLE_06_PLAN.md) and [cycle 07](FINE_DETAILS_CYCLE_07_PLAN.md), including their implementation records
