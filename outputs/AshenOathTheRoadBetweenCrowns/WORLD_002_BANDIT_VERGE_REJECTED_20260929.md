# WORLD-002 Bandit Road verge candidate rejected (2026-09-29)

A single scene-level trial added integrated, nearly flush road verges to the authored Bandit Road mesh and moved the two existing torches toward the guard line. It did not change collision, the road corridor, actor population, or the light count.

The graphical 1280x720 matching-camera arrival-day and arrival-night captures under `D:\Temp\AshenOath\world002_bandit_verge_candidate_20260929\captures` show obvious parallel terrain striping. The broad road remains flat and the night composition remains weak. The candidate is visually rejected. Only those trial code changes were removed, and the deterministic authored mesh was rebuilt to its prior 13,926 bytes and SHA-256 `d3dd7d419ad7796243373b3851144531412168d32a3eed9de1267b03e064308b`. The affected campaign wilds resource/collision contract passes again at `D:\Temp\AshenOath\world002_bandit_scene_restore_verify_20260929.log`.

No runtime asset mapping, export, browser artifact, accepted ticket, commit, push, or production deployment changed. Next Bandit Road pass needs materially different authored terrain/lighting and accepted guards; do not repeat low, colored-strip meshes or isolated torch repositioning.
