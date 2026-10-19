# WORLD-SAGA-102 - Wychwood: Where the Water Runs

Parent: [WORLD-SAGA-000](../WORLD-SAGA-000.md). Status: build-only implementation present; user acceptance pending.
Current compilation/publication details: [implementation record](../IMPLEMENTATION.md).
Region: `wychwood`. Places: existing cart road, bridge, working grove, northern clearing.

## People And Regional Story

Iven, a forester, wants enough sound wood without losing the living grove.
Edda, a charcoal burner, knows the paths and resents being blamed for every scar.
Their disagreement is about limits on useful work, not civilization versus an
intrinsically evil forest. The grove contains ordinary animals, old human work
and dangerous memory vessels; distinguish the three through observable evidence.
Keep Bram/Sella/Oren's existing investigation, the five-enemy clearing, bitter
roots, Oren's red thread and Black Dog Contract intact.

Place the two living workers in small clear laybys, never across clue/return
lanes. Their tools, cut stacks and shelters reuse retained props. No new village
or permanent quest-giver crowd is needed. Their routines change after agreements.

## Five New Quests

| ID | New story | XP | Dependencies |
| --- | --- | --- | --- |
| [WYC-Q01](../quests/WYC-Q01.md) | The Woodcutter's Silence | 300 | Wychwood access |
| [WYC-Q02](../quests/WYC-Q02.md) | What the Traps Took | 350 | Wychwood access |
| [WYC-Q03](../quests/WYC-Q03.md) | A Song for No One | 250 | Safe conversation with Edda; no romance gate |
| [WYC-Q04](../quests/WYC-Q04.md) | The Hunter's Blind | 300 | Read the old lookout mark |
| [WYC-Q05](../quests/WYC-Q05.md) | Where the Water Runs | 500 | Bog Wretch encounter resolved; no Q01-Q04 gate |

## Artifacts And Secrets

- [ ] WYC-S01, hunter's cache. A split-feather carving on the ground-level blind
  points to three aligned branch scars. Follow them to a dry stone pocket; no
  pixel hunt or required high jump. Contents: old hunter's knife record, six
  Standard arrows, 100 XP. The cache is separate from WYC-Q04's named owner deposit.
- [ ] WYC-S02, charcoal shelter. Smoke-stained stones and Edda's optional direction
  identify a concealed rain shelter; lift the loose screen from outside.
  Contents: charcoal burner's seasonal journal, one bitterleaf tonic, 100 XP.
  Edda's confidence is helpful, never the only route or implied permission to steal.
- [ ] WYC-S03, boundary inscription. After WYC-Q05's clearing/drainage action,
  inspect revealed boundary marks from the safe bank. Contents: a record of a
  once-public crossing, 100 XP. Both lawful water choices expose it; no wading
  through forbidden river collision or changing the bridge-only rule.

The knife/journal/inscription are lore. Claims use the S IDs, not generic
discovery plus an extra secret reward. Ordinary herb harvests keep existing ownership.

## Capstone: Bog Wretch And Migration

- [ ] Keep `bog_wretch`, approved cursed-human source, collision dimensions and
  existing `main_teeth_in_rain:fight_bog_wretch` and memory-core decision IDs.
- [ ] Author the arena beside the existing northern ritual route, outside the
  bridge/Deep Wood transit lane. Trigger only after Oren's naming prerequisite;
  ordinary passing does not ambush a player still investigating the cart.
- [ ] Wet Shell (100-50%): visible shoulder lift before a short advancing rake,
  dark bubbles before a ground burst, clear recovery after overextension.
  Exposed Core (below 50%): brighter core, alternating shorter rakes and a
  longer telegraphed burst. Fit these to current animation/damage contracts.
- [ ] Root-bed observations expose safe burst lanes; optional preparation helps
  but no secret or Moon Oil craft is required. All existing core dispositions remain.
- [ ] Extend the existing boss/checkpoint owner for this promoted encounter;
  no separate temporary monster with another ID. Checkpoint normalizes saved
  position to its safe arena arrival while retaining supplies and fight progress.
- [ ] Remove the original Deep Wood spawn authority when migrating. Translate an
  unfinished old checkpoint to the new arena; preserve completed fight/core choice,
  pending core interaction and boss/quest claims. Never spawn or award two copies.
  Keep the Deep Wood route usable and update its direction text consistently.

## Reward, Return And Checklist

- [ ] Wayfarer's Bow Grip (`saga_wayfarer_grip`): full-draw time x0.90; current
  one-second full draw becomes 0.90 seconds. Keep aim sensitivity, camera,
  draw-ratio damage, ammo and cancellation rules; use the new duration everywhere.
- [ ] Promote the current generic encounter to canonical `boss:bog_wretch`
  with a 400-XP budget. For an old recorded 75-XP claim, grant only the new
  325-XP difference as specified in the master; no generic-plus-boss double award.
  Legitimate core choices do not alter the mechanical reward.
- [ ] After WYC-Q05, a later sector return to the clean bank grants
  `return:saga_wyc_settled` (100 XP) and shows working collection pots/animal signs.
- [ ] User checks: fresh and old Bog saves; all core choices; five-enemy wave
  intact; bridge both ways; secrets at day/night; bow draw/cancel; water aftermath
  and no duplicate boss, checkpoint, objective or reward.
