# MAT-001 — Surface and Material Library

## Files Changed

- `scripts/world_material_library.gd`
- `tools/verify_mat_001.gd`
- `tools/gate_profiles.json`

## Implementation

- Defined seven authored surface profiles with stable scale and roughness values.
- Enabled normal, roughness, anisotropic filtering, and world-triplanar projection in Balanced.
- Kept Potato to one albedo sample per surface; Quality adds AO and stronger normal response.
- Added shared texture caching, normalized quality names, wetness quantization, named resources, and a stable non-white fallback.
- Added a material contract verifier for texture completeness, quality budgets, cache identity, wetness, grass, and fallback behavior.

## Verification

Run through the WORKFLOW-002 `materials` profile. No Web export or production deployment is required for this ordinary ticket.

## Running

Open the existing local Web candidate as before, or run the Godot project from `scenes/main.tscn`. Select Balanced in Settings to inspect the upgraded surface detail.
