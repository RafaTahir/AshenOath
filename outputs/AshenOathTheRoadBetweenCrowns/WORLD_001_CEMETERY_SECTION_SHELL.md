# WORLD-001 Cemetery Section Shell

## Objective

Create the bounded, accessible shell for Greyfen Cemetery and the Ruined Crow Chapel without activating narrative, combat, or consequence systems.

## Implemented

- Modular `cemetery_section.gd` builder integrated into Greyfen.
- Clear west-entry approach and grave-court floor.
- Three-sided cemetery boundary with gate posts.
- Ruined chapel silhouette, altar, and sealed ossuary door.
- Four grave plots, rubble dressing, restrained fog, and chapel glow.
- Named staging markers for the entrance, Sister Anwen, encounter, and Crow Shrine.
- Visible verifier checks for required landmarks, accessible entry staging, and chapel collision.

## Deferred

Bell behavior, Anwen relocation, clue logic, Ghoulkin ambush, shrine choice, dialogue, quest updates, and new audio remain deferred to their dedicated tickets.

## Acceptance

- Greyfen and the existing first route remain playable.
- Cemetery shell is visible and reachable without a new loading zone.
- Chapel and perimeter use collision.
- No new quest, combat, enemy, or active interaction is introduced.
- Runtime and visible-quality verifiers pass before deployment.
