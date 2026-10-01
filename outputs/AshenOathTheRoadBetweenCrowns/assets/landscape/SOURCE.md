# Landscape and bridge foundations

`far_terrain.res` is original Ashen Oath authored geometry. The inner perimeter
joins the existing scene support apron; rolling outer ridges provide terrain
behind the trees rather than changing fog to conceal a missing landscape.

`bridge_stone_pier.res` is a fitted four-course assembly derived from the retained
Quaternius forest `Rock_Medium_1.obj` CC0 source. It is a visual foundation only;
bridge collision continues to belong to BridgeSurfaceContract.
The retained `License_Standard.txt` in
`assets_external/licenses/quaternius_stylized_nature_megakit/` declares CC0-1.0.
Two interlocking stones per course use 2,736 triangles in one shared surface,
not the initial 5,472-triangle unintegrated bake.

Build with `tools/build_landscape_foundations.gd`. No runtime terrain generation,
collision mesh, transparent wall, downloaded source or proprietary art is added.
Runtime hashes, byte counts, pack ownership and license lineage are recorded in
`runtime_asset_manifest.json` after the deterministic bake and contract proof.
