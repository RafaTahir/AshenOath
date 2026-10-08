# LR-023 - Bracken's Field Trial

Implemented locally. UNVERIFIED - REQUIRES USER TESTING. No build, launch, test,
commit, push or deployment was performed for this ticket.

The southern Greyfen road has an optional three-mark cedar-scent trail, untimed
practice and a ninety-second scored mode. Actual walking and each marker's normal
interaction are required in order. Bracken indicates direction using his existing
body and sniff pose, then follows through the retained collision-aware navigator.
His saved command is never replaced by activity state. Best scored time and one
completion acknowledgement persist; no clue, quest, inventory or recruitment grant.

Markers disappear on cancellation, menu/focus interruption, save, transition,
danger, departure or completion. Revisit the start to retry. Absent/unrecruited
Bracken leaves an explanatory invitation, never a progression lock.

Files: `bracken_field_trial.gd`, `companion_controller.gd`,
`story_activity_director.gd`, `game.gd`, `save_manager.gd`,
`zone_runtime_coordinator.gd`. Source reasoning only; physical placement and motion
remain for user acceptance. No new asset payload. Combined package deferred to LR-028.

Manual checklist: practice and timed run; inspect a later mark first; cancel,
pause, leave, save/reload and retry; confirm previous follow/wait command returns;
confirm investigations and the Black Dog Contract remain independent.
