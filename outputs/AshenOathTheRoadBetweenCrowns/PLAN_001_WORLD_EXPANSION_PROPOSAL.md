# PLAN-001 World Expansion Proposal

## Current State

Ashen Oath currently ships a browser-first Greyfen to Wychwood slice: meet Sister Anwen, investigate the Road of Crows, defeat the first Ghoulkin, and return to report. Existing systems already cover quests, dialogue, interactions, combat, enemy AI, saves, procedural audio, Web/Potato settings, material safety, screenshots, and slim Vercel deployment.

The project remains low-poly, WebGL-sensitive, and heavily orchestrated by `game.gd`. Expansion must stay modular, bounded, and small enough for the Dell 7280 target.

## Recommended Next Section

Build **Greyfen Cemetery and the Ruined Crow Chapel** as the next playable section. It is a compact dusk investigation space with a grave court, ruined chapel, sealed ossuary, bell omen, clue chain, one Ghoulkin ambush, a Crow Shrine consequence, and a return to Sister Anwen.

Intended flow:

`Greyfen report -> cemetery bell -> disturbed graves -> changing clues -> Ghoulkin ambush -> Crow Shrine choice -> report consequence -> next Road of Crows hook`

This section comes first because it reuses current systems and visual vocabulary, deepens Greyfen and Sister Anwen, provides a strong emotional transition, and avoids the asset and performance cost of a marsh, hamlet, or castle approach.

## Moving Parts

| Moving part | Player-facing effect | Implementation | Complexity | Risk | Milestone |
| --- | --- | --- | --- | --- | --- |
| Cemetery bell | Omen on approach; changes after combat | Timer and quest-state signal | Low | Repetition | Next |
| Relocating Anwen | Anwen stages at the cemetery gate | Existing NPC with fixed staging markers | Medium | Save duplication | Next |
| Grave clue chain | Clues react in any inspection order | Existing interactables and objective flags | Low | Deadlock | Next |
| Grave ambush | Existing Ghoulkin wakes after final clue | Dormant encounter trigger | Low | Unfair spawn | Next |
| Crow Shrine choice | Blessing or adverse consequence flag | Existing world state/dialogue actions | Medium | Save compatibility | Next |
| Chapel gate | Ossuary remains visibly sealed until earned | Existing blocked interaction | Low | Misleading prompt | Later |
| Grave mist hazard | Local traversal pressure | Small trigger and existing damage hooks | Medium | Readability | Later |
| Cemetery patrol | World feels less static | Reusable waypoint movement | Medium | CPU/pathing | Later |

## Small Gameplay Additions

- Order-independent clue chaining using existing quest objectives.
- One saved consequence flag for the Crow Shrine decision.
- One temporary shrine blessing through existing player components.
- Fixed-point NPC relocation rather than a general scheduling system.
- One dormant encounter using current Ghoulkin AI, leash, and combat balance.
- One post-combat clue state and one changed report response.

## Narrative Purpose

The cemetery turns Greyfen's fear into a place the player can enter and change. Sister Anwen becomes an active witness rather than a quest dispenser. The Road of Crows gains physical evidence beneath the chapel, while the player's shrine choice establishes whether they approach the old powers with restraint or expedience. The section ends with a playable hook toward the larger mystery rather than a lore dump.

## Technical Strategy

- Construct the section through `scripts/zones/cemetery_section.gd`, using a small `build(parent, context)` entry point.
- Keep managers, global signals, saving, combat, and transitions in their current owners.
- Keep the cemetery inside Greyfen for this milestone; do not add a loading zone.
- Reuse procedural roads, walls, graves, rubble, lighting, fog, and material fallbacks.
- Preserve the non-white material verifier and add explicit shell, collision, route, clue, encounter, and consequence checks as tickets land.
- Do not touch Ruins, Castle Vargan, inventory architecture, global combat balance, or the asset downloader.

## Alternatives Considered

- **Deeper Wychwood:** technically easy but visually and emotionally repeats the current forest route.
- **Old mill:** strong landmark, but requires bespoke machinery and animation to feel credible.
- **Marsh crossing:** adds useful variety, but water, terrain, fog transparency, and traversal are expensive on WebGL.
- **Abandoned hamlet:** reuses village pieces but duplicates Greyfen before its current story pays off.
- **Castle Vargan approach:** narratively important enough to require stronger assets and production scope than the next milestone can support.

## Tickets

| Ticket | Objective | Likely files | Success criteria | Complexity | Deploy |
| --- | --- | --- | --- | --- | --- |
| WORLD-001 | Cemetery shell | Zone helper, `game.gd`, visible verifier | Bounded, accessible, collision-safe landmark | Medium | Yes |
| WORLD-002 | Bell and moving environment | Zone helper, audio/game hooks | Restrained state-driven motion and bell | Low | Yes |
| NARR-001 | Bell Beneath Greyfen flow | Quest/dialogue data, game hooks | Order-independent investigation survives save/load | Medium | Yes |
| AI-001 | Grave ambush | Zone/game hooks, runtime verifier | Safe dormant Ghoulkin encounter | Low | Yes |
| GAME-001 | Crow Shrine consequence | Game/player/save hooks | Visible, saved blessing or adverse flag | Medium | Yes |
| UX-002 | Objective guidance | Existing HUD/quest text | Route completable without a map | Low | Yes |
| PERF-002 | Web acceptance | Verifiers/export tooling | Slim payload and stable Potato/Quality modes | Low | Yes |

## First Ticket

`WORLD-001` creates only the bounded environment, path, chapel landmark, sealed ossuary, staging markers, collision, and verifier coverage. Narrative, moving parts, combat, and consequences remain inactive until their own tickets.

## Context Discipline

Future tickets read `EXPANSION_CONTEXT_BRIEF.md`, this plan, and the active ticket only. They inspect likely files, avoid broad audits and asset scans, build one ticket at a time, use hard acceptance criteria, and deploy implementation tickets only. Visible work requires screenshots and visible-quality checks.
