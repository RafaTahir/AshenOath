# Ashen Oath story overhaul execution ledger

Plan: C:/Users/User/Documents/Codex/AshenOath/plans/2026-10-03-ashen-oath-story-overhaul-master-plan.md

## Authorization

2026-10-03: User approved keeping the core identity with a major rewrite, then requested implementation, no testing or verification, followed by push and deployment. This explicitly replaces plan and skill test/review gates for this execution. Compilation/export remains necessary to create the release. No QA, smoke, browser, screenshot, lint or gameplay verification will run. Changed work is untested.

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
- World staging and aftermath: event-driven story compositions, voluntary witness staging, three peaceful covenant rituals, Ash confrontation, and return to Greyfen implemented.
- Player experience: journal, decision previews, individual epilogues, evidence-earned combat opportunities, supply consequences, emergency medicine, nine-practice progression, difficulty, audio mix, and focus-loss pause implemented.
- Export: completed production import, seven pack exports, Web export, runtime manifests and WASM transport compression from source commit 85a80d0. Final build identity: `story-20261003T101232Z-85a80d0794e2`.
- Push/deployment: published to GitHub `main` and `codex/story-centered-overhaul`. Production application commit: `55633a5` (game export commit: `4d18a11`). Vercel deployment command completed with `status: ok`, `readyState: READY`, and the production alias `https://ashenoath.vercel.app`.

Production deployment: `dpl_9DKbrtv61oZVYfk5pQ6h5mXwkUiX`, `https://ashenoath-6yzh9ysh9-rafaeitahir-5792s-projects.vercel.app`. The initial CLI upload omitted `web` due to an overly broad ignore pattern; that filter was corrected, committed and pushed before the successful 82.5 MB upload. No post-deployment request, browser session, test or gameplay verification was performed.

## Interrupted-build recovery

Vercel was linked to the existing `rafaeitahir-5792s-projects/ashenoath` project after device authentication. Six compiler-reported type declarations were made explicit. The original asset downloader had omitted model companion files: 675 existing-source companions were restored, and 934 author-local texture references were normalized in 244 restored materials. The downloader now retains `.bin` and `.mtl`. An optional legacy `Chest_Wood.mtl` could not be recovered because its original archive URL returns 404; production import and export completed without it. Build execution now inhibits automatic system sleep for its own duration and releases that request on exit.

## Release limits

No tests, QA, gameplay sessions, screenshots, performance measurements, verification or review pass were run, as requested. Compilation/export diagnostics are handled only to produce deployable artifacts. Standard combat values are preserved unless an explicitly discovered preparation opportunity applies. Revised dialogue is presented through subtitles: existing voice lines are suppressed until a matching performance is authored. Runtime asset reuse and new staging do not constitute a complete replacement of every art or audio asset. The longer art-production, localization, playtime and measured quality targets in the master plan are not claimed as achieved by this release.
