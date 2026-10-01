# Bandit Road Worn-Surface Trial - Rejected

Recovery acceptance remains **27/37**. The retained checkpoint and existing
Bandit Road landscape are unchanged after this trial.

One road/shoulder candidate replaced the existing continuous road mesh with
irregular cross-section colors and scattered eroded-ground patches. The
visual-only candidate compiled and was captured from the existing genuine
pre-fight save at native 1280x720. Its established arrival-day camera showed
the road losing its readable surface while the ground patches became obvious
dark ovals. This is worse than the retained frame, so no night or broader
acceptance was inferred.

Evidence: `D:/Temp/AshenOath/bandit_scene_candidate_v2/captures/arrival_day.png`
and `capture_report.json`. The first capture attempt used the wrong isolated
profile root and did not load the save; the corrected attempt exited 0 and
captured the intended state. The direct wilds verifier failed only on the
candidate mesh's expected manifest hash/size drift before rejection.

Both candidate source edits were removed. Rebuilding `--bandit-only` restored
the retained `Campaign_bandit_road_Landscape.res` to SHA-256
`d3dd7d419ad7796243373b3851144531412168d32a3eed9de1267b03e064308b`,
exactly matching the current asset manifest. No manifest, Web export,
collision, gameplay, or production artifact was changed. The remaining
Bandit Road cell needs authored topography and a readable road together, not
another flat tint or oval-overlay pass.
