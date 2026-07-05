# Ashen Oath Story Implementation Context Brief

## Direction

Ashen Oath is an 8-12 hour dark-fantasy action RPG about broken promises, denied witnesses, and inherited guilt. Writing is restrained, playable, and human. The Witcher 3 is a quest-design benchmark only; do not copy its IP.

## Main Mystery

House Vargan promised sanctuary during the War of Three Crowns. Greyfen barred its gate, the shrine hid the road through a White Hart covenant, and Vargan soldiers killed those trapped between them. Bodies were burned without names; their ash and iron built modern Greyfen. The bound Hart is the only complete witness. Ghoulkin are bodies animated by fragments of erased memory.

## Protagonist

Kael is a defined but steerable oath-bound hunter. He once obeyed a retreat order that abandoned civilians. His four possible orientations are Witness, Mercy, Duty, and Ash. He speaks concretely and avoids theatrical toughness.

## Current Playable Spine

Greyfen -> Sister Anwen -> Wychwood clues -> five-enemy Ghoulkin clearing -> aftermath -> Greyfen report. The next section is the cemetery and Ruined Crow Chapel.

## Existing Cast

Anwen, Mira, Rook, Edric, Elna, Tor, Toma, White Hart, villagers. Use existing enemies: Ghoulkin pack, Bog Wretch, Gravebound Knight, Bandit, Hart Avatar.

## Choice Rules

- Explicit major flags plus `anwen_trust`, `greyfen_fear`, and `hart_debt`.
- No generalized branching engine.
- Every quest changes a relationship, encounter, preparation, or place.
- Investigation changes combat but missing optional clues never blocks progression.
- Every major quest includes aftermath and reporting.
- Final endings remain explicit choices, not hidden score results.

## Human Voice Rules

- One to three sentences per ordinary turn.
- Use objections, corrections, remembered details, and silence instead of exposition.
- Anwen self-edits; Mira speaks clinically; Rook jokes when afraid; Edric becomes plain when control fails.
- Voice main-path and payoff lines first. Subtitles remain authoritative.
- Scratch/generated speech requires human review and is not automatically final.

## Main Quest Order

1. Road of Crows
2. Bell Beneath Greyfen
3. Teeth in the Rain
4. The Names They Burned
5. Ash at the Mill
6. A Soldier Without a Banner
7. Blood Under Stone
8. The Last Witness
9. Crowns Without Mercy
10. The Hart Remembers

## Immediate Ticket Order

`NARR-003 -> QUEST-001 -> DIALOGUE-001 -> CHOICE-001 -> WORLD-001 -> NPC-001 -> ENEMY-002 -> WORLD-002 -> AUDIO-003 -> CINEMATIC-001 -> SAVE-002 -> QA-001`

## Technical Constraints

Reuse objective progression, dialogue actions, world flags, inventory/crafting, NPC staging, enemy spawn/leash, audio, save/load, and cemetery helper. Keep the Web build and Potato Mode safe. Add only small legal assets when a procedural or existing asset cannot carry the story.

## Credit-Saving Instruction

Future Codex tasks read this brief, the active ticket, and only the directly relevant design document. Do not scan the repository, reread historical phase files, or load the full asset manifest unless the ticket requires it.

## Deployment Instruction

Planning-only tickets do not deploy. Implementation tickets follow the repository workflow unless the user explicitly writes `DO NOT DEPLOY`. STORY-ARCH-001 itself is documentation-only and must not be exported, committed, pushed, or deployed.
