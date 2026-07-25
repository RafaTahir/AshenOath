# GAMEPLAY-001 — First-Hour Loop and Pacing

## Implementation

- Replaced misleading individual-clue tracking with count-based, order-independent investigation summaries.
- Road evidence reads `Investigate the Wychwood road (n/3)`.
- Cemetery evidence reads `Inspect the disturbed graves (n/2)`.
- Preserved optional clues after each threshold without allowing repeats to progress.
- Added a versioned first-hour route and pacing contract covering Anwen, the pack, reporting, cemetery, and chapel handoffs.

## Running

Run New Game. Speak with Anwen, inspect any three Wychwood clues, defeat all five enemies, inspect the changed tracks, and return by any report method. Continue to Anwen at the cemetery gate and inspect any two graves.
