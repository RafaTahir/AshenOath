# QUEST-002 — Teeth in the Rain

## Implemented
- Added Mira's one-time Moon Oil preparation and a persistent refined-formula reward.
- Added erased-name evidence inside the Crow Chapel.
- Gated Oren's ritual stones behind that evidence and deeper Wychwood behind the spoken name.
- Consolidated the Bog Wretch into one deeper-Wychwood encounter.
- Added three ways to expose its memory core: Moon Oil, Ash Bomb, or repeated heavy/parry staggers.
- Added destroy, preserve, and return consequences with story values and Act Two handoff.
- Migrated legacy active saves so the new chapel objective cannot block later progress.

## Verification
- `tools/verify_quest_002.gd` covers supply replay prevention, investigation order, encounter gating, core exposure, consequences, recipe mastery, Act Two handoff, and legacy migration.
- Registered the verifier in the authoritative release runner.
- Authoritative release gate: PASS.
- Graphical 720p performance: 35.0 FPS average, 34.7 FPS minimum, 178 ms warm transition.
- Web export and packed startup: PASS; seven files, 63.9 MB.

## Running
Open the current Web build, finish `Road of Crows` and `Bell Beneath Greyfen`, then speak to Mira in Greyfen. Read the names in the chapel, return to the Wychwood ritual stones, and enter deeper Wychwood.
