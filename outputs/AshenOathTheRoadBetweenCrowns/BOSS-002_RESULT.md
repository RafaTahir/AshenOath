# BOSS-002 Result

## Changes
- Added `BossEncounter` with phase checkpoints, save/load state, peaceful-resolution eligibility, outcome metadata, and host callbacks.
- Attached it to every data-marked boss at spawn.
- Added defeat hooks for Bell-Eater, Rootbound Colossus, Ashwing, Halvern, and White Hart.
- Added role-specific boss telegraph feedback.

## Route hooks
- Bell-Eater spawns after the Crow Chapel opens.
- Rootbound Colossus spawns after the register reconstruction reaches the Deep Wood.
- Ashwing follows the Old Mill ash-bound encounter.
- Halvern uses the boss role in the undercroft.
- White Hart retains the existing ending resolver.

## Verification
- `verify_boss_002.gd` validates the framework and five-definition contract.
- Real-input encounter, reload, performance, and fresh screenshots remain pending the Godot user-log startup repair.
