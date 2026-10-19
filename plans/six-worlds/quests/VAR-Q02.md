# VAR-Q02 - A Servant's Price

Parent: [WORLD-SAGA-105](../worlds/WORLD-SAGA-105.md). Runtime ID: `saga_var_q02`.
Status: build-only implementation present; user acceptance pending. See [current build/delivery record](../IMPLEMENTATION.md).
Type: optional, connected human story. XP: 350. Courtyard/service threshold accessible.

## Hook And People

The retained tired servant has been promised a family pass in exchange for removing
a complaint from a service basket. Merrow calls it an administrative convenience.
The servant needs safe movement for relatives, not a reward for betraying another worker.
Servant: "The pass is real. That is what makes the offer difficult."

## Playable Objectives

1. `hear_offer`: hear the servant privately. On quality presets where this actor
   is not spawned, use the same person's attributed service-basket note, not a second body.
2. `verify_pass`: compare the family pass terms and dated complaint receipt in
   the courtyard service area, preserving the complainant's private identity.
3. `choose_protection`: insist Merrow issue an unconditional pass on record, or
   arrange the documented neutral service passage and preserve the complaint separately.
4. `deliver_copy`: hand the complaint to the existing archive intake and place
   the safe-passage copy in the servant's agreed household parcel.
5. `confirm_departure`: inspect an actual departure acknowledgement; no off-map escort.

## Branches And Consequences

`unconditional`: steward's revised pass visibly separates help from compliance.
`neutral_route`: relatives use the existing passage; a protected complaint remains.
No branch compels testimony, creates new household consent or bypasses original
Castle evidence gates. After Edric's fall, the same case resolves an outstanding restriction.
Merrow: "Then write the terms where the next clerk has to see them."

## State, Rewards And Recovery

Save terms verified, route, two parcel/copy deliveries and `saga_var_q02_outcome`
(`unconditional`, `neutral_route`). Reward: 350 XP and two travel bread once.
No required bribe, killing, romance or public naming of the servant. Absence uses
signed instructions and a receipt; never stage the servant as an invisible live speaker.
Reload reconstructs remaining delivery, not a new confiscation. Preserve current
optional NPC quality policy while keeping this quest accessible in every preset.

## User Manual Checklist

Use each protection route, a preset without the servant actor, an advanced save
and reload after one delivery; confirm intact complaint and original Castle access.
