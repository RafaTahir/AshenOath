# WORLD-001 Nightmare Source Audition - Rejected

The CC0 Nightmare Monsters archive was inspected as a possible grounded
Ghoulkin source. The archive remains in scratch under
`D:\Temp\AshenOath\world001_nightmare_asset_audit_20260929`; no file from it
was added to the game or Web export.

- Source: https://opengameart.org/content/nightmare-monsters
- Archive SHA-256: `961c5918c4420382e1dacae3272f2154514540e16b3178ad0abaed42a556f4f1`
- Licensing: bundled `LICENSE.txt` contains CC0; bundled `CREDITS.txt`
  identifies the model and texture authors.
- Candidate: `crawlmaster deluxe.fbx`, plus its supplied material textures.

In a separate Godot 4.6.3 Compatibility project, the FBX imported as one
skinned mesh and a 25-bone skeleton, but supplied **no animation clips**.
The mesh-local bounds were approximately 0.018 x 0.004 x 0.018 metres, under
an armature transform scaled by 100. An initial audition incorrectly ignored
that ancestor transform and produced an off-camera frame. After correcting
the harness to measure global bounds, the 1280x720 capture shows the body:
a flat-white bind pose with no imported texture and a long-necked,
quadrupedal outline. This is neither a production-ready animation/material
source nor the intended recognizable cursed-human Ghoulkin. The rejection is
based on the corrected frame, missing clips, and role mismatch, **not** on
the initial off-camera capture.

Evidence: `D:\Temp\AshenOath\world001_nightmare_asset_audit_20260929\audition\crawlmaster_audition.png`
(corrected global-transform capture) and the isolated import's mesh/skeleton/material
report. The scratch project
and imported files stay outside the repository. No runtime mappings changed.

WORLD-001 remains open. A future Ghoulkin candidate must have an accepted
connected body, working locomotion/attack/death animation and a readable
occupied-arena silhouette before integration. Do not repeat this FBX import
without a materially different animation and proportion pipeline.
