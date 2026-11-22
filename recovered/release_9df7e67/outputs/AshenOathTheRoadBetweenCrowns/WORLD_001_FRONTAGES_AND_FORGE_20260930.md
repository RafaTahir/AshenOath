# WORLD-001 - Fitted Frontages And Forge

Retain the finite native visual cells: street-to-shop/door/work-court joins and
supported opening work composition. Formal ticket acceptance remains pending.

## Changes

- One original three-surface frontage mesh connects existing streets to the
  apothecary, well, four door approaches and forge. Worn work courts and paired
  stone runoff lips replace visually isolated entrances. It adds no collision,
  crosses neither river bank exclusion nor the bridge, and retains actors.
- The close forge frame revealed an unfinished work bay. One fitted CC0-derived
  assembly supplies an anvil/log, supported table/axe, stock rack and quench
  bucket. Original shaped fuel/inset embers replace the orange rectangle.
  Existing wall, hearth and coal collision extents, light count, quest anchor,
  vendor and character remain unchanged. This is not a new shop system.
- Production, QA and base filters now include the three new original opening
  meshes. The grounded Ghoulkin files have explicit monster-pack ownership.
  No export was performed and no payload/performance claim is inferred.

## Resources

Frontages: 5,756 bytes, three surfaces, 168 triangles, SHA-256
`221ffe768161d6d40bbbac87881bdadc31417b7c88224066e1dec082e2719eca`.

Forge work: 101,590 bytes, two surfaces, 8,310 triangles, SHA-256
`94394c5b829bbd98c78e110840b1e6f9bfa21893b90bfcdc6842ed2358e89414`.
Source is the retained Quaternius Fantasy Props MegaKit CC0 library; native
source hashes are embedded. Both meshes use the existing material language.

## Verification And Visual Decision

- Initial frontage bake referenced an absent stone texture: its emitted PASS
  does not validate that run. Corrected to the retained medieval-brick texture
  and made a missing texture fail the builder. The final bake exits 0 clean.
- Final affected WORLD-001 native structural check exits 0 clean. Full route
  clearances, four house variants, active materials, upward frontage normals,
  river exclusion and physical fuel ownership pass. Scene totals: 855 nodes,
  181 mesh instances and two lights, within unchanged budgets.
- Established four street cameras in
  `.release-gate/world001_frontages_20260930/` were inspected. The connections
  are visible at gameplay distance, without covering the bridge or actors.
- Apothecary and both current social-table views in
  `.release-gate/world001_frontage_social_20260930/` were inspected. Stock,
  counter, seating and support remain readable and grounded.
- Both established forge views in
  `.release-gate/world001_forge_work_20260930/` were inspected. Work tools and
  stock now give the open bay a working identity; no floating tool or fuel
  panel remains. Previous bare-bay frames are diagnostic, not approval.
- Captures exit 0. Only the classified OpenGL-to-ANGLE selection warning;
  no parser, resource, material or renderer error. No numerical FPS proof.

Raw logs: `D:/Temp/AshenOath/greyfen_frontier_20260930/`.
Staged art views do not substitute for real input, save or final Web evidence.
The final source-aligned opening route exits 1: actual New Game, bridge,
Anwen, clues and five kills pass (health 109/125), but the return remains
Greyfen-pending/input-locked at (0, 0.946667, -13). Exact stdout/stderr are
`opening_route_stdout.log` and `opening_route_stderr.log` in that log directory.
There are no resource/renderer errors. Final FPS/memory, full return and
browser proof remain open; this result accepts only finite native visuals.

## Running Steps

From `D:/Projects/AshenOath/outputs/AshenOathTheRoadBetweenCrowns`, use Godot
4.6.3: `--headless --path . --script tools/build_greyfen_frontages.gd`, then
`tools/build_greyfen_forge_work.gd` and `tools/verify_world_001.gd`.
Existing graphical `capture_world_012.gd` supports `--social-only` and
`--forge-only`, with `--output-dir=res://.release-gate/<unique>`.
