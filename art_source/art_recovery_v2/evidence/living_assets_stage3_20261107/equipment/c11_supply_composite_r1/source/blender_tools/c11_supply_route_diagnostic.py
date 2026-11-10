"""Measure the standing survivors through the full unmodified native route."""
import hashlib
import json


def placement_identity(candidate):
    placement = {"palm_vertex": int(candidate["hand_id"]), "prop_primary_vertex": int(candidate["anchor_index"]),
                 "basis_columns": [[float(value) for value in column] for column in candidate["basis"].col],
                 "translation_in_scaled_hand_m": [float(value) for value in candidate["translation"]],
                 "contact_in_scaled_hand_m": [float(value) for value in candidate["contact"]],
                 "anchor_in_prop_m": [float(value) for value in candidate["anchor"]]}
    token = hashlib.sha256(json.dumps(placement, sort_keys=True, allow_nan=False).encode("utf-8")).hexdigest()
    return {"sha256": token, **placement}


def scan_route(candidates, samples, scale, frame, body_geometry, clearance, face_owner, report, record):
    """Retain every collision instead of removing failed candidates from later samples."""
    rows = [{"placement": placement_identity(candidate), "frames": []} for candidate in candidates]
    report.update(standing_survivors=len(rows), native_frame_count=len(samples), stable_hand_weight=1.0,
                  diagnostic_only=True, source_fit_accepted=False, placements=rows)
    for index, sample in enumerate(samples):
        points, _ = frame(sample, scale)
        geometry = body_geometry(points)
        for candidate, result in zip(candidates, rows):
            candidate.pop("intersections", None)
            problem, distance = clearance(candidate, points, geometry)
            pairs = candidate.get("intersections", [])
            result["frames"].append({"sample": index, "time": sample["time"], "visible": sample["prop_visible"],
                "pose_weight": sample["pose_weight"], "speed_mps": sample["speed_mps"],
                "problem": problem, "contact_error_m": distance, "overlap_pairs_count": len(pairs),
                "overlap_pairs": [{"body_face": int(body), "prop_face": int(prop), "dominant_bone": face_owner(body)}
                                  for body, prop in sorted(pairs)[:12]]})
        if (index + 1) % 120 == 0:
            record()
    for candidate, result in zip(candidates, rows):
        if result["placement"] != placement_identity(candidate):
            raise ValueError("Diagnostic changed the measured placement")
        visible = [sample for sample in result["frames"] if sample["visible"]]
        stable = [sample for sample in visible if sample["pose_weight"] >= report["stable_hand_weight"]]
        failures = [sample for sample in visible if sample["problem"]]
        stable_failures = [sample for sample in stable if sample["problem"]]
        result["summary"] = {"samples": len(result["frames"]), "visible": len(visible), "stable_visible": len(stable),
                             "visible_failures": len(failures), "stable_visible_failures": len(stable_failures),
                             "first_stable_visible_sample": stable[0]["sample"] if stable else None,
                             "first_stable_failure": stable_failures[0]["sample"] if stable_failures else None,
                             "last_visible_failure": failures[-1]["sample"] if failures else None,
                             "maximum_visible_contact_error_m": max(row["contact_error_m"] for row in visible)}
    record()
