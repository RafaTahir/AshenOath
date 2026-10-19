# WYC-Q02 - What the Traps Took

Parent: [WORLD-SAGA-102](../worlds/WORLD-SAGA-102.md). Runtime ID: `saga_wyc_q02`.
Status: build-only implementation present; user acceptance pending. See [current build/delivery record](../IMPLEMENTATION.md).
Type: optional local ecology story. XP: 350. No Bracken/Black Dog prerequisite.

## Hook And People

A fresh snare lies beside old camp wire. Iven says poachers set it; Edda recognizes
knots from her own abandoned lean-season line. She must take responsibility without
making it harder for households to feed themselves.
Edda: "I took down the ones I remembered. That is not the same as taking down all of them."

## Playable Objectives

1. `read_snare`: inspect the mechanism and fresh animal track from a safe path.
2. `release_line`: open three marked snares in any order, including one holding
   a small injured animal. Use patient interaction; no pet recruitment or QTE.
3. `trace_owner`: follow matching cord to Edda's tool roll and hear her account.
4. `settle_hunting`: choose a marked seasonal trapping limit with an agreed check
   routine, or retire the old line and establish household food exchange at her layby.
5. `clear_remaining`: gather the remaining loose wire into a safe bin and inspect
   the released animal's open escape route. Do not require it to heal instantly.

## Branches And Consequences

`regulated`: maintained, visibly marked safe-set line outside travel routes.
`retired`: empty anchors and a small lawful exchange basket. Both show the cost
and reduce abandoned harm; neither rewrites the dangerous Black Dog memory vessel.
Wildlife can return later; Bracken is optional company, never a required tool.
Iven: "It was made by a hand. We can begin by using ours."

## State, Rewards And Recovery

Save each snare ID/released state, wire cleared and `saga_wyc_q02_outcome`
(`regulated`, `retired`). Reward: 350 XP and one redroot potion once.
No consumable bait or timed animal death. Reload cannot reclose a released trap;
the animal rests off the collision lane if the player leaves. If Edda is absent,
her signed tool roll supports safe decommissioning; her acknowledgement waits.

## User Manual Checklist

Release in different orders, leave/reload beside the animal, finish without Bracken,
choose both hunting plans and confirm no reopened snares or duplicated supplies.
