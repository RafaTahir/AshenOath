# LR-011 - Tracking and Wildlife

Status: implemented_local_awaiting_user. Source only; combined build/publication
deferred to LR-028. The existing generated LR-009 Web artifact is unchanged.

## Implemented

- Three authored scent reactions use the existing Wychwood cart, scratched token
  and drag-mark clue actors. Bracken pauses, sniffs with his native neck/head,
  turns toward the actual nearby trail and waits briefly. He does not run to a
  remote objective or collect anything for Kael.
- Actual proximity, same-bank location, clear sightline, clue availability and
  current quest state govern reactions. Sprinting, dialogue, care and danger
  suppress or cancel them. Scanning is bounded, with an 18-second reaction cooldown.
- `bracken_scent_seen` persists only which authored reactions were shown. No
  evidence/objective flags are written by sniffing. Normal clue interaction,
  all five clues, route geometry, enemy staging and unaccompanied play are intact.
- Existing Greyfen crow silhouettes now react to slow approach, running/combat
  noise and the nearby hound. They move away and rise, then return gradually after
  the disturbance leaves. Their existing wings flap with flight. Other objects
  tagged as bird-like motion (motes or decorative markers) are not wildlife.
- Wildlife remains noncolliding environmental life, without loot, hunting,
  companion requirement or any quest mutation.

## Files And Review

`scripts/companion_controller.gd`, `scripts/world_motion_controller.gd`,
`scripts/game.gd`, and the project/ticket/result records. Native scent pose reuses
LR-010's modifier. Static review covered concrete existing clue IDs, quest checks,
weak-reference lifetime, cooldowns, bank/occlusion boundaries and wildlife-only
metadata. No game, compiler, browser, screenshot or QA run was launched.

## Unverified

UNVERIFIED - REQUIRES USER TESTING: sightlines, animation, perceptibility of hints,
wildlife reactions and interruption behavior. Final compilation is deferred with
the combined artifact. No runtime acceptance or visual approval is claimed.

## Manual Test Checklist

1. Bring Bracken to the Wychwood cart/token/drag marks. Follow a reaction, then
   inspect the clue yourself; sniffing alone must not earn evidence.
2. Reload or return after investigating, and repeat the route without adopting
   him. Check that clues and story progression do not depend on the companion.
3. Sprint, converse or enter combat near a scent. Check that he stops hinting.
   Approach the Greyfen crows quietly, then run or bring Bracken closer; observe
   their departure and gradual return without route obstruction.
