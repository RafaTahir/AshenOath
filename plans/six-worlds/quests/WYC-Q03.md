# WYC-Q03 - A Song for No One

Parent: [WORLD-SAGA-102](../worlds/WORLD-SAGA-102.md). Runtime ID: `saga_wyc_q03`.
Status: build-only implementation present; user acceptance pending. See [current build/delivery record](../IMPLEMENTATION.md).
Type: optional independent interlude. XP: 250. Edda's safe layby accessible.

## Hook And People

Edda hums a charcoal-working call she stopped singing when workers began treating
every old tune as a supernatural summons. She misses a small pleasure, not a lost
love who needs resurrection. She asks Kael to mend the place where workers used to sit.
Edda: "It was a song for counting bundles. We were allowed to enjoy it anyway."

## Playable Objectives

1. `hear_invitation`: choose to ask about the tune; declining leaves it available.
2. `find_seat_parts`: collect the fallen seat plank and peg from the marked public
   work pile. Do not cut trees, buy a flute or consume crafted ingredients.
3. `restore_seat`: fit both pieces in the existing rest alcove outside actor routes.
4. `share_call`: choose to listen privately or join a simple response through
   dialogue choices. Display rhythm/lyrics in subtitles; no sound-only timing puzzle.

## Branches And Consequences

`listened`: Edda sings without performing for a crowd. `joined`: Kael learns the
work response and laughs at his missed line. Neither is a romance/approval grind.
Later workers may use the repaired seat; her tune remains ordinary, not a boss key.
Kael: "I can carry the wood. I make no promises about the tune."

## State, Rewards And Recovery

Save invitation, pieces fitted and `saga_wyc_q03_outcome` (`listened`, `joined`).
Reward: 250 XP and the charcoal work-song journal entry; no permanent stat boost.
Read/performance can complete entirely subtitle-only. Canceling dialogue or
leaving mid-repair resumes the same step; no real-time dusk appointment.
If Edda is temporarily unavailable, finish the seat now and return for the voluntary
exchange later. The main campaign and her other tasks never wait for this interlude.

## User Manual Checklist

Decline and return, complete with audio muted, interrupt fitting/dialogue, choose
both social routes and confirm no added combat trigger or compulsory affection.
