# LR-020 - Relationships Across the Cast

Source-implemented locally on 2026-10-08. No runtime acceptance or publication.

Both arcs read one active `lr_commitment_partner`. A second proposal presents
Kael's honest disclosure and the other person's boundary, without an acceptance
button or remote breakup. Kael can keep friendship or leave the conversation,
speak directly to his current partner, then return. Current terms and one-shot
answers are checked again when applying the choice; stale actions cannot overwrite
a commitment. Ended relationships retain history and cannot silently recommit.

Rook and Anwen respond only when Kael explicitly chooses to confide, after their
friendship moment. No global gossip flag or omniscient witness reaction is added.
The People journal distinguishes the active commitment from historical events.
No service, medicine, testimony or political consequence is granted by romance.

Files: `scripts/story_state.gd`, `scripts/story_activity_director.gd`,
`scripts/dialogue_manager.gd`, `scripts/story_journal_model.gd`,
`data/interaction_scenes.json`, ticket/status records.

Static source/diff review only. No tests, builds, browser/game launch or captures.
UNVERIFIED - REQUIRES USER TESTING: both commitment orders, honest endings, confidences,
stale dialogue cancellation, reload and unchanged services. No legacy partner is inferred.

## Manual Test Checklist

1. Commit to one partner and approach the other's proposal; check the disclosed boundary.
2. End the existing commitment in person, then return or choose friendship instead.
3. Confide in Rook/Anwen; Save/Continue and inspect one current partner plus history.
