# WORLD-SAGA-104 - The Long Road: Passage Without Permission

Parent: [WORLD-SAGA-000](../WORLD-SAGA-000.md). Status: build-only implementation present; user acceptance pending.
Current compilation/publication details: [implementation record](../IMPLEMENTATION.md).
Region: `long_road`. Sectors: marsh_crossing and bandit_road.

## People And Regional Story

Nera maintains the crossing markers and wants travelers to know the cost before
they step onto a dangerous route. She once obeyed a closure instead of attempting
a rescue and does not want the player to turn that admission into absolution.
Tavin, a former quartermaster at the retained deserter camp, fears that a borrowed
uniform and false name are the only things keeping him safe. Senn retains his
Ranger body, current culpability, present raids and possible fates.

The road should feel used: marker maintenance, a resting cart, an orderly camp
and safe gathering shoulders. Add no new crossing through the main river.
The optional causeway remains inside the marsh's existing walkable-land policy.

## Five New Quests

| ID | New story | XP | Dependencies |
| --- | --- | --- | --- |
| [ROA-Q01](../quests/ROA-Q01.md) | Toll for the Living | 300 | Reach the crossing/checkpoint |
| [ROA-Q02](../quests/ROA-Q02.md) | The Crossing Keeper's Oath | 350 | Meet Nera or inspect the closure marker |
| [ROA-Q03](../quests/ROA-Q03.md) | Boots That Do Not Fit | 250 | Tavin's safe camp table accessible |
| [ROA-Q04](../quests/ROA-Q04.md) | Lights Across the Marsh | 300 | Read a fallen signal post |
| [ROA-Q05](../quests/ROA-Q05.md) | The Road Belongs to No One | 500 | Any existing settled Senn fate |

Preserve A Soldier Without a Banner, The Bannerless and the healer's register
fragment. A borrowed identity is a new personal dispute, not another deserter muster roll.

## Artifacts And Secrets

- [ ] ROA-S01, concealed causeway. Repeated triangular stake cuts visible by day
  and reflected at night identify a short walkable shoulder route. Lift its
  collapsed brush screen. Contents: route journal record, one travel bread,
  100 XP. It bypasses no locked main gate and does not permit river wading.
- [ ] ROA-S02, quartermaster's supply cache. A numbered empty crate matches the
  underside of a camp packing board; compare both and open a dry buried sleeve.
  Contents: three Bodkin arrows, an old packing tally (lore), 100 XP. It is
  abandoned surplus, not the supplies owed to Q01's living claimants.
- [ ] ROA-S03, unsent dispatch. Wax crumbs lead to a hollow marker cap. Read its
  delivery docket and recover a sealed copy. Contents: limited military-route
  history, 100 XP. This cannot replace Halvern's proof or Senn's signed account.

Each secret works without Nera/Tavin being present. Narrated observations have
subtitles; lantern color/audio alone is never the unlock condition.

## Capstone: Captain Senn

- [ ] Preserve `captain_senn`, the approved Ranger body, guards, surrender record,
  `senn_fate` values and established custody/exile/execution choices.
- [ ] Extend the existing encounter owner to a living-human Senn duel only while
  his fate and the original `senn_confrontation` are unresolved. A legacy completed
  confrontation still permits the existing fate dialogue without another duel.
  Do not load Halvern's body or substitute an undead enemy.
- [ ] Commanding Guard (100-60%): deliberate shield/weapon guard and a visible
  two-strike opening. Isolated Officer (below 60%): shorter forward press,
  telegraphed guard break and longer recovery. Translate guard break into the
  existing confrontation-complete state, not a mandatory death callback.
- [ ] Earned stand-down remains possible through the retained documented account
  and existing conditions; new toll evidence can add dialogue, not become its
  only prerequisite. Guards retire cleanly on surrender, and dialogue suspends combat.
- [ ] Checkpoint outside camp danger; retain recorded supplies and phase/guard
  state. Death restores the encounter but never overwrites an already settled fate.
- [ ] If Senn is already gone/dead, the camp account and Tavin carry aftermath;
  no resurrection, rematch or living oath fabricated from a written confession.

## Reward, Return And Checklist

- [ ] Roadwarden's Baldric (`saga_roadwarden_baldric`): sprint stamina drain x0.90;
  base 10/second becomes 9/second. No movement-speed, turning or camera changes.
- [ ] One 450-XP `boss:captain_senn` capstone grant and signature entitlement
  for any settled legal fate. Existing identical claims block duplicates;
  ordinary guard-kill XP remains separate and is not subtracted or replayed.
- [ ] After ROA-Q05, return to the open passage board for
  `return:saga_roa_settled` (100 XP). See shared maintenance and the real Senn outcome.
- [ ] User checks: combat and earned surrender, every Senn fate, old resolved
  saves, absent speakers, night/day signals, marsh/road returns, once-only rewards.
