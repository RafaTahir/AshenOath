# CHAR-002 — Villagers, Guards, and Travelers

## Implementation

- Expanded Greyfen routines from two alternating bodies to four existing skeletal body sources.
- Separated road travelers from Castle guards and assigned distinct hooded/ranger and martial silhouettes.
- Assigned named Widow Elna and Blacksmith Tor occupation-specific bodies.
- Added deterministic occupation palettes for workers, mourners, pilgrims, guards, and rangers.
- Added explicit height and LOD role specifications without changing collision or quest ownership.

## Verification

`verify_char_002.gd` requires six loadable skeletal roles, correct normalized heights, four distinct crowd sources, distinct guard/traveler bodies, and the versioned role manifest.

## Running

Run the project in Godot 4.6.3, choose New Game, and walk from Greyfen spawn through the shrine and forge. The four ambient villagers now cycle distinct bodies and identities. Castle guards and Long Road travelers are distinct when those zones are entered.
