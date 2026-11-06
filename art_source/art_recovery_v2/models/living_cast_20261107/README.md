# Opening cast: retained source and native motion

This directory contains editable animation derivatives of the actual prepared
Anwen (C01), Tor (C04), Mira (C03) and Rook (C02) actors. Their production model
files, bone rest transforms, mesh vertices, scale and collisions are unchanged.
The full actor GLBs here are review carriers, not runtime dependencies.

Each actor has five native clips: `Life_Idle_A` (6 seconds), `Life_Idle_B`
(8 seconds), `Life_Work`, `Life_Listen` and `Life_Speak` (4 seconds each).
The work contact is phase 0.50. The lower body stays in its retained Idle pose;
workstation alignment and interruption remain with the existing runtime owners.
The body action does not own facial joints or physics root motion.

Rebuild from the repository root, one heavy process at a time on the 8 GB host:

1. Run Godot headless on the game project with
   `--script art_source/art_recovery_v2/tools/export_living_cast_baseline.gd`
   using the absolute script path. This exports the exact prepared actor and its
   real attached Idle. Existing baseline files are retained and hash checked.
2. Run Blender in background/factory mode with
   `--python art_source/art_recovery_v2/tools/author_rook_station_satchel.py`.
3. Run Blender with
   `--python art_source/art_recovery_v2/tools/author_living_cast_20261107.py -- --asset C01 --render`,
   replacing the asset ID for each actor. `--refresh-work` reauthors only the
   work action from the retained baseline; the other four actions stay intact.
   A per-asset `.hold` file stops before import for host scheduling and is never
   part of the authored or shipped result.
4. Run `verify_living_cast_sources.py --asset C01 C04 C03 C02` with Python.
5. Run Godot headless on the project with
   `--script res://tools/build_living_cast_libraries.gd`, followed by
   `--script res://tools/build_living_cast_station_props.gd`.

The animation compiler checks production/carrier hashes, all retained bone rest
transforms and the five clip identities/durations. It rewrites track prefixes to
the actual prepared skeleton, excludes face/object-transform tracks, retains a
proven-static skeletal root basis, and emits compressed
actor-owned `life_Cxx.res` libraries. The prop compiler emits an immutable body,
attached strap and independent `SatchelKnot` in the supported station scene.

Mira and Rook use actual retained palm vertices calibrated in native Idle with
at least 90% hand-bone weight. Their work poses target those surfaces while
retaining wrist orientation. The compiler converts recorded Blender world
probes through the imported Godot Work pose, verifies wrist FK within 2 mm, and
stores finite nonzero Godot-local contact probes and the measurement method.

Blender sources pack their image data before save. Receipts record inputs,
hashes, sample rate, source bone positions and runtime paths. Clay images show
pose/silhouette and are separate from in-game contact, garment, visibility,
performance and user acceptance. `source_verification.json` proves source
contracts only; it does not assert those later acceptance checks.

Do not package `.blend`, `.blend1`, source/review GLBs, preview images or baseline
carriers into the Web packs. Runtime ownership is the four prepared actor packs
and Greyfen's station scene dependency closure.
