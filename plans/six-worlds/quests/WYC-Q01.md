# WYC-Q01 - The Woodcutter's Silence

Parent: [WORLD-SAGA-102](../worlds/WORLD-SAGA-102.md). Runtime ID: `saga_wyc_q01`.
Status: build-only implementation present; user acceptance pending. See [current build/delivery record](../IMPLEMENTATION.md).
Type: optional, connected regional pressure. XP: 300. Wychwood access only.

## Hook And People

Iven's crew stopped work after hearing names in the cut stumps. He wants to know
which trees can be cut safely, not a license to level the wood. Edda suspects a
current boundary marker was moved to put her grove inside somebody else's allotment.
Iven: "I know the sound a green tree makes. This one answered with a name."

## Playable Objectives

1. `hear_stoppage`: hear Iven's account at the working layby, outside active combat.
2. `compare_stumps`: inspect three marked stumps: one rotten, one recent cut,
   one containing a worked name-bearing iron tag. Any inspection order is valid.
3. `find_old_boundary`: compare a displaced stake with a retained stone boundary;
   a tool-width cut shows present intrusion, not proof the forest attacked first.
4. `mark_working_line`: choose sound fallen timber only, or a limited live stand
   outside the old burial/root boundary; physically place three visible work marks.
5. `return_tag`: hand the tag to Iven for safeguarded recording or to Anwen's
   existing shrine drop-off. Either preserves its limited account and closes the job.

## Branches And Consequences

`fallen`: slower work, smaller stacked supply and recovering undergrowth.
`limited`: a modest living stand is marked and a watch keeps cutting inside it.
Neither causes random later punishment. The returned tag contextualizes the
Bog Wretch's claimed ground without supplying Oren's name or replacing Road of Crows.
Edda: "A line is useful when someone is willing to stop at it."

## State, Rewards And Recovery

Save the three inspections, line-marker set, tag custody and
`saga_wyc_q01_outcome` (`fallen`, `limited`). Reward: 300 XP and one iron trap.
The tag is attributed evidence, not a dead person's permission to cut elsewhere.
No player-owned supplies required. Interrupted marking resumes at remaining
posts; missing workers use their work ledger/drop-off. Completed original forest
quests change acknowledgement, never require a second enemy wave or revived boss.

## User Manual Checklist

Inspect stumps out of order, choose each working line, reload with a held tag,
finish after the Bog encounter and confirm the original forest objectives remain intact.
