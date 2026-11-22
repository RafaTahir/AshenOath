# AI-002 — Per-Family Behavior and Perception

## Implementation

- Added explicit skirmisher, flanker, feinter, brute, lurker, sentinel, duelist, and boss profiles.
- Added 5.5 Hz line-of-sight checks and bounded last-known-position memory.
- Prevented attacks without current visual contact.
- Added slow reveal behavior for Bog Wretches and measured lateral movement for human duelists.
- Preserved navigation, leash, attack-token, health, damage, and quest behavior.

## Running

Run the Wychwood encounter and use trees or solid scenery to break line of sight. Enemies investigate the last seen position briefly instead of tracking through the obstacle forever.
