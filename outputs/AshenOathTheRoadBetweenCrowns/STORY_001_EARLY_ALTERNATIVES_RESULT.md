# STORY-001 - Shrine, Core, Names and Ledger Alternatives

2026-09-28. Partial native evidence; formal acceptance remains 27/37.

## Completed

Seven actual decisions and seven separate Continue/manual-save round trips
pass graphical native execution, owned exit 0 and clean active/shutdown logs.
Real keyboard movement, resolved focus, E, visible dialogue and ordinary Save
are used. No teleport, damage injection, story mutation or direct handler call.

| Group | Additional decisions | Genuine pre-choice fixture |
| --- | --- | --- |
| Crow Shrine | disturbed, bound | chapel_pier_aligned autosave backup |
| Bog core | preserved, returned | bog_fixture autosave backup |
| Recovered names | withheld | names_choice_fixture autosave backup |
| Vargan ledger | hidden, copied | record_ledger_v1_fixture manual backup |

All fourteen runs and wrappers are under
`D:/Temp/AshenOath/story_early_choices_v2_20260928`. Source inputs were hashed
before each process and checked afterward. Genuine originals remain untouched;
Continue reads exact copied bytes and reloads read the actual preceding Save.
Ledger checks exclusive outcome flags and the real staged haunting. Bog checks
the refined-oil unlock and item reward. Shrine checks the next chapter handoff.

The first shrine attempt in `story_early_choices_20260928` failed: focus ID
alone did not establish interaction validity/cooldown readiness. Both dialogue
helpers now use the established shared readiness wait with its unchanged
three-second limit. No gameplay or collision was changed. The failed run is
preserved and is not accepted downstream evidence.

## Authored Consequences

`tools/verify_story_choice_save_evidence.gd` independently compares all seventeen
new main decisions and seventeen reloads against the authored dialogue actions
and real StoryState adjustment/clamping rules. It checks exact flags, all saved
trust/fear/debt values and awarded items. Current clean exit-0 proof:
`D:/Temp/AshenOath/story_choice_consequence_20260928/consequences_v3.log`.
This offline comparison supplements the graphical runs; it cannot replace them.
Earlier parser and JSON numeric-type comparison failures remain harness history.

## Identity And Limits

Frozen early-matrix route SHA-256:
`29f1c9118b3a9b4e4b826b04a8d5473a3a26debefdb1facc681dd42f90b9bc1a`.
Early-alternative driver:
`3f26d3e3de7b110c4972bece851eb0d54e1b42a27cf5d69a2736972ba9fdc548`.
Game/save/dialogue identities remain those in the Edric result document.
Per-run `*.sources.json` files bind the actual evidence, not future source edits.

Choice activation spans 308.4-1537.1 ms; separate reload spans 264.2-5365.3 ms.
These uncontrolled repeat-cache timings retain performance/transition blockers.
No cold-start, FPS, uninterrupted campaign, combined permutation, visible NPC
aftermath, screenshot, browser or full STORY acceptance is implied.

Remaining story work includes first-hour report/refusal/clue permutations,
choice-aware actor aftermath and continuous production-input campaign proof.
No Web export while native PERF is red; no Git/production mutation occurred.

## Running Steps

Open the D: Godot project and Continue a genuine checkpoint before the named
decision. Physically approach, press E, select the named visible option and
Save from Pause. Reopen, Continue and confirm the outcome, reward and next beat.
The isolated `run.ps1` and `matrix.ps1` wrappers in the evidence directory record
exact commands and refuse overwriting previous evidence.
