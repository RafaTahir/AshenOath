# QUEST-010 Result

## Changes
- Teeth, Names, and Ash retain deeper-Wychwood, register, mill, and boss hooks through the existing quest data and builders.
- Rootbound and Ashwing outcomes write explicit story flags used by later dressing.
- Names and mill story choices are now one-shot and remove their consumed dialogue
  interactions, preventing replayed consequences after a stale prompt or reload.
- Published/withheld names and preserved/burned/exposed mill records now leave
  visible aftermath dressing in Greyfen and at the old mill.

## Verification
- `verify_campaign_quests_008_012.gd`: PASS.
- `verify_world_015.gd`: PASS.
- `verify_quest_010.gd`: PASS for all 24 register-fragment permutations, choice
  contracts, runtime persistence, and one-shot consequence application.
