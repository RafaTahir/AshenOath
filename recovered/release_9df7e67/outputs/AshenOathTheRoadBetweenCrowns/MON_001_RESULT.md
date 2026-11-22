# MON-001 Result

## Scope

Closed the released monster-family identity contract for Ghoulkin, Wychwood
roles, Bog Wretch, Gravebound Knight, and the White Hart body. Boss phase,
arena, reward, and aftermath behavior remains covered by the accepted
`BOSS-001` contract; world composition remains owned by `WORLD-001` and
`WORLD-002`.

## Changes

- Corrected the native face/anatomy driver so approved Quaternius monster roles
  validate their complete skinned mesh surfaces without being forced through a
  human brows, skin, and blinking contract.
- Added an explicit `monster_native_anatomy` report kind. Monster verification
  still rejects synthetic overlays and requires native rendered anatomy.
- Kept the existing accepted mappings: Ghost Ghoulkin, Demon Stalker, Orc
  Raider, Blue Demon Brute, Slime Bog Wretch, Skeleton Gravebound Knight, and
  the native animated stag White Hart.
- Preserved all existing AI profiles, animation maps, scale ranges, boss state,
  quest IDs, and save-compatible enemy IDs.

## Runtime Result

- Every released family has a complete, grounded, animated body with a distinct
  silhouette and material identity.
- No Wychwood role silently falls back to a primitive, bat, dragon, or shared
  human body.
- The White Hart uses the approved native stag and antler mesh rather than the
  former procedural proxy.
- Human native-face behavior remains unchanged; monsters are not assigned fake
  human eye or brow overlays.

## Verification

- `verify_face_003.gd`: PASS across humans and all five Wychwood enemies.
- `verify_mon_002.gd`: PASS.
- `verify_character_real_001.gd`: PASS.
- `capture_monster_families.gd`: PASS under the native Compatibility renderer.
- Visual review: PASS for complete anatomy, distinct silhouettes, grounding,
  material visibility, and native White Hart presentation.

## Screenshot

- `Development_Gallery/screenshots/MON_002_RUNTIME_FAMILIES.png`

## Remaining Work

- Opening and campaign environment art remain open under `WORLD-001`,
  `WORLD-002`, and `PRES-001`.
- Performance, complete campaign traversal, final browser certification, and
  release remain open under their owning tickets.
- No Web export, browser run, commit, push, merge, tracked production sync, or
  deployment was performed.

## Running Steps

```powershell
Set-Location D:\Projects\AshenOath\outputs\AshenOathTheRoadBetweenCrowns
$godot = 'C:\Users\User\.cache\codex-runtimes\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe'
& $godot --headless --path . --script tools/verify_face_003.gd
& $godot --headless --path . --script tools/verify_mon_002.gd
& $godot --headless --path . --script tools/verify_character_real_001.gd
& $godot --path . --script tools/capture_monster_families.gd
```
