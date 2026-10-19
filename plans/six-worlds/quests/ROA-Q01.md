# ROA-Q01 - Toll for the Living

Parent: [WORLD-SAGA-104](../worlds/WORLD-SAGA-104.md). Runtime ID: `saga_roa_q01`.
Status: build-only implementation present; user acceptance pending. See [current build/delivery record](../IMPLEMENTATION.md).
Type: optional, connected. XP: 300. Crossing/checkpoint access only.

## Hook And People

Nera finds families paying a temporary toll twice: once at the crossing, once
for the same stamped pass at the checkpoint. Tavin can compare the stamps but
is reluctant to attract the officers' attention. Current theft matters even if
Senn has an account of an older injustice.
Nera: "A price written plainly is one thing. The same price twice is another."

## Playable Objectives

1. `hear_double_toll`: inspect a traveler's two receipts or hear Nera's account.
2. `compare_terms`: read the crossing rate and checkpoint stamp board in either order.
3. `locate_held_goods`: identify two confiscated bundles in a clearly marked camp
   store using matching claimant tags. DEP-Q01's freight copy offers context only.
4. `secure_release`: choose a public comparison through the camp account, or
   a quiet return with duplicate receipts deposited for later hearing.
5. `return_claimed_goods`: carry both bundles to the travelers' safe collection
   shelf and strike the duplicate charge from the current passage sheet.

## Branches And Consequences

`public`: corrected rate displayed; guards acknowledge an exposed practice.
`recorded`: households get goods without public names; a protected copy survives.
Neither automatically clears Senn's raids, changes his fate or supplies a new oath.
After his prior removal, Tavin reconciles the old camp account without replaying guards.
Tavin: "Put down what went back as carefully as what was taken."

## State, Rewards And Recovery

Save receipt/stamp facts, both bundle deliveries and `saga_roa_q01_outcome`
(`public`, `recorded`). Reward: 300 XP and two travel bread once.
No required bribe, theft combat, rescue timer or personal money. The main road
stays traversable before completion. Missing named speakers use the posted rate
and signed returns; interrupted carrying reconstructs the remaining bundle only.
This is not the existing surrender/account quest or a repeat of Greyfen's sack weighing.

## User Manual Checklist

Compare stamps out of order, use both release paths, reload with one bundle
delivered and finish before/after each Senn fate without duplicating guard combat.
