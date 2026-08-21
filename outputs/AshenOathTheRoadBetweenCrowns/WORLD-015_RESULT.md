# WORLD-015 Result

## Current Development Checkpoint

This checkpoint adds the first authored presentation pass to the four later-wild
builders without changing their route topology or quest ownership. It is a
development result, not a final campaign visual approval.

## Changes
- Deep Woods, Old Mill, Burned Farmstead, and Marsh Crossing remain bounded builders with authored routes and return/continue gates.
- Rootbound Colossus and Ashwing spawn hooks are tied to the existing quest state rather than unconditional decoration.
- Wilderness routes now use a narrower 3.35 m damp-earth road, textured shoulder bands, path stones, grass clusters, and waystones.
- Deep Woods adds approved mapped rock silhouettes, a memory altar, and a denser but route-safe forest edge.
- Old Mill now has a bounded stone foundation, framed walls, charred beams, door, water wheel, forge glow, and pitched visual roof treatment.
- Burned Farmstead now uses open structural wall sections, roofs, doors, ash patches, a firepit, and clearer yard staging instead of solid block homes.
- Marsh Crossing uses a cached water material for non-walkable pools, existing boardwalk collision, reeds, and approved rock dressing.
- Loose wilderness rocks now use the approved `forest_rock` role when available instead of defaulting to rubble boxes.
- Non-paved road tinting now respects the zone palette so the path reads as damp earth rather than a bright or black slab.

## Verification
- `verify_world_015.gd`: PASS.
- `verify_world_004.gd`: PASS.
- `verify_engine_003.gd`: PASS. Active runtime material/resource checks are clean; known renderer shutdown allocator/RID/ObjectDB diagnostics remain.
- `verify_perf_003.gd`: PASS.
- Static route and builder contract checks: PASS.

## Screenshots

Fresh graphical Compatibility captures (1280x720) are written to the ignored
gallery directory:

- `Development_Gallery/screenshots/WORLD_004_01_DeepWood_20260821_085426.png`
- `Development_Gallery/screenshots/WORLD_004_02_AshMill_20260821_085426.png`
- `Development_Gallery/screenshots/WORLD_004_03_BurnedFarmstead_20260821_085426.png`
- `Development_Gallery/screenshots/WORLD_004_04_MarshCrossing_20260821_085426.png`

The frames are nonblank and show the route, portal, character, landscape
dressing, and zone landmark. They remain stylized and do not satisfy the final
AAA visual bar for buildings or sky.

## Remaining
Final visual review, the remaining later-zone architecture pass, sky/cloud
repair, full hardware performance capture, and complete campaign acceptance
remain in the campaign milestone gate.

## Running
Run `Godot_v4.6.3-stable_win64_console.exe --headless --log-file .release-gate\\world_015.log --path . --script tools\\verify_world_015.gd`.
