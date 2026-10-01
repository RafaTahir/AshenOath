# WORLD-001 Ghoulkin asset decision (2026-09-29)

Status: occupied Wychwood arena remains visually rejected. Recovery acceptance
is 27/37; this investigation does not close WORLD-001 or MON-001.

The active `ghoulkin` enemy resolves through `enemy_ai.gd` to
`ghoulkin_creature`, which the visual/runtime manifests map to Quaternius
`Ghost.glb`. Its flying animation and disconnected lower silhouette explain
the skull-and-hands appearance in the fixed day/night arena captures. This is
an asset-direction problem, not a renderer, collision, or terrain failure.

A one-line trial mapped the same actor to the retained `Skeleton.fbx`. It
parsed and captured in the same arena camera, but visual review rejected its
juvenile generic skeleton silhouette. The trial mapping was removed; no
manifest, combat, AI, population, or story change was adopted. The existing
`monster_family_manifest.json` skeleton declaration is not proof of visual
acceptance. `Creep.glb` is already the distinct Rootbound Colossus body and
would not establish a separate Ghoulkin identity. No other retained source is
accepted as the final grounded cursed-human Ghoulkin by this evidence.

Retain the integrated Wychwood ground. Do not swap another unrelated monster
or call the occupied arena approved. The next Ghoulkin implementation must
author and validate a complete grounded cursed-human body, compatible
animations and materials, and its Web payload before changing active role
mappings. Its day/night gameplay-camera and motion captures must pass. In the
meantime, advance the independent Greyfen street/support visual cells; the
cemetery backdrop remains parked after two failed composition approaches.

Diagnostic trial captures: `.release-gate/world001_grounded_ghoul_candidate_20260929/`.
No Web export, commit, push, merge, or deployment was performed.
