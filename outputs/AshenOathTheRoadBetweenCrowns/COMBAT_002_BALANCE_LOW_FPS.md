# COMBAT-002 — Balance and Low-FPS Combat

## Implementation

- Fixed blade contacts being skipped when a long frame crosses the strike threshold.
- Added a 180 ms light/heavy attack input buffer during recovery.
- Increased the parry window from 240 ms to 300 ms for browser readability.
- Preserved damage, stamina costs, enemy health, wave staging, and the single-attacker token.
- Added an explicit versioned tuning and low-FPS contract.

## Running

Run New Game and reach Wychwood. Light attack is left click, heavy attack is right click, tap `Q` to parry, hold `Q` to block, and press `C` for Oathfire. Inputs made just before attack recovery ends are now retained.
