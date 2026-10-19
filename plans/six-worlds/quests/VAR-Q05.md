# VAR-Q05 - Those Who Had No Graves

Parent: [WORLD-SAGA-105](../worlds/WORLD-SAGA-105.md). Runtime ID: `saga_var_q05`.
Status: build-only implementation present; user acceptance pending. See [current build/delivery record](../IMPLEMENTATION.md).
Type: optional connected aftermath. XP: 500. Final Halvern disposition recorded.

## Hook And People

After Halvern's bounded account is resolved, Lysa finds that the known names
have no place in the castle memorial. Oris is not summoned early from Hartlands;
ordinary local work and written family replies suffice here.
Lysa: "We can mark where the account is kept without pretending we found the bodies."

## Playable Objectives

1. `compare_named_records`: compare guaranteed copied proof with memorial entries;
   include only established identities and explicitly mark unresolved gaps.
2. `choose_memorial`: choose an attributed public name panel with addresses
   removed, or a quiet record repository with individually offered family access.
3. `prepare_place`: clear the existing side memorial alcove and fit supplied
   blank plaques/record sleeves, outside Halvern's saved combat lane.
4. `place_accounts`: transfer the agreed copies by hand and label records as
   testimony/documents, not consent or confirmed burials.
5. `leave_response_space`: set an empty reply tray and hear/read the first
   voluntary acknowledgement; no compulsory family attendance.

## Branches And Consequences

`public_panel`: visible established names and sources. `quiet_repository`:
searchable copies and a modest marker. Either can coexist with Halvern released,
preserved or destroyed; his absence does not erase guaranteed command proof.
New physical memorial work earns this quest, not the old guard-break callback.
Kael: "Write what we know. Leave room for the people who know something else."

## State, Rewards And Recovery

Save compared name IDs, place prepared, copies placed and `saga_var_q05_outcome`
(`public_panel`, `quiet_repository`). Reward: 500 XP once; pommel and 450 boss XP
remain separate capstone entitlements. Later return to the memorial grants
`return:saga_var_settled` (100 XP) once. Q01-Q04 not required.
If Lysa is absent, her prepared request/archival receipt handles the work.
Original proof is copied, never consumed. Reload restores unplaced sleeves and
does not revive Halvern or manufacture a family reply/consenting witness.

## User Manual Checklist

Finish after every Halvern outcome, use both memorials, leave/reload mid-placement,
return twice and continue the existing Assembly/Hart route without changed evidence.
