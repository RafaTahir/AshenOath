# HAR-Q03 - Where the Deer Return

Parent: [WORLD-SAGA-106](../worlds/WORLD-SAGA-106.md). Runtime ID: `saga_har_q03`.
Status: build-only implementation present; user acceptance pending. See [current build/delivery record](../IMPLEMENTATION.md).
Type: optional independent habitat story. XP: 250. Late woodland edge accessible.

## Hook And People

Maelin notices old deer paths stop at discarded human cord and a broken screen.
The Hart is not every deer in the wood. Restoring ordinary habitat is a small
act with no secret command over the supernatural witness.
Maelin: "They used this path before anyone needed it to mean something."

## Playable Objectives

1. `read_tracks`: inspect hoofprints, a rubbed trunk and abandoned cord in any order.
2. `choose_corridor`: choose the quiet outer shoulder or the sheltered inner
   passage, both separated from the player transit and Hart combat lanes.
3. `clear_hazards`: unwind three cord points and brace the fallen screen rather
   than deleting the retained scenery. No hunting or animal damage required.
4. `mark_quiet_edge`: place two unobtrusive human-work markers to keep future
   stores off the corridor. No magic animal-attraction ability.
5. `confirm_signs`: after leaving the immediate work area and returning, inspect
   newly placed hoof signs. This is an explicit authored response, not a simulation promise.

## Branches And Consequences

`outer`/`inner` change which habitat edge is clear. Both allow fresh tracks and
modest undergrowth, including post-Ash adaptation outside scorched ground.
Use retained approved wildlife only if available; tracks and supported ambience
carry the required observable result. Never miniaturize/copy the White Hart as a herd.
Optional audible hints have visual/subtitle equivalents.

## State, Rewards And Recovery

Save observed/cleared IDs, corridor, confirmation and `saga_har_q03_outcome`
(`outer`, `inner`). Reward: 250 XP and the habitat field-note entry.
No real-time wait, bait purchase, skill unlock or other new quest required.
Cancel/ending/reload preserves cleared hazards; confirmation does not grant the
world's separate post-Q05 sector-return reward. Do not relocate the player or wildlife to fake travel.

## User Manual Checklist

Use each corridor before/after the ending, interrupt removal, confirm signs
without audio and ensure no hidden kill requirement, Hart duplicate or blocked route.
