# LR-018 - Vale Before Vargan

Source-implemented locally, 2026-10-08. Not published or user-accepted.

Greyfen's existing noticeboard offers Vale's letter only during known erased-name
investigation. Reading and replying are separately saved; a journal correspondence
entry preserves the record without treating it as testimony or Castle access.
At the actual Record Hall keeper, Kael can respect, question or decline a living
witness's private leaf. Later direct acquaintance offers friendship, interest or
refusal. Existing ledger/evidence choices are untouched, and no romantic state is
inferred from reading, help, prior saves or letters.

Files: `scripts/story_activity_director.gd`, `scripts/story_scene_direction.gd`,
`scripts/story_journal_model.gd`, `data/interaction_scenes.json`, ticket/status docs.
New flags: `lr_vale_letter_read`, `lr_vale_letter_reply`, `lr_vale_archive`,
`lr_vale_personal`. No new actor, resource, currency, voice or access gate.

Static source review only; no tests, captures, game launch or export.
UNVERIFIED - REQUIRES USER TESTING: correspondence flow, actual actor staging,
conversation framing, existing ledger access and save persistence.

## Manual Test Checklist

1. During erased-name investigation, read/reply or decline at Greyfen's noticeboard.
2. Reach Vale normally, handle or decline the private leaf, then choose a personal response.
3. Save/Continue; inspect correspondence and keep using the normal archive/story choices.
