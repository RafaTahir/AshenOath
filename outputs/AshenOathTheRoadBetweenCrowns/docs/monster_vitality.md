# Monster pigments and combat presentation

The vitality pass retains the twenty live design-pack creature models, their
rigs, clips and texture inputs. Species color is owned by
`data/monster_material_profiles.json` and applied by
`scripts/views/monster_material_view.gd` through the existing spawn owner.
Unused source-library creatures are outside this pass.

Each recipe binds an exact source hash and native material name. Separate
surfaces distinguish skin, eyes, teeth, linen and metal. Atlas recipes preserve
texture variation, dark recesses, chromatic islands and warm ivory highlights.
The highlight thresholds account for the renderer's working color space;
Compatibility uses sRGB output, while Forward+ and Mobile use linear output
([Godot 4.6 spatial shader reference](https://docs.godotengine.org/en/4.6/tutorials/shaders/shader_reference/spatial_shader.html)).

The opaque and coated shaders retain the native texture inputs, normal strength,
roughness, metallic response, specular response and clearcoat. The glassmoth's
layered wing membrane uses its original native material, selected by an exact
zero-strength recipe. Positive-strength transparent recipes fail validation.
There are no additional textures, geometry, material passes or actor processing
loops. Shared variants are released through the existing world-cache cleanup.

Combat stays under the current AI and model/view owners. Ready melee actors
approach inside their existing reach before requesting an attack token. Accepted
hit reactions cancel replaced strikes, while rejected animations cannot arm new
damage. The navigation goal includes the route's stop tolerance, and occupancy
queries exclude the actor requesting a route while retaining other obstacles.
Boss warnings and release effects use the same attack-shape model as hit
queries, with the original ranges, damage, telegraph and recovery durations.
Bestiary memory text describes behavior the runtime actually implements.

## Verification

`tools/verify_monster_material_profiles.py` checks exact source/texture identity,
native surface features, recipes and species coverage. Its invalid fixtures reject
unsupported surface changes rather than silently dropping them.
`tools/verify_monster_material_runtime.gd` checks bindings, retained native
surfaces, idempotence and cache release. `tools/verify_monster_mechanics_contract.gd`
checks attack ownership and geometry independently of a rendered world.

`tools/run_monster_vitality_capture.py` records matched original, identity and
candidate frames in real constructed levels, using disposable data and an owned
non-input desktop. Runtime scripts, data, shaders and declared model inputs are
hashed before and after observation.
Controlled placement and suspended comparison scenes are recorded explicitly.
The optional mechanics module sends ordinary keyboard/mouse or live touch-control
events and records actual damage, parry, miss, interruption and obstruction
boundaries. It does not inject damage, refill health or award campaign progress.

These observations are source-authoring evidence. A frozen-scene shader timing
diagnostic does not establish representative route performance. Frozen-export
checks, publication and user visual acceptance are recorded separately in the
release evidence under `art_source/art_recovery_v2/evidence/monster_vitality_20261118`.
The 960×540 touch window retains the production 1280×720 internal canvas. Raw
input points are mapped into window coordinates; captured render frames remain
1280×720. Both dimensions are checked and recorded. This does not establish
physical-phone coverage.
