# Props for the novel adaptation

Look up a default or variant scene in `res://assets/narrative_props/library.json` and instantiate that PackedScene. Each scene uses metres and contains presentation only. The caller controls placement, custody and transitions.

| Prop | Placement and visible detail |
| --- | --- |
| Oren’s crow | The origin lies at the centre of the pierced disc. The black cart-paint crow and scratched AVEL face local +Z. Align the Grip marker with a palm or the CordAnchor with a branch. The shrine and recovered forms add the thread and flattened wire in sequence. The wrapped form conceals the token. |
| Harl’s cart bell | The lip rests at Y = 0. Align Grip with the carrying hand. FiledMarks identifies the rubbed patch near the front lip. The default has an empty striker eye. The cemetery form adds Mira’s waxed wool and a temporary striker that can swing about StrikerPivot. The returned form keeps just a trace of wax by the handle. Its forged iron uses the metallic, roughness and base colour of the existing bell clasp. |
| Tor’s left wrist brace | Instance at identity on a BoneAttachment3D bound to lowerarm_l on C04 Tor. The wooden splints and linen sit in forearm bind space, with WristCrease toward the hand. The separate torso sling described in the novel is outside this wrist prop. |
| Merrow’s strongbox | Place the root on the floor under the bench. Front is local −Z. The clerk and household locks each expose a KeySocket. Positive local X rotation opens LidHinge. The PriedCorner morph flexes the damaged corner while the locks stay seated. CoinTray and WrappedVolume can be removed independently. |

The four subdirectories retain the editable Blender masters and their build scripts. Each script describes its inputs and export command. Their source references are the original novel and adaptation companion supplied with the 2026-11-27 edition, alongside the existing Greyfen material and actor assets.

After importing the game project with Godot 4.6, run `godot --headless --path <project> --script <absolute-path-to-verify_props.gd>` to load all nine forms, check their geometry and materials, and exercise their attachment and articulation points.
