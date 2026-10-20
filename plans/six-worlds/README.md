# Six Worlds, One Unfinished Oath

Date: 2026-10-19. Workspace: `D:\Projects\AshenOath`. Branch: `codex/masterpiece-rebuild`.

## Delivery State

The story package has now entered authorized build-only implementation.
Current authored runtime: 21 retained quests plus 30 additive regional quests, 51 total.
See [the current implementation record](IMPLEMENTATION.md) for coverage, build
status, compatibility details and the deferred oil-duration effect. Compilation,
publication and user acceptance remain separate from code implementation.

Start with [WORLD-SAGA-000](WORLD-SAGA-000.md), then the active world and quest card.
The [research appendix](RESEARCH.md) records sources, adaptations and research limits.
All common lifecycle, reward and acceptance rules in the master apply to every card.

Static authoring review on 2026-10-19: 37 authored tickets, 30 distinct new
runtime quest IDs (none reuses an existing ID), 18 secrets and six settled-return
milestones. Internal document links and whitespace were checked. Planned new
quest/secret/return XP totals 12,600, plus the separately specified encounter
promotions. This is document consistency evidence, not gameplay or balance acceptance.

| Ticket | World | Quest subtickets | Documentation | Runtime / compilation / deployment / user acceptance |
| --- | --- | --- | --- | --- |
| WORLD-SAGA-000 | Shared campaign and progression | Six world tickets below | Authored | Implemented / compiled / publication authorized (receipt records outcome) / user pending |
| [WORLD-SAGA-101](worlds/WORLD-SAGA-101.md) | Greyfen | [GRE-Q01](quests/GRE-Q01.md), [GRE-Q02](quests/GRE-Q02.md), [GRE-Q03](quests/GRE-Q03.md), [GRE-Q04](quests/GRE-Q04.md), [GRE-Q05](quests/GRE-Q05.md) | Authored | Implemented; [current delivery](IMPLEMENTATION.md); user pending |
| [WORLD-SAGA-102](worlds/WORLD-SAGA-102.md) | Wychwood | [WYC-Q01](quests/WYC-Q01.md), [WYC-Q02](quests/WYC-Q02.md), [WYC-Q03](quests/WYC-Q03.md), [WYC-Q04](quests/WYC-Q04.md), [WYC-Q05](quests/WYC-Q05.md) | Authored | Implemented; [current delivery](IMPLEMENTATION.md); user pending |
| [WORLD-SAGA-103](worlds/WORLD-SAGA-103.md) | Deep Woods and the Mill | [DEP-Q01](quests/DEP-Q01.md), [DEP-Q02](quests/DEP-Q02.md), [DEP-Q03](quests/DEP-Q03.md), [DEP-Q04](quests/DEP-Q04.md), [DEP-Q05](quests/DEP-Q05.md) | Authored; timed-oil follow-up approved | Content and oil effect implemented; [current delivery](IMPLEMENTATION.md); verification/user pending |
| [WORLD-SAGA-104](worlds/WORLD-SAGA-104.md) | The Long Road | [ROA-Q01](quests/ROA-Q01.md), [ROA-Q02](quests/ROA-Q02.md), [ROA-Q03](quests/ROA-Q03.md), [ROA-Q04](quests/ROA-Q04.md), [ROA-Q05](quests/ROA-Q05.md) | Authored | Implemented; [current delivery](IMPLEMENTATION.md); user pending |
| [WORLD-SAGA-105](worlds/WORLD-SAGA-105.md) | Castle Vargan | [VAR-Q01](quests/VAR-Q01.md), [VAR-Q02](quests/VAR-Q02.md), [VAR-Q03](quests/VAR-Q03.md), [VAR-Q04](quests/VAR-Q04.md), [VAR-Q05](quests/VAR-Q05.md) | Authored | Implemented; [current delivery](IMPLEMENTATION.md); user pending |
| [WORLD-SAGA-106](worlds/WORLD-SAGA-106.md) | The Hartlands | [HAR-Q01](quests/HAR-Q01.md), [HAR-Q02](quests/HAR-Q02.md), [HAR-Q03](quests/HAR-Q03.md), [HAR-Q04](quests/HAR-Q04.md), [HAR-Q05](quests/HAR-Q05.md) | Authored | Implemented; [current delivery](IMPLEMENTATION.md); user pending |

## Work Order

1. Master shared prerequisites: additive save/quest bindings, progression extension and unique reward ownership.
2. Greyfen, Wychwood, Deep Woods, Long Road, Castle Vargan, then Hartlands.
3. Within a world: cast/locations, Q01-Q04, capstone integration, Q05 aftermath, secrets/reward/return.
4. Integrate all four endings and the retained homecoming. Independent quests remain available after the ending.

This order is for development, not a new mandatory player checklist. Existing main-quest
gates remain authoritative. No new side quest or collection of secrets blocks the old campaign.
The Deep Woods oil decision is now resolved; follow [FINISH-017](../finish-line/FINISH-017.md)
for the approved timed-oil implementation and pending verification.

## User Review Checklist

- Confirm the six local stories and 30 new quest cards fit the intended tone.
- Review secrets, proposed numerical rewards and character motivations before implementation.
- During later implementation, use each ticket's manual scenarios; no runtime result is claimed here.

## Boundaries

Preserve the cumulative worktree, existing 21 quest IDs, A-set people, Ranger Senn,
the actual White Hart, two swords/bow, Bracken, relationships and activities.
This package does not reopen Recovery-004, replace existing planning records or change production.
New plot details are proposed expansion canon; existing saved outcomes always take precedence.
