# SAVE-004 Result

## Outcome

Advanced the save schema to version 9. Saves now carry canonical
`world_sector`, `world_position`, and `seamless_world` state while preserving
existing quest, story, inventory, vendor, time, health, stamina, and world
state payloads. Legacy zone aliases migrate to canonical sectors. Legacy
interior positions now map to their correct world cells instead of silently
falling back to Greyfen coordinates.

## Verification

- `tools/verify_save_004.py`: PASS
- Existing `verify_save_003` gate: PASS
- Atomic save and backup paths remain unchanged.
- Missing seamless fields initialize neutrally for old saves.

## Limitation

Invalid positions continue to use the existing validated local recovery path;
full campaign save permutation coverage belongs to the later campaign QA gate.

