# Milestone 5 - Rendering and Resource Lifetime

OPT-033 through OPT-040 implementations are present and compiled. This is not
measured performance or visual acceptance.

- OPT-033: authored trees use cached source mesh/material/bounds/normalization
  metadata directly. No preview tree actor is instantiated and destroyed just
  to discover the same immutable data. Tree transforms and colliders are retained.
- OPT-034: static detail, house/module, prop, tree/crown and deadfall batches
  upload full transform/color buffers. Matrix layout, instance count, source
  meshes, materials, color data and collision remain the same.
- OPT-035 (comparison only): opt-in alpha-detail segregation separates explicit
  transparent colors from the existing opaque batch. Default rendering is retained.
- OPT-036: the permanently hidden legacy gradient sphere/material and 2D sky
  overlay are not allocated in production setup. The existing Environment,
  depth-tested celestial bodies, stars and all authored clouds are retained.
  Legacy overlay source/factory remains available for intentional authoring use.
- OPT-037 (comparison only): static batch bounds can use the exact union of
  every transformed source mesh, with a conservative margin. This never changes
  skinned actor, particle, water or animation bounds. No previously demonstrated
  custom-AABB defect is claimed; default automatic bounds remain unchanged.
- OPT-038 (comparison only): exact opaque Record Hall wall/roof triangles can
  act as interior occluders. No doorway box or dynamic prop is used as an occluder.
- OPT-039: blade contacts, block/parry flashes and Oathfire endpoints pool nodes;
  dynamic blade ribbons reuse their own mesh object. Leases reset transforms,
  visibility, playback/tweens and materials. Stale callbacks are generation-guarded;
  idle pools are bounded. Existing impact/ground pools also have bounded retirement.
- OPT-040: asset-cache entries track active/shared/cached-zone owners. Retirement
  releases cache references only; live scene resources and renderer anchors remain
  owned until their existing retirement. Prepared geometry/occluder caches clear
  at host shutdown. This does not promise PCK unmounting or discard gameplay actors.

## Conditional Retention

OPT-035/037/038 are compiled but OFF by default, pending your comparison. On Web,
add `opt_alpha=1`, `opt_bounds=1`, or `opt_occlusion=1` to the normal URL to compare
one change at a time. Native custom arguments are `--opt_alpha`, `--opt_bounds`,
and `--opt_occlusion` after Godot's `--` separator. No saved visual preference is
modified. Enabling these by default requires user approval; they are not claimed
retained performance wins.

## User Checks

1. Compare tree population, placement/materials, roofs, houses and prop colors.
2. Check repeated melee/parry/Oathfire, reduced flashes and zone changes mid-effect.
3. Revisit cached zones and confirm all characters, materials and collisions remain.
4. Compare each opt-in separately; inspect route/roof/camera readability and culling.

## Build / Publication

Production build: `opt-m5-20261018-43e3e8c`.
Manifested artifacts: 104191462 bytes, below 104857600 bytes.
Root PCK: 9033576 bytes; SHA-256
`2f1c3e806b3c74315268f5981d9c88f9ed568c0b1cea0fd5bb8145aecf2c7206`.
The existing production compiler/export and static package identity checks
completed. Publication uses OPT-040; the local publication receipt records the
resulting commit and deployment. No runtime test, browser, benchmark, automated
gameplay or screenshot capture was performed by the agent.
