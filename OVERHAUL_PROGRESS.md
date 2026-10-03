# Ashen Oath story overhaul execution ledger

Plan: C:/Users/User/Documents/Codex/AshenOath/plans/2026-10-03-ashen-oath-story-overhaul-master-plan.md

## Authorization

2026-10-03: User approved keeping the core identity with a major rewrite, then requested implementation, no testing or verification, followed by push and deployment. This explicitly replaces plan and skill test/review gates for this execution. Compilation/export remains necessary to create the release. No QA, smoke, browser, screenshot, lint or gameplay verification will run. Changed work is untested.

The user subsequently directed continuous autonomous work until explicitly stopped: finish the current story implementation and publish, then write and execute successive improvement plans focused on interactions, HUD, navigation and fine visual details. Intermediate releases do not complete this objective. Routine edits, commands, publishing and implementation decisions are already authorized. Platform access restrictions remain applicable; reuse existing permissions rather than adding conversational approval gates.

## Workspace

Worktree: C:/Users/User/Documents/Codex/AshenOath/build
Branch: codex/story-centered-overhaul
Starting commit: 6b991c6
Original checkout and its untracked artifacts are retained at D:/Projects/AshenOath.

## Ownership

- Narrative implementer: dialogue/quest content and narrative canon. Preserves action IDs; defines new outcome flags for root integration.
- World implementer: zone scripts and new story world director; physical opening, chapter staging, investigation counterplay and aftermath.
- Experience implementer: HUD/journal/epilogues, quest beat guidance, vendor/progression systems.
- Root: story/quest/decision/save integration, dialogue runtime ownership, combat/boss/audio/accessibility integration as needed, export and publication.

## Execution rulings

- The user's no-testing instruction governs. Report no test passes or certification.
- Existing action IDs and quest IDs are migration anchors. New choices add explicit flags rather than reinterpreting legacy decisions silently.
- Preserve primary branch and user files; build in isolated worktree. Push/deployment already authorized.
- No engine upgrade or new dependency framework. Use pinned Godot 4.6.3 and existing export/runtime-pack format.

## Work status

- Narrative content: main campaign and side-story rewrites implemented; stable quest/action identities retained.
- Story state and saves: decision/evidence separation, batched decision publication, schema 10, legacy-slot preservation, and pre-covenant save implemented.
- World staging and aftermath: event-driven story compositions, voluntary witness staging, three peaceful covenant rituals, Ash confrontation, physical village work, encounter counterplay, and three return activities per ending implemented.
- Player experience: journal, decision previews, epilogues after return scenes, evidence-earned combat opportunities, supplies, emergency medicine, nine-practice progression, difficulty, audio mix, save library, isolated replay, conversation history and accessibility controls implemented.
- Presentation: character keepsakes and speaking/listening performances, 335 generated exact-text voice clips, seven story motifs and an illustrated chapter atlas included in the second production package.
- Latest export: source `e04faa67c124`, build `story-20261003T105555Z-e04faa67c124`, packaged commit `f0cdc09`.
- Latest push/deployment: both authorized GitHub branches updated; Vercel deployment `dpl_2VrkF1PdFeBzJUphz6UQoU8jYzuw` returned `status: ok`, `readyState: READY`, and alias `https://ashenoath.vercel.app`.
- Active work: `FINE_DETAILS_CYCLE_01_PLAN.md` is being implemented. The continuing goal remains active.

Production deployment: `dpl_9DKbrtv61oZVYfk5pQ6h5mXwkUiX`, `https://ashenoath-6yzh9ysh9-rafaeitahir-5792s-projects.vercel.app`. The initial CLI upload omitted `web` due to an overly broad ignore pattern; that filter was corrected, committed and pushed before the successful 82.5 MB upload. No post-deployment request, browser session, test or gameplay verification was performed.

## Interrupted-build recovery

Vercel was linked to the existing `rafaeitahir-5792s-projects/ashenoath` project after device authentication. Six compiler-reported type declarations were made explicit. The original asset downloader had omitted model companion files: 675 existing-source companions were restored, and 934 author-local texture references were normalized in 244 restored materials. The downloader now retains `.bin` and `.mtl`. An optional legacy `Chest_Wood.mtl` could not be recovered because its original archive URL returns 404; production import and export completed without it. Build execution now inhibits automatic system sleep for its own duration and releases that request on exit.

## Release limits

No tests, QA, gameplay sessions, screenshots, performance measurements, verification or review pass were run, as requested. Compilation/export diagnostics are handled only to produce deployable artifacts. The first release presented revised dialogue through subtitles and suppressed stale recordings. The subsequent package adds generated exact-text voices; neither vocal performance nor the final game has been reviewed. Runtime asset reuse and new staging do not constitute a replacement of every asset. Localization preparation is implemented for English; translated languages and measured playtime or quality targets are not claimed.

## Continuing story package

Implementation added after the first production release:

- Environmental encounter actions: Bell-Eater shelter rhythm and named rope, Rootbound root redirection and testimony recovery, Ashwing sluice/worker escort/records/perch, protected Halvern surrender, and Senn's evidence-or-relief stand-down.
- Physical story work: carried grain, household deliveries, drainage repair, mill aid, discovered wayposts and Vargan shortcut. Each covenant has three return activities; individual epilogues follow that return.
- Six named manual saves, import/export with recoverable replacement backups, protected decision checkpoints, isolated chapter replay and persistent conversation history.
- Subtitle size/opacity/speaker labels, block and sprint toggles, bounded targeting assistance and reduced-flash effects.
- Ten character presentation profiles with keepsakes and speaking/listening performances; seven original generated musical motifs with dialogue ducking.
- Newly synthesized dialogue tied to exact speaker/text hashes, retained voice-model attribution, and generated illustrated chapter headers.
- English source catalog/glossary and downloadable local problem reports. Production export includes the catalog, chapter atlas, motif manifest and external audio resources.

Production import, all seven runtime packs and the Web export completed for source revision `e04faa67c124`, build `story-20261003T105555Z-e04faa67c124`, candidate `.release-gate/story-complete-02`. The initial import reported two dynamic boolean inference errors; explicit declarations addressed those compiler diagnostics. There are 335 exact-text generated voice clips in the active manifest. Push and production deployment follow this packaged candidate. This records implementation and packaging, not test or quality certification. After publication, the next fine-detail cycle starts with a written plan before code changes.

Published package commit `f0cdc09` to both GitHub branches. Vercel reported `READY` for deployment `dpl_2VrkF1PdFeBzJUphz6UQoU8jYzuw`, URL `https://ashenoath-cqcz80kq6-rafaeitahir-5792s-projects.vercel.app`, aliased to `https://ashenoath.vercel.app`. The deployment uploaded 85.9 MB and exited successfully. No post-deployment verification was run. Continuous work remains active; next cycle is planning fine interaction, HUD, menu and browser-entry details.

## Fine details cycle 01

The written plan `FINE_DETAILS_CYCLE_01_PLAN.md` was created before implementation. Source changes now include bounded menu navigation memory, restored journal/shop focus and scroll, retained save drafts, local save-operation feedback, preserved dialogue History position and voice pause, readable wrapped controls, prioritized notices, structured binding-aware prompts, stable interaction selection, explicit availability and input release barriers. Browser startup has quieter presentation, optional Crow Flight, truthful download/preparation stages, focused recovery actions and foreground input handoff. New-journey metadata is initialized only at the accepted world handoff. Production packaging follows; continuous work remains active.
