# ROA-Q03 - Boots That Do Not Fit

Parent: [WORLD-SAGA-104](../worlds/WORLD-SAGA-104.md). Runtime ID: `saga_roa_q03`.
Status: build-only implementation present; user acceptance pending. See [current build/delivery record](../IMPLEMENTATION.md).
Type: optional independent personal story. XP: 250. Safe camp table reached.

## Hook And People

Tavin wore a missing soldier's uniform to cross a hostile checkpoint. The coat
contains an unsent household letter; he is frightened that returning it will
expose his own refusal. His motive is safety, not a magical identity theft.
Tavin: "The boots were too large. I kept waiting for someone to look down."

## Playable Objectives

1. `hear_borrowed_name`: hear Tavin's admission, or examine his offered sealed parcel.
2. `verify_property`: compare the coat's repair mark and household address label;
   do not open the private letter to identify its intended recipient.
3. `choose_delivery`: return the effects through a neutral household drop with
   the borrower's name withheld, or include Tavin's voluntary signed account.
4. `prepare_parcel`: fold the coat, seal the letter intact and mark that the
   soldier's fate remains unknown. Deliver to the established road-post collection.
5. `confirm_receipt`: read the collection acknowledgement; no journey to a new off-map town.

## Branches And Consequences

`private`: effects returned without publishing the deserter's whereabouts.
`signed`: Tavin accepts authorship of his act, not an oath to Senn or Kael.
Neither names him in the original hidden muster roll or settles the soldier's fate.
On return Tavin wears his own repaired coat and better-fitting ordinary footwear.
Tavin: "Someone can open that letter at home. They need not hear my excuse first."

## State, Rewards And Recovery

Save verified property, signed/private route, sealed parcel and
`saga_roa_q03_outcome` (`private`, `signed`). Reward: 250 XP and one bitterleaf tonic.
No forced undressing scene, costume-system expansion or romance. Parcel remains
quest work if interrupted. If Tavin leaves, the consent/instructions already
recorded in his parcel govern it; never invent a signature on an unchosen route.

## User Manual Checklist

Preserve the sealed letter, choose either authorship route, reload while carrying
it and confirm no changes to Senn's fate or the original Bannerless identities.
