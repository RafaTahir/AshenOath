# STORY-001 - Edric Alternative Decisions

2026-09-28. Partial native evidence, not whole-ticket or release acceptance.

## Result

Both visible decisions, `Expose him now` and `Compel a confession`, pass
physical approach, focused E, dialogue pagination/keyboard selection,
Blood Under Stone completion, Last Witness activation and real pause-menu
manual save. Separate normal Continue runs preserve each decision and pass
a second manual save. All four owned processes exit 0 without active or
shutdown errors.

Evidence: `D:/Temp/AshenOath/story_edric_choices_20260928/`:
`exposed.log`, `compelled.log`, `exposed-reload.log`, `compelled-reload.log`
and their stderr files. Wrapper and reload fixture are retained there.
The original `edric_exposed_v2_fixture` genuine pre-choice save is copied
unchanged; no JSON state editing, teleport or direct handler call occurs.

The north aisle uses real sprint input within the unchanged eight-second
deadline. This proves the sprint route, not the earlier failing walking
route or a performance fix. Record Hall activation is 1522.4/1467.3 ms in
choice runs, exceeding the cold transition limit. Reloads are 509.8/695.9 ms;
cache conditions are repeat, not cold. No FPS, browser, uninterrupted full
campaign or screenshot acceptance is claimed.

## Source Identity

- Branch: `codex/masterpiece-rebuild`
- HEAD: `5b530361a5aae8612626532287b5bd27d7b244b8`
- Route SHA-256: `d37011cfc8792b845346407516bba8cbee4da19607142addaf62a49d73ccd5cd`
- Game SHA-256: `560d4f7966ebc383142e40639948770aafc53cfe59c81281bd2c72f42204f4c5`
- Dialogue SHA-256: `bfae72dde9c5b7cca85939b0913c6edfaa51ffedb7a7eadf2a173d265d90fdbb`
- Save manager SHA-256: `5894738dbf22dc17ea015d39b0f5d6d7ed5e30fc7c05070180f669e0e9ac0de3`

## Running Steps

Open the Godot project under `D:/Projects/AshenOath/outputs/AshenOathTheRoadBetweenCrowns`.
Load an unresolved Record Hall checkpoint after clearing the haunting,
approach Edric around the east side of the archive tables, interact, choose
either alternative and save through Pause. Continue and confirm the next
quest and decision remain intact.

Completed logs cannot be overwritten by the isolated wrapper. Reproduction
requires a new evidence directory, not a repeat performed to hunt for a pass.
No export, commit, push, merge or deployment occurred. Formal count stays 27/37.
