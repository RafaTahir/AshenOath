# WORLD-SAGA-103 - Deep Woods: A Roof Before Rain

Parent: [WORLD-SAGA-000](../WORLD-SAGA-000.md). Status: runtime content implemented; oil-duration effect deferred; user acceptance pending.
Current compilation/publication details: [implementation record](../IMPLEMENTATION.md).
Region: `deep_wood`. Sectors: deep_wood, old_mill, burned_farmstead.
Implementation/compilation/publication not performed; user acceptance pending.

## People And Regional Story

Dain is the named presentation of retained mill worker index 0: keep the existing
worker/escort identity and save keys, add a dialogue alias rather than another
body. He wants wages to mean something after the mill's past is exposed. Ressa,
a displaced farmstead resident, wants usable land and a home without being made
to defend the source of its old prosperity. Neither must approve Kael to eat.
Retain the other worker, Mira/Toma's roles, Rook's map, all register fragments,
the wage chest, escape channel, rescue, Rootbound and the existing mill decision.

Place Dain at the original worker staging until rescue, then the safe south yard;
use his work notebook before safe conversation is possible. Ressa works at the
cleared farmstead yard. Show tools/seed trays, not a second settlement blocking routes.

## Five New Quests

| ID | New story | XP | Dependencies |
| --- | --- | --- | --- |
| [DEP-Q01](../quests/DEP-Q01.md) | The Second Ledger: current freight diversion | 300 | Mill exterior reached; notebook hook before rescue |
| [DEP-Q02](../quests/DEP-Q02.md) | A Field Without Ash: prepare a clean plot | 350 | Ressa or her work plan found |
| [DEP-Q03](../quests/DEP-Q03.md) | The House That Kept Its Heat: recover a usable cellar | 250 | Farmstead reached |
| [DEP-Q04](../quests/DEP-Q04.md) | The Orchard's Debt: protect living stock | 300 | Farmstead/deep-wood orchard edge reached |
| [DEP-Q05](../quests/DEP-Q05.md) | A Roof Before Rain: rebuild or shelter the closed mill's work | 500 | Ashwing resolved and existing mill operation decided |

For a legacy completed mill chapter with no explicit `mill_operation`, allow
DEP-Q05's detached workshop only. Keep the historical operation unknown; do not
infer closure/supervision/restitution or demand that the player choose it again.

No new quest is a rename of the ash measure, worker escort, wage chest or protected
root name-board. Existing Names They Burned still crosses multiple regions.

## Artifacts And Secrets

- [ ] DEP-S01, farmstead root-cellar cache. Inside the cleared cellar, an exposed
  grain-stamp rubbing identifies a false-backed dry cupboard. Its sliding catch
  is reachable from the walkable room. Contents: household planting calendar,
  one travel bread in a current sealed relief jar, 100 XP. Ancient food is not edible loot.
- [ ] DEP-S02, millwright's maintenance compartment. Match the wheel's three
  service numbers to Dain's maintenance sketch and open the stopped ground-level
  access hatch from the yard. Contents: maintenance log, one iron trap, 100 XP.
  No swimming/climbing through the wheel or operating it while the player is inside.
- [ ] DEP-S03, orchard seed store. Follow small graft-mark notches to a covered
  stone bin outside the Rootbound arena. Contents: regional seed-history entry,
  two redroot ingredients, 100 XP; the quest's viable graft is a separate object.

Ressa's crock, freight book, seed history and planting calendar are lore/work
artifacts. None replaces the refugee register, mill ledger or guaranteed evidence.

## Major Encounters

- [ ] Rootbound remains the additional deliberate-challenge encounter in Deep Wood.
  Preserve root lanes, exposed heart, protected/damaged name-board and all saved outcomes.
- [ ] Ashwing remains `ashwing`, approved retained drake, mill arena and saved phases.
  Cause: burned testimony draws it to working channels; workers are not fuel or guilt tokens.
- [ ] Perched (100-66%): original wing blast with a readable raised-wing windup.
  Scorched (66-33%): original ash breath with a clear shoulder/cone preparation.
  Breaking Perch (below 33%): original swoop lane with explicit recovery.
  Retain hauling-rope counterplay and Oathfire interruption at the applicable
  existing windows; never overlap untelegraphed attacks or rename saved phases.
- [ ] Keep mill rescue, ventilation and wage preservation available before/after
  combat. No Q01-Q04 or secret required to fight. The old mill-record decision
  becomes available after the existing Ashwing defeat, not before it.
- [ ] Checkpoint at safe south-yard arrival; retain supplies, phase damage and
  recorded rescue progress, no automatic healing. Defeat retires all attack owners.

## Reward And Approved Blocker

- [ ] Ash-Tempered Blade Fitting (`saga_ash_tempered_fitting`) records the Ashwing
  entitlement and a forge provenance entry. Retain existing 500-XP Ashwing reward.
- [ ] Intended mechanical effect: blade-oil duration x1.20. BLOCKED: current oils
  never expire. On 2026-10-19 the user chose to defer this perk until a separate
  oil-system decision. Do not add a timer, substitute damage or claim it works.
  Documentation is complete with this dependency; full reward implementation is not.
- [ ] After DEP-Q05, later return to the workers' chosen dry work/supply station
  grants `return:saga_dep_settled` (100 XP). Closed/supervised/restitution states
  have different dressing but equivalent useful continuation and reward access.

## User Manual Checklist After Implementation

1. Use pre-rescue notes and post-rescue Dain without duplicate worker bodies.
2. Complete all three mill choices, Rootbound outcomes and distinct new orchard work.
3. Interrupt cellar/plot/roof work; reload without losing records or supplies.
4. Inspect all secrets and phased Ashwing saves; preserve original Mill/Names quests.
5. Confirm the duration perk stays explicitly blocked until separately approved and implemented.
