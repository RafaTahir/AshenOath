"""Pure acceptance of matched, nonfrozen source-level route observations."""
from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
import statistics

VIEWPORTS = {(1280, 720), (960, 540)}
ZONES = ("greyfen", "wychwood")
ROUTE_ID = "monster_live_route_v2_south_trail"
CHECKPOINTS = {"greyfen": ["start", "move_forward", "idle", "move_back", "move_left", "move_right"],
               "wychwood": ["start", "move_forward", "block", "move_back", "move_forward", "block", "move_back"]}
INPUT_PAIRS = [("light_attack", 2), ("move_forward", 75), ("move_back", 75), ("move_left", 38),
               ("move_right", 38), ("move_forward", 30), ("block", 180), ("move_back", 30),
               ("move_forward", 30), ("block", 180), ("move_back", 30)]


def number(value) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value)


def percentile(values: list[float], fraction: float) -> float:
    ordered = sorted(values)
    if not ordered:
        raise ValueError("empty frame sequence")
    return ordered[min(len(ordered) - 1, int(len(ordered) * fraction))]


def _compare(observations: list[dict], expected_viewports: set[tuple], repeats: range, enforce_performance: bool) -> dict:
    """Reject incomplete, paced, drifted, errored or slower matched matrices."""
    issues: list[str] = []
    indexed: dict[tuple, dict] = {}
    configurations: dict[tuple, dict] = {}
    script_hashes: set[str] = set()
    source_hashes: dict[str, set[str]] = {"baseline": set(), "candidate": set()}
    if not isinstance(observations, list) or any(not isinstance(item, dict) or not isinstance(item.get("report"), dict) for item in observations):
        return {"passed": False, "issues": ["Malformed observation matrix"], "comparisons": []}
    for item in observations:
        version, repeat, report = item.get("version"), item.get("repeat"), item.get("report", {})
        viewport = tuple(report.get("viewport", []))
        key = (viewport, version, repeat)
        label = str(key)
        if viewport not in expected_viewports or version not in source_hashes or type(repeat) is not int or repeat not in repeats:
            issues.append("Invalid observation identity: " + label)
            continue
        if key in indexed:
            issues.append("Duplicate observation: " + label)
            continue
        indexed[key] = report
        script_hashes.add(str(item.get("qa_script_sha256", "")))
        source_hashes[version].add(str(item.get("source_snapshot_sha256", "")))
        if report.get("kind") != "live_route_performance" or report.get("route_id") != ROUTE_ID:
            issues.append("Unknown route/report: " + label)
        if report.get("passed") is not True or report.get("failures") or report.get("engine_errors"):
            issues.append("Runtime failure: " + label)
        if report.get("physical_device_coverage") is not False or report.get("frozen_export_acceptance") is not False:
            issues.append("Source/device scope claims changed: " + label)
        if "fixture_pool_scope" in report or report.get("actors_frozen") or report.get("camera_override"):
            issues.append("Staged/frozen diagnostic cannot be a live route observation: " + label)
        events = report.get("inputs", [])
        if not isinstance(events, list) or len(events) != len(INPUT_PAIRS) * 2 or any(not isinstance(event, dict) for event in events):
            issues.append("Missing normal input-event schedule: " + label)
        else:
            for index, (action, ticks) in enumerate(INPUT_PAIRS):
                down, up = events[index*2:index*2+2]
                if down.get("action") != action or up.get("action") != action or down.get("pressed") is not True or up.get("pressed") is not False \
                        or type(down.get("tick")) is not int or type(up.get("tick")) is not int or up["tick"]-down["tick"] != ticks \
                        or down.get("touch") != (viewport == (960,540)) or up.get("touch") != (viewport == (960,540)):
                    issues.append("Input route/duration differs: " + label)
        rows = report.get("segments", [])
        if not isinstance(rows, list) or any(not isinstance(row, dict) for row in rows):
            issues.append("Malformed segment list: " + label)
            continue
        if [row.get("zone") for row in rows] != list(ZONES):
            issues.append("Missing/reordered route segments: " + label)
            continue
        for row in rows:
            zone = row["zone"]
            scope = label + " " + zone
            config = row.get("configuration", {})
            expected = {"viewport": list(viewport), "frame_limit": 0, "vsync": 0, "physics_hz": 30,
                        "time_scale": 1.0, "paused": False, "day_locked": False, "quality": "balanced",
                        "resolution_scale": 1.0, "shadow_quality": 0, "foliage_density": 1, "visual_density": 1,
                        "window_client_size":list(viewport),"internal_viewport":[1280,720],"raw_render_size":[1280,720],
                        "coordinate_contract_valid":True,"coordinate_policy":"production_internal_canvas_with_native_window_stretch"}
            if any(config.get(name) != value for name, value in expected.items()) or config.get("renderer") != "gl_compatibility":
                issues.append("Effective render/simulation configuration changed: " + scope)
            if not isinstance(config.get("adapter"), str) or not config["adapter"].strip():
                issues.append("Missing measured graphics adapter: " + scope)
            if config != row.get("configuration_end"):
                issues.append("Configuration changed within segment: " + scope)
            config_key = (viewport, zone)
            if config_key in configurations and configurations[config_key] != config:
                issues.append("Unmatched configuration/adapter: " + scope)
            configurations[config_key] = config
            frames = row.get("frames", [])
            if not isinstance(frames, list) or len(frames) < 30 or any(not isinstance(frame, list) or len(frame) != 6 or
                                       not all(number(value) and value >= 0 for value in frame) or frame[0] <= 0 for frame in frames):
                issues.append("Missing/nonfinite/raw frame samples: " + scope)
            points = row.get("checkpoints", [])
            if not isinstance(points, list) or any(not isinstance(point, dict) for point in points):
                issues.append("Malformed checkpoint list: " + scope)
                continue
            if [point.get("label") for point in points] != CHECKPOINTS[zone]:
                issues.append("Input route did not complete: " + scope)
            for point in points:
                for field in ("player", "camera", "camera_rotation"):
                    vector = point.get(field)
                    if not isinstance(vector, list) or len(vector) != 3 or not all(number(value) for value in vector):
                        issues.append("Invalid checkpoint geometry: " + scope)
                if point.get("input_context") != "gameplay" or point.get("player_physics") is not True:
                    issues.append("Native player/input owner was not running: " + scope)
                if not number(point.get("health")) or point["health"] <= 25:
                    issues.append("Player safety/death invalidated route: " + scope)
                if not number(point.get("world_minutes")) or not isinstance(point.get("weather"), str):
                    issues.append("Missing/nonfinite world environment: " + scope)
            vectors = [point.get("player") for point in points]
            if all(isinstance(vector, list) and len(vector) == 3 and all(number(value) for value in vector) for vector in vectors):
                travelled = sum(math.dist(left, right) for left, right in zip(vectors, vectors[1:]))
                if travelled < (3.0 if zone == "greyfen" else 6.0):
                    issues.append("Blocked/stationary run did not travel the representative route: " + scope)
            roster = row.get("roster_start", [])
            if zone == "wychwood" and not any(actor.get("active") and not actor.get("dead") and actor.get("physics") for actor in roster):
                issues.append("No naturally active monster: " + scope)
            if any(actor.get("dead") for actor in row.get("roster_end", [])):
                issues.append("Actor death changed route workload: " + scope)
    expected_keys = {(viewport, version, repeat) for viewport in expected_viewports for version in source_hashes for repeat in repeats}
    if set(indexed) != expected_keys:
        issues.append(f"Exactly {len(repeats)} baseline and candidate runs per requested viewport are required")
    if len(script_hashes) != 1 or "" in script_hashes:
        issues.append("The identical hash-listed QA script must run on both versions")
    if any(len(values) != 1 or "" in values for values in source_hashes.values()):
        issues.append("Source snapshot changed between repetitions")
    comparisons = []
    if not issues:
        for viewport in sorted(expected_viewports):
            reference = indexed[(viewport, "baseline", 0)]
            for zone_index, zone in enumerate(ZONES):
                base_row = reference["segments"][zone_index]
                metrics = {version: {"p50_ms": [], "p95_ms": []} for version in source_hashes}
                for version in source_hashes:
                    for repeat in repeats:
                        row = indexed[(viewport, version, repeat)]["segments"][zone_index]
                        if row["roster_start"] != base_row["roster_start"]:
                            issues.append(f"Unmatched initial actor workload: {viewport} {zone} {version} {repeat}")
                        for before, after in zip(base_row["checkpoints"], row["checkpoints"]):
                            if math.dist(before["player"], after["player"]) > 1.0 or math.dist(before["camera"], after["camera"]) > 1.5:
                                issues.append(f"Route/camera drift: {viewport} {zone} {version} {repeat} {after['label']}")
                            angle = [abs((x-y+math.pi) % (2*math.pi)-math.pi) for x, y in zip(before["camera_rotation"], after["camera_rotation"])]
                            if max(angle) > .12 or before.get("weather") != after.get("weather") or abs(before["world_minutes"]-after["world_minutes"]) > 1.0:
                                issues.append(f"Camera/environment drift: {viewport} {zone} {version} {repeat} {after['label']}")
                        wall = [frame[0] for frame in row["frames"]]
                        metrics[version]["p50_ms"].append(percentile(wall, .50))
                        metrics[version]["p95_ms"].append(percentile(wall, .95))
                for metric in ("p50_ms", "p95_ms"):
                    baseline = statistics.median(metrics["baseline"][metric])
                    candidate = statistics.median(metrics["candidate"][metric])
                    within = candidate <= baseline * 1.10 + 1.e-9
                    comparisons.append({"viewport": list(viewport), "zone": zone, "metric": metric,
                                        "baseline": baseline, "candidate": candidate, "regression": candidate/baseline-1,
                                        "within_ten_percent": within})
                    if not within and enforce_performance: issues.append(f"Performance regression above 10%: {viewport} {zone} {metric}")
    return {"passed": not issues, "issues": issues, "comparisons": comparisons,
            "statistic": "median of three per-run p50 and p95 wall-frame times, per zone/viewport",
            "scope": "matched native live-route source observation; adjusted prerequisite-only 1c baseline; synthetic touch, no physical phone or frozen-export acceptance",
            "gpu_zero_means": "unavailable, not free rendering"}


def compare(observations: list[dict]) -> dict:
    """Full acceptance always requires twelve observations across both windows."""
    return _compare(observations, VIEWPORTS, range(3), True)


def validate_pilot_pair(observations: list[dict]) -> dict:
    """One real A/B pair validates route matching; it cannot accept performance."""
    if not isinstance(observations, list) or len(observations)!=2:
        return {"valid_for_matched_sampling":False,"issues":["Pilot requires one baseline/candidate pair"],"performance_acceptance":False}
    viewport = tuple(observations[0].get("report",{}).get("viewport",[]))
    if viewport not in VIEWPORTS:
        return {"valid_for_matched_sampling":False,"issues":["Unknown pilot window"],"performance_acceptance":False}
    result = _compare(observations,{viewport},range(1),False)
    result["valid_for_matched_sampling"] = result.pop("passed")
    result["performance_acceptance"] = False
    result["statistic"] = "one paired baseline/candidate observation; workload and route matching only"
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("matrix", type=Path)
    args = parser.parse_args()
    result = compare(json.loads(args.matrix.read_text(encoding="utf-8")))
    print(json.dumps(result, indent=2))
    return 0 if result["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
