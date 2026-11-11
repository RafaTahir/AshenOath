# Lower-face repair

Baseline: `b4b52e4b6a87a0a346618484fdabd405b2980fdf`, published as
`combined-loading-cast-20261111-ba93115-r6`.

The legacy human authoring tool fitted its neck ellipse through `Head + 0.025m`.
That range included the mandible. A unique retained source UV shows roughly
60 mm of forward chin projection lost on Kael and Tor. The source generator now
limits fitting to the lower neck, below `Head - 0.035m`.

Eleven affected sources were repaired individually: Kael, Rook, Mira, Tor,
Toma, Senn, Edric, Vale, Merrow, Nessa and Nera. Each has a new editable Blender
master, the exact original runtime GLB, a repaired GLB, a source recipe and a
certificate under `models/lower_face_repair_20261111`. The inverse-clamp
displacement preserves the later individual sculpts. Beard attachments follow
the same retained head triangles. POSITION bounds and neighboring normals are
updated; topology, skins, UVs, material/texture data and animation data stay
protected by the source comparison. No additional vertices, bones or processing
loops were introduced. Post-repair frame time has not been measured.

Anwen and Elna use a separate head source and were not changed by this repair.
Anwen's bone data was captured, but the care scene overrode close-up framing;
the single diagnostic does not establish her full-face appearance.

The one authorized game process used the exact frozen published packs with a
disposable profile at 1280 x 720. Kael and Tor retained the distorted chin with
the facial modifier disabled and facial bones restored to rest. This establishes
an authored geometry defect. The diagnostic's successful completion is not
post-repair gameplay or visual acceptance. No post-repair rendered, browser,
touch, sleep, combat or conversation run was performed.

The strict admission compares actual source and prepared bytes. It permits the
new scenes to retain the exact eleven existing life libraries while preserving
the original model/prepared hashes in all measured motion records. The 19
affected native/route records remain predecessor evidence; 71 affected aliases
retain consistent ownership. These records establish rig, hand and animation
fidelity. Appearance and clearance around the restored chin, including cups,
have not been observed after the repair.

Four beard certificates also preserve their complete pre-canonicalization
certificate and original float32 neutral-bind anchor values. A separately
labelled proof is derived from the exact raw GLB triangles in float64. This
resolves coordinate-rounding differences without changing geometry or gate
tolerances. It is source metadata, not a new runtime observation.

For reproduction, use the archived recipe with a disposable checkout of the
baseline commit and the recorded original editable source. Restore the exact
archived donor/design inputs to their original logical locations first. The
runtime GLB is patched deterministically from the recorded baseline; it is not
re-exported through a different animation or material conversion. The metadata
augmenter and shared admission helper are retained alongside the maintained
art tools. Exact input bytes are archived to avoid platform newline conversion.

Publication identity and user acceptance are recorded separately in the local
release receipt. Source admission does not assert user visual acceptance.
