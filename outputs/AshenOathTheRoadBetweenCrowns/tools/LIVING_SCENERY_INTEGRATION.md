# Living scenery: retained geometry and Blender provenance

The four authored assemblies are checkpoint cloth (2 parts), marsh reeds (5),
Hart ferns (6), and the Ash Mill wheel (1). Their inline runtime scenes live in
assets_external/environment_prepared/living_world. The existing world prop
owner animates them; these assets add no per-prop controller.

The full native builders remove the same parts from the surrounding static
meshes. Always ship the rebuilt static meshes and moving scenes together.
Do not run a moving-parts-only extraction over the original static meshes:
that would duplicate their visible geometry.

## Maintained release integration

Run the pinned Godot 4.6.3 editor executable headlessly from this project:

    Godot --headless --path <game> --script res://tools/build_living_world_blender.gd
    Godot --headless --path <game> --script res://tools/verify_living_world_split.gd

These two steps validate and compile existing authored deliveries. They must
finish successfully before pack layout/resource closure and package hashes are
generated. The builder must not implicitly launch Blender or rewrite authoring.
The compiler validates current recipe/helper hashes, every archived native input,
the editable .blend, raw/final carriers, source builders, mesh identities, pivots,
and strict complete triangle-corner equivalence. It explicitly disables GLTF
attribute compression to preserve the retained position and UV precision.

The nine original combined meshes are frozen under
art_source/art_recovery_v2/evidence/living_assets_stage3_20261107/scenery/combined_original.
This archive must remain unchanged. The final union check compares those exact
originals with the rebuilt static meshes plus all fourteen moving parts,
including untouched surroundings, transforms, winding, multiplicity, normals,
colors, UVs, and semantic material roles.

If an approved source change requires reauthoring, use the explicit serial
tools/run_living_scenery_pipeline.py with a new receipt directory. Its full
sequence performs three complete native builds, four Blender recipes, compilation
and union verification. A failed receipt cannot resume. Versioned .blend/GLB files
and their archived recipes/helpers are retained; successful new runs advance the
authoring.json pointer without overwriting old versions.

## Verified checkpoint

The v001 Blender deliveries and failed actual_pipeline_r1 receipt are retained.
The corrected v002 deliveries preserve coincident/opposite faces as separate
editable triangle corners, unquantized FLOAT_COLOR, and raw source normals in
the named _AO_RETAINED_NORMAL float attribute. The helper validates the full
exported corner multiset before binding NORMAL to that exported accessor; its
binary payload is unchanged. Both raw and final GLBs remain archived.

Actual_pipeline_r2 completed all three native builders and four v002 Blender
assemblies. Its compiler stopped on default Godot UV compression. The read-only
native_transport_diagnostic_r1 isolated that channel without changing tolerances.
Actual_pipeline_r3 then validated 239 exact retained inputs, allowed only the
reviewed compiler import repair and eight compiler output destinations, and
passed the parser, all four native compilations, and the real nine-mesh union.
The four compiled scenes total 110,449 bytes.

These receipts prove authored resource fidelity. They do not prove actual-level
visibility, animation, performance, browser behavior, physical-phone coverage,
or user acceptance. Those checks remain part of the assembled candidate gates.
