# ENGINE-003 — Resource Lifecycle and Cache Policy

## Files Changed

- `scripts/game.gd`
- `scripts/asset_spawn_helper.gd`
- `scripts/world_material_library.gd`
- `tools/verify_engine_003.gd`
- `ENGINE_003_RESOURCE_LIFECYCLE_AND_CACHE_POLICY.md`

## Implementation

- Established one explicit owner state for every zone root: `active`, `cached`, or `retiring`.
- Limited the route cache to one disabled, invisible inactive zone and removed duplicate cache ownership by node identity.
- Replaced renderer-resource stripping with staged whole-subtree disposal. Mesh and MultiMesh resources remain valid until their owning nodes are freed.
- Added deterministic shutdown and lifecycle snapshots for verification.
- Added one cache-stable world fallback material.
- Audited generated MeshInstance3D and MultiMeshInstance3D nodes after zone construction and repaired missing effective materials.
- Hardened imported asset material assignment per surface and stopped caching failed resource loads.

## Cache Policy

- Asset, mesh, texture, and material caches are runtime-global and remain shared across zone transitions.
- Exactly one inactive route zone may be cached.
- A cached zone has collision, processing, and visibility disabled.
- Unretained zones wait two rendered frames, then their complete subtree is freed without mutating live renderer resources.
- Save, quest, content, UI, and Web output behavior are unchanged.

## Verification

- Parser/import check.
- ENGINE-002 extraction regression.
- Runtime route verifier.
- ENGINE-003 lifecycle and material verifier.

## Remaining Scope

- ENGINE-003 does not tune memory or transition budgets; that belongs to `PERF-002`.
- Navigation edge-merge warnings remain secondary and are not changed unless they prove to originate from duplicate lifecycle ownership.
