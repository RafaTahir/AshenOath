#!/usr/bin/env python3
"""Validate the reproducible QA-013 baseline ledger.

This gate validates evidence integrity for either the preserved historical
baseline or a current identical-camera recapture. It never turns screenshots
into final visual approval.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image, ImageStat


MANIFEST = "qa_013_baseline_manifest.json"
REPORT = ".release-gate/qa_013_baseline.json"
REQUIRED_ZONES = ("greyfen", "wychwood", "wychwood_combat", "vargan_court", "record_hall", "hart_glade")
REQUIRED_TIMINGS = (
    "scene_ready",
    "new_game",
    "transition_wychwood",
    "transition_vargan_approach",
    "transition_hart_glade",
)


def main() -> int:
    project = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else Path(__file__).resolve().parents[1]
    errors: list[str] = []
    try:
        manifest = json.loads((project / MANIFEST).read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        print(f"QA-013 BASELINE VERIFIER: FAIL - {exc}")
        return 1

    if manifest.get("schema_version") != 1 or manifest.get("ticket") != "QA-013":
        errors.append("baseline manifest schema or ticket identity is invalid")
    current_capture = manifest.get("status") == "current_recapture_recorded_visual_review_pending"
    historical_capture = manifest.get("status") == "baseline_recorded_recapture_pending"
    if not current_capture and not historical_capture:
        errors.append("baseline status must distinguish historical evidence from current recapture")
    if manifest.get("environment", {}).get("gameplay_viewport") != [1280, 720]:
        errors.append("baseline gameplay viewport is not native 1280x720")
    if manifest.get("environment", {}).get("menu_viewport") != [1920, 1080]:
        errors.append("baseline menu viewport is not 1920x1080")
    fresh_capture_required = manifest.get("environment", {}).get("fresh_capture_required")
    if current_capture and fresh_capture_required is not False:
        errors.append("current recapture must clear the fresh capture requirement")
    if historical_capture and fresh_capture_required is not True:
        errors.append("historical baseline must retain the fresh capture requirement")

    views = manifest.get("required_views", [])
    if len(views) != 9:
        errors.append("baseline must contain exactly nine required views")
    for view in views:
        if not isinstance(view, dict):
            errors.append("baseline view row must be an object")
            continue
        path = project / str(view.get("path", ""))
        valid_view_statuses = {"preserved_historical", "current_recaptured_visual_review_pending"}
        if view.get("status") not in valid_view_statuses:
            errors.append(f"view {view.get('id')} has an invalid evidence status")
        if not path.is_file():
            errors.append(f"baseline image missing: {path}")
            continue
        try:
            with Image.open(path) as image:
                if list(image.size) != view.get("size"):
                    errors.append(f"baseline image dimensions differ: {path.name}")
                variance = max(ImageStat.Stat(image.convert("RGB").resize((64, 36))).var)
                if variance < 12.0:
                    errors.append(f"baseline image is blank or visually flat: {path.name}")
        except Exception as exc:
            errors.append(f"baseline image cannot be read {path.name}: {exc}")

    timings = manifest.get("timings_ms", {})
    for key in REQUIRED_TIMINGS:
        value = timings.get(key)
        if not isinstance(value, (int, float)) or value < 0:
            errors.append(f"missing non-negative timing: {key}")
    zones = manifest.get("zones", {})
    for zone_id in REQUIRED_ZONES:
        row = zones.get(zone_id, {})
        for key in ("average_fps", "one_percent_low_fps", "frames", "nodes", "draw_calls", "primitives", "static_memory_bytes"):
            if not isinstance(row.get(key), (int, float)) or row[key] <= 0:
                errors.append(f"zone {zone_id} missing positive {key}")

    for evidence in manifest.get("evidence_sources", []):
        if not (project / str(evidence)).is_file():
            errors.append(f"evidence source missing: {evidence}")
    if not manifest.get("known_debt"):
        errors.append("baseline must record known debt")

    report = {
        "ticket": "QA-013",
        "status": "pass" if not errors else "fail",
        "fresh_capture": "current_recapture_present" if current_capture else "blocked_missing_godot",
        "historical_evidence_preserved": not bool(errors),
        "errors": errors,
    }
    path = project / REPORT
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    if errors:
        print("QA-013 BASELINE VERIFIER: FAIL")
        for error in errors:
            print(f"- {error}")
        return 1
    print("QA-013 BASELINE VERIFIER: PASS - current evidence is intact; final visual approval remains separate")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
