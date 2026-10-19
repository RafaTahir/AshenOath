# HAR-Q01 - The Names Without Stones

Parent: [WORLD-SAGA-106](../worlds/WORLD-SAGA-106.md). Runtime ID: `saga_har_q01`.
Status: build-only implementation present; user acceptance pending. See [current build/delivery record](../IMPLEMENTATION.md).
Type: optional, connected memorial story. XP: 300. Existing late-road access only.

## Hook And People

Oris has blank stones and a short list of people whose burial places remain
unknown. He wants a place for remembrance without pretending the stones establish
where somebody died. Maelin asks him to leave room for names nobody has recovered.
Oris: "I can cut a straight line. I cannot make an uncertain name certain."

## Playable Objectives

1. `read_request`: inspect Oris's invitation and known-name list at the Ruins workbench.
2. `compare_sources`: compare the offered copied record and two existing memorial
   marks. Use only independently established names; mark gaps as unknown.
3. `choose_place`: choose a small public marker with attributed names and gaps,
   or a quiet memorial space with the account kept nearby for voluntary reading.
4. `set_stones`: carry three supplied lightweight work stones to prepared safe
   sockets and place the selected inscription sleeves. No arbitrary free-build system.
5. `leave_space`: set a blank, explicitly unnamed marker for future information;
   do not assign the unnamed child's grave to Oren without evidence.

## Branches And Consequences

`named_walk`: public existing names with sources. `quiet_place`: a modest
marker and accessible account. Both preserve uncertainty and room for later replies.
This adds an outdoor Hartlands remembrance place, not VAR-Q05's castle repository
or the existing three memorial candles in Greyfen. It unlocks no required ending.
Maelin: "Leave that one blank. It is not empty because we have failed to guess."

## State, Rewards And Recovery

Save compared sources, stone IDs, inscription choice and `saga_har_q01_outcome`
(`named_walk`, `quiet_place`). Reward: 300 XP and a local memorial lore entry.
Oris's standing work request handles physical work when absent; no invented
family attendance or signatures. Post-ending dialogue acknowledges the real
covenant. Reload restores remaining stones and does not consume original evidence.

## User Manual Checklist

Use incomplete/complete known-name records, choose both memorials, interrupt
stone carrying and finish before/after each covenant without a new ending requirement.
