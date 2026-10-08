# LR-012 - Resting Places

Status: implemented_local_awaiting_user. Source only. Combined packaging and
publication are deferred to LR-028; the existing Web artifact is unchanged.

## Implemented

- Greyfen's existing shrine bench, Wychwood's southern deadfall and the Long Road
  supply cart offer a half-hour rest, existing Preparation inventory, or departure.
  No additional obstruction, imported prop or survival system is introduced.
- A stationary four-second interval after sheathing commits the rest. Movement,
  pause, focus loss, death, injury, drawing a weapon, danger or a journey handoff
  cancels it. Action selections retain the actual area instance, not stale focus.
- Completed rests advance the existing day/night authority by thirty game minutes
  with day rollover and normal clock signals. Time-locked story states refuse rest.
- Recovery is capped to current configured stamina only. Health, difficulty,
  ingredients, food, ammunition and quest requirements are unchanged. Cancellation
  grants no rest bonus; ordinary world time and natural stamina regeneration continue.
- Additive StoryState flags save `last_rest` (place, zone, day, time, event) and
  once-only nearby friend reactions. A present rescued Bracken can remember rest
  after testimony. Remote or absent companions/speakers are not fabricated.
- The in-progress interval is transient; a resumed save cannot finish or award an
  abandoned interval. Existing checkpoint/autosave captures completed clock/state.

## Files And Static Review

`scripts/story_activity_director.gd`, `scripts/game.gd`, PROJECT_STATE and the
Living Road ticket/status/result records. Reviewed live area ownership, existing
equipment API, spatial checks, clock/stamina interfaces, cancellation boundaries
and diff. No tests, compiler, application, browser or captures were run.

## Unverified

UNVERIFIED - REQUIRES USER TESTING: actual rest reachability, time/schedule
presentation, preparation focus, interruptions and save round trips. Source
compilation is deferred to the combined build. No runtime acceptance claimed.

## Manual Test Checklist

1. Rest, prepare and leave at the shrine bench, southern Wychwood log and Long
   Road cart. Finish one rest, cancel another by walking or pausing, and compare
   clock, stamina and unchanged supplies.
2. Repeat before/after reporting testimony and with/without Bracken. Attempt a
   rest near danger, then move to safety. Check control and normal routes remain.
3. Save/Continue after completion and during an interrupted attempt; check time,
   actors, companion and objective without duplicated supplies or free recovery.
