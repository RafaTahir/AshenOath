# LR-014 - Promises and Boundaries

Status: implemented_local_awaiting_user. Source-only, awaiting the combined
LR-028 build/publication and the user's runtime acceptance.

## Implemented

- StoryState records stable, once-only relationship events in additive
  `living_road_relationships` flags: help, promise, kept/broken, refusal,
  friendship, interest, commitment and boundary are separate factual categories.
  No numeric affection, gift economy or competing Anwen trust value.
- Existing flour delivery, road repair and water delivery record specific help
  when those outcomes newly occur. Explicit witness refusals record boundaries.
  Repeating a greeting, purchase or unchanged flag grants no relationship event
  or additional trust. Existing legacy flags/decisions retain their meaning.
- Rook offers a direct privacy promise or honest refusal before his map outcome.
  A later public disclosure breaks that specific promise; keeping the mark
  private fulfills its privacy condition. Destroying the map also records the
  lost route: keeping secrecy is not treated as absolution or universal virtue.
- Dialogue acknowledges the recorded event; People & Promises displays the
  actual action and outcome, not inferred affection. The existing choice
  coordinator records authored relationship payloads only for applied choices.
- Legacy loads default to no new relationship ledger. No chronology, romance,
  promise or retrospective help event is manufactured. Existing journal facts
  continue to describe old saved outcomes.

## Files And Review

`scripts/story_state.gd`, `scripts/story_decision_coordinator.gd`,
`scripts/dialogue_manager.gd`, `scripts/story_journal_model.gd`, and the
project/status/ticket/result records. Static source/diff review only: additive
save ownership, one-shot choice conditions, event identity, transaction order
and existing dialogue/quest preservation. No test or application was run.

## Unverified

UNVERIFIED - REQUIRES USER TESTING: live dialogue choices/acknowledgements,
journal presentation and legacy/current Save/Continue. Compilation is deferred
to final packaging. No user acceptance is implied by source implementation.

## Manual Test Checklist

1. Speak/trade repeatedly with Rook, Tor and Anwen. Check that no extra memory,
   supplies or trust is awarded merely for repeating the interaction.
2. Promise Rook privacy, then choose a protected or public disclosure on your
   normal story route; revisit and inspect People & Promises. In another save,
   decline the promise and check that the game does not accuse you of breaking it.
3. Continue a legacy save and save/reload a new promise. Old choices must remain
   intact, with no invented romantic commitment or rewritten outcome.
