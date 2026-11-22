# STORY-001 - Main Decision Alternatives

2026-09-28. Native partial acceptance only; STORY-001 remains pending.

## Completed Evidence

Eight decisions and eight separate normal Continue/manual-save round trips
pass graphical native execution with actual keyboard movement, focus, E,
visible dialogue choice and pause-menu Save. Every owned process exits 0;
no parser, resource, renderer or shutdown error is present.

| Group | Decisions | Evidence directory under D:/Temp/AshenOath |
| --- | --- | --- |
| Miller | burned, exposed | story_main_choices_20260928 |
| Senn | exile, punished | story_main_choices_20260928 |
| Halvern | released, destroyed | story_main_choices_20260928 |
| Assembly | kael, edric | story_assembly_choices_v2_20260928 |

Each decision uses an unchanged byte-copy of its genuine pre-choice save:
`ashwing_v5_fixture` autosave backup, `senn_fight_v3_fixture` autosave backup,
`halvern_choice_v1_fixture` manual backup and `assembly_choice_v4_fixture`
manual backup. Reloads use the actual preceding pause-menu save. Wrappers
validate prerequisite objectives, source SHA-256, original preservation,
120-second owned-process limits, exit and stderr. No flags, damage, position
or interaction handler is manipulated by the test.

Halvern verifies exact boss outcome, reward and aftermath, not only the
dialogue flag. Assembly verifies the real newly published Hart gate can be
approached immediately after the decision without reload.

## Repaired Harness Route

The first assembly Kael attempt correctly fails on a physical reading table:
center (8, 0.5, -3.5), size (2.4, 1, 1.1), west edge x=6.8. The old x>6.3
route settles at x=6.78 and clips it with the player's capsule. The source
and recorded shape agree. The corrected route uses the existing aisle at
x>5.5, preserving the 6500/6000 ms bounds, table and all gameplay geometry.
The passing route is x=5.81/5.98 before moving north. Both assembly decisions
and reloads then pass. The failed original log remains preserved; no collider
was removed to obtain a pass and no deadline was enlarged.

## Limits

This is resumed native branch evidence, not an uninterrupted campaign,
every combined permutation, final NPC staging, screenshot, browser or FPS
acceptance. Measured choice activation is 1438.1-4782.6 ms and reload is
484.5-3334.1 ms; cache conditions are repeat, not controlled cold benchmarks.
These timings retain the transition blocker. No new Web export is allowed
while native PERF remains red.

Game, dialogue and save-manager hashes remain those in
STORY_001_EDRIC_CHOICES_RESULT.md. Current route SHA-256:
`e7b2e412cc4eeaaa294a160d1dc4a4a41850d6b7368d68d3374e498756d06620`;
alternative driver:
`b02111043dec91b3492de991b95683be678ab817cf56476084be157b64aa85b1`.
The assembly-only correction follows the Miller/Senn/Halvern tests; their
movement helper and decision dependencies did not change.

## Running Steps

Open the D: Godot project. Continue a genuine checkpoint immediately before
one of these decisions, approach its speaker/object, press E and select the
named option. Save using Pause, Continue and confirm the recorded outcome
and next quest. Assembly's clear route is between the central tables and the
east witness record, not through the record table.

Exact isolated wrappers and logs remain in the evidence directories. They
refuse to overwrite runs. Remaining native choices are shrine, memory core,
recovered names and ledger, followed by combined/continuous route proof.
Formal 27/37 unchanged. No commit, push, merge, export or deployment.
