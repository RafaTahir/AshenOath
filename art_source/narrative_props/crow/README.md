# Oren’s painted brass token

The retained rig has no moving bones. The disc measures 60 × 63 mm and the cord extends to about 90 mm above its centre. The face normal is local +Z, up is +Y, and the root sits in the middle of the disc. Use the exposed scenes’ `CordAnchor` for a hanging attachment, `Grip` for the back of the token and `InspectFocus` for the crow and name. For a flat display, rotate the +Z face towards world up.

The four scenes in `res://assets/narrative_props/crow/` correspond to the pictured object at different points in the novel.

| Scene | Visible details |
| --- | --- |
| OrenPaintedCrow.tscn | Oren’s black cart-paint crow, brass eye, the nail-cleared AVEL and Sella’s knotted red cord |
| OrenShrineCrow.tscn | Adds Anwen’s grey burial thread around Sella’s knot |
| OrenRecoveredCrow.tscn | Adds two flattened wire turns across the thread as found at the thorn |
| OrenWrappedCrow.tscn | Closed grey folded packet with the cord tucked inside |

To rebuild in an empty working directory:

1. Run `python paint_crow.py BUILD_DIR` with Pillow and NumPy.
2. Run `blender --background --factory-startup --python author_crow.py -- BUILD_DIR`.
3. Run `godot --headless --path EMPTY_GODOT_PROJECT --script PATH/TO/cook_crow.gd -- BUILD_DIR TARGET_MESH_DIR` with Godot 4.6.3. Pass absolute paths. The target is the runtime crow folder containing the scenes above.
4. Retain the generated `OrensPaintedCrow.blend` here. Its image textures are packed. All five named component meshes remain independently editable.

`CrowParts.glb` and the two PNGs in the working directory are build intermediates. The engine loads the exported .res meshes directly. The opaque parcel displays only its visible wrapping.
