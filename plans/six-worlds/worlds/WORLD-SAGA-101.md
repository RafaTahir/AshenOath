# WORLD-SAGA-101 - Greyfen: A Gate Left Open

Parent: [WORLD-SAGA-000](../WORLD-SAGA-000.md). Status: build-only implementation present; user acceptance pending.
Current compilation/publication details: [implementation record](../IMPLEMENTATION.md).
Region: `greyfen`. Places: village, river/bridge, shrine, cemetery/chapel, later Assembly.
Read the master's common save/reward/manual-acceptance rules with this ticket.

## People, Place And Dramatic Arc

Greyfen must be worth protecting before it is accused. Nessa bakes for neighbors
and worries that announcing a shortfall will cause hoarding. Jory maintains the
warning bell and would rather admit carelessness than have Anwen blamed for
every unexplained ring. Elna wants a usable home, not a permanent role as a widow.
Rook enjoys a game without turning every encounter into a confidence test.
Retain Anwen, Mira, Tor, Toma, Bracken, existing village routines and all optional relationships.

Introduce Nessa beside the common kitchen, Jory on the cleared chapel approach.
Give each a work/idle pose, a private rest position and pre/after lines. Do not
build a competing bakery shell across the existing market route. Use the current
houses and authored entrances for the repaired household and traveler shelter.

## Five New Quests

| ID | Story purpose | XP | Availability |
| --- | --- | --- | --- |
| [GRE-Q01](../quests/GRE-Q01.md) | The Baker's Last Sack: investigate present grain manipulation | 300 | First ordinary visit; no board prerequisite |
| [GRE-Q02](../quests/GRE-Q02.md) | The Apprentice's Bell: restore a reliable warning mechanism | 350 | Before or after Bell-Eater; repair never summons it |
| [GRE-Q03](../quests/GRE-Q03.md) | A Door Before Winter: repair an inhabited home with its owner | 250 | Elna available, or her written work order |
| [GRE-Q04](../quests/GRE-Q04.md) | A Small Dishonesty: hear and settle a disputed wager | 300 | Rook/common-table access; no required win |
| [GRE-Q05](../quests/GRE-Q05.md) | A Gate Left Open: make sanctuary practical after the bell | 500 | Existing Bell-Eater/legacy shrine retirement resolved |

The Road of Crows, Bell Beneath Greyfen, all six Greyfen-linked side quests,
the Assembly and homecoming retain their own IDs and completion paths. New grain
investigation is not the existing flour delivery; the door repair is not Tor's
friendship hinge task. Jory's work does not substitute for investigating graves.

## Artifacts And Secrets

- [ ] GRE-S01, bell-founder's compartment. Three cast notches are visible on the
  counterweight; after GRE-Q02's inspection, turn the maintenance catch to align
  them. Contents: founder's maintenance sketch (lore), one iron trap, 100 XP.
  Read the sketch again without loot; maintenance access remains after the boss.
- [ ] GRE-S02, well-side savings cache. A worn bucket drawing on a loose bank stone
  points to a dry sleeve outside the actual well water. Align the carved bucket
  handle and inspect. Contents: bread stamp (lore), two travel bread, 100 XP.
  Cache belongs to a defunct mutual-aid fund; no stealing an NPC's required supplies.
- [ ] GRE-S03, unfinished household letter. GRE-Q03's owner offers a private letter
  after accepting the repair. Decline reading or read with consent; either can
  complete the discovery by acknowledging its sealed destination. Contents:
  attributed household history and 100 XP, no combat buff for violating privacy.

Secret records/claims use the exact S IDs. None unlocks the chapel or supplies
the only copy of a victim's name. Record letters, sketches and stamps as lore,
not inventory weapons or magical consent.

## Capstone: Bell-Eater

- [ ] Retain approved body, `bell_eater`, cemetery checkpoint, rewards and saved defeat.
- [ ] Cause: names tied down by burial rites; the clapper pulls toward the graves.
  Arena stays on the existing clear cemetery approach, not inside the chapel shell.
- [ ] Harnessed/Unchained/Hollow Bell use existing 100/66/33-percent phase boundaries:
  raised clapper before rings, visible chain sweep arc, ground-marked grave slam;
  cap and retire summons with the existing encounter owner. Graves/rope remain
  optional clue counterplay, not secret required damage gates.
- [ ] Combat is required on fresh saves. No noncombat shortcut through Jory's bell.
  Checkpoint restores phase/outcome correctly and never resets recorded supplies.
- [ ] Defeat retires attacks, restores bystanders and permits the existing shrine decision.

## Reward And Return

- [ ] `saga_bellkeeper_clasp`: Bellkeeper's Clasp, guard-hit stamina cost x0.90
  (current 12 becomes 10.8), no change to the 10-stamina parry cost/window.
  Fit via existing ownership; do not attach an unvalidated chest primitive.
- [ ] Item and permanent perk granted once for the legitimate capstone entitlement,
  independent of Q01-Q04 and the chosen shrine fate. Retain 400 existing boss XP.
- [ ] After GRE-Q05, returning from another sector to the shelter anchor grants
  `return:saga_gre_settled` (100 XP). Show a genuinely used shelter and Jory's
  functioning warning line; later Assembly/homecoming dressing coexists.

## User Manual Checklist After Implementation

1. Begin in a fresh and an advanced journey; find all hooks without replaying original quests.
2. Choose each grain/wager/repair route; decline a personal invitation without penalty.
3. Interrupt repairs, reload, resolve Bell-Eater and inspect shrine/bystander state.
4. Claim all three secrets and the clasp twice; XP/items must remain once-only.
5. Return after Q05 and later after the Assembly/finale; original homecoming remains available.
