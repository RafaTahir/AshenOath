# GRE-Q02 - The Apprentice's Bell

Parent: [WORLD-SAGA-101](../worlds/WORLD-SAGA-101.md). Runtime ID: `saga_gre_q02`.
Status: build-only implementation present; user acceptance pending. See [current build/delivery record](../IMPLEMENTATION.md).
Type: optional, connected. XP: 350. Prerequisite: accessible Greyfen chapel approach.

## Hook And People

Jory discovers the village warning rope pulls a maintenance counterweight, not
the expected bell. He fears admitting a botched repair will make every supernatural
ring his fault. Anwen distinguishes a mechanical fault from the bound graves.
Jory: "A warning ought to mean something. Mine means pull harder."

## Playable Objectives

1. `inspect_mechanism`: examine rope wear and the three counterweight notches from
   the ground maintenance alcove. No ladder/climbing-system prerequisite.
2. `recover_pin`: take the dropped matching pin from the dry runoff basket nearby;
   the reflected metal/drag mark provides a daytime and subtitle-readable clue.
3. `seat_counterweight`: brake the weight, fit the pin, release the brake in that
   order using three explicit interactions. Wrong order safely resets only this step.
4. `agree_warning`: choose a posted rhythm guide signed by Jory, or a practical
   demonstration to the watch with his private maintenance log preserved.
5. `sound_trial`: ring the repaired warning once and hear/see the watch acknowledge it.

## Branches And Consequences

`posted`: the guide helps unfamiliar travelers; `demonstrated`: watchkeepers repeat
the rhythm and keep Jory's private notes. Both are reliable, honest repairs.
Learning the rhythm gives an optional early readability cue for Bell-Eater's
raised clapper; it neither harms the boss nor bypasses the graves/shrine chapter.
After boss defeat the trial is an ordinary bell, never a new encounter trigger.
Anwen: "A working bell is a kindness. It is not an explanation for what we buried."

## State, Rewards And Recovery

Save objectives, seated-pin state and `saga_gre_q02_outcome` (`posted`, `demonstrated`).
Reward: 350 XP and Jory's maintenance sketch lore entry; no duplicate secret XP.
The sketch makes GRE-S01's catch legible, but opening its compartment is a separate action.
Interrupted fitting restores safe brake/weight placement; no falling physics prop.
An unattended watch tally can acknowledge the trial if Jory is temporarily absent.
Do not confuse this mechanism with the retained boss rope-release counterplay.

## User Manual Checklist

Try the wrong fitting order, interrupt and reload, repair before/after the boss,
use either public/private route, and confirm no accidental boss spawn or chapel unlock.
