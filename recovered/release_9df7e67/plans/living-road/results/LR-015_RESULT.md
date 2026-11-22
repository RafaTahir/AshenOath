# LR-015 - Friends in Greyfen

Implemented locally on 2026-10-08. Not published or user-accepted.

## Changes

- Optional Rook stool, Tor hinge and post-report Anwen shrine work uses existing
  prop locations, a short interruptible hand gesture and authored conversations.
- Each invitation can be declined without losing games, shops, testimony or quest
  access. Completed work is saved separately from the follow-up exchange.
- Anwen permits encouragement, disagreement or silence without changing existing
  trust, witness consent or report choices. Later acknowledgement uses LR-014's ledger.
- Accepted work appears in existing started-work guidance. No rewards, new currency,
  farmable relationship points, geometry, remote NPC teleports or replacement actors.

## Files

`scripts/story_activity_director.gd`, `scripts/game.gd`,
`scripts/story_scene_direction.gd`, `data/interaction_scenes.json`, ticket/status records.

## Persistence And Limitations

`lr_friend_rook_stool`, `lr_friend_tor_hinge`, `lr_friend_anwen_shrine` and unique
relationship event IDs are additive StoryState flags. Incomplete timed work cancels
on movement, combat, menus, focus loss or departure without completing the task.
The existing prop is used; no moving stool/hinge submesh is claimed.

Static source/diff review only. No tests, game launch, captures or export.
UNVERIFIED - REQUIRES USER TESTING: work positioning, gesture fit, interruption,
saved state, services and dialogue framing. The LR-009 local artifact excludes this ticket.
One combined build/publication follows LR-028.

## Manual Test Checklist

1. Help or decline Rook and Tor; use their usual game/shop afterward.
2. After reporting, help Anwen and choose disagreement or silence; revisit her.
3. Interrupt work, reload before/after completion, and resume the follow-up exchange.
