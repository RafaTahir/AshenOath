#!/usr/bin/env python3
"""Require fresh Codex-reviewed visual evidence, or legacy human evidence."""

from __future__ import annotations

import argparse
import json
import subprocess
from pathlib import Path

from PIL import Image, ImageStat


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("project", type=Path)
    parser.add_argument("--manifest", type=Path)
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    project = args.project.resolve()
    manifest_path = (args.manifest or project / "Development_Gallery" / "qa_003_approval_manifest.json").resolve()
    failures: list[str] = []
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        print(f"QA-006: FAIL - cannot read approval manifest: {error}")
        return 1
    required = [view for view in manifest.get("views", []) if bool(view.get("required", True))]
    policy = manifest.get("policy", {})
    codex_review = str(policy.get("visual_review", "human")).lower() == "codex"
    if not required:
        failures.append("manifest has no required views")
    if not codex_review:
        failures.append("manifest still requires legacy human approval; set policy.visual_review to codex")
    source_paths = []
    for root in manifest.get("runtime_source_roots", ["scripts", "scenes", "data", "project.godot"]):
        path = project / root
        if path.is_file():
            source_paths.append(path)
        elif path.is_dir():
            source_paths.extend(child for child in path.rglob("*") if child.is_file())
    newest_source = max(source_paths, key=lambda item: item.stat().st_mtime_ns) if source_paths else None
    gallery = project / "Development_Gallery" / "screenshots"
    for view in required:
        view_id = str(view.get("id", "unknown"))
        if view.get("status") != "approved":
            failures.append(f"{view_id} is not Codex-reviewed")
        reviewer = str(view.get("reviewer", "")).strip()
        if not reviewer:
            failures.append(f"{view_id} has no visual reviewer")
        elif codex_review and "codex" not in reviewer.lower():
            failures.append(f"{view_id} reviewer is not Codex under the active policy")
        matches = [candidate for candidate in gallery.glob(str(view.get("current_glob", ""))) if candidate.is_file()]
        image = max(matches, key=lambda item: item.stat().st_mtime_ns) if matches else None
        if image is None:
            failures.append(f"{view_id} has no current screenshot")
            continue
        if newest_source is not None and image.stat().st_mtime_ns < newest_source.stat().st_mtime_ns:
            failures.append(f"{view_id} screenshot predates current source")
        try:
            with Image.open(image) as opened:
                rgb = opened.convert("RGB")
                expected = tuple(view.get("expected_size", []))
                if expected and rgb.size != expected:
                    failures.append(f"{view_id} has dimensions {list(rgb.size)}, expected {list(expected)}")
                stat = ImageStat.Stat(rgb)
                means = stat.mean
                variance = max(stat.var)
                luminance = rgb.convert("L")
                histogram = luminance.histogram()
                total = float(rgb.width * rgb.height)
                bright_ratio = sum(histogram[248:]) / total
                heuristics = view.get("heuristics", {})
                if sum(means) / 3.0 < float(heuristics.get("min_mean_luminance", 1.5)):
                    failures.append(f"{view_id} appears black")
                if variance < float(heuristics.get("min_channel_variance", 4.0)):
                    failures.append(f"{view_id} appears visually flat")
                if bright_ratio > float(heuristics.get("max_bright_ratio", 0.985)):
                    failures.append(f"{view_id} appears overexposed")
        except (OSError, ValueError) as error:
            failures.append(f"{view_id} cannot be inspected: {error}")
        if not codex_review:
            baseline = view.get("baseline") or {}
            if baseline.get("status") != "approved" or not str(baseline.get("path", "")).strip():
                failures.append(f"{view_id} has no approved perceptual baseline")
    revision = str(manifest.get("capture_source_revision", "")).strip()
    if not revision:
        failures.append("capture_source_revision is missing")
    else:
        if not codex_review:
            repo_root = project.parents[1]
            project_relative = project.relative_to(repo_root)
            git_roots = [str(project_relative / root).replace("\\", "/") for root in ["scripts", "scenes", "data", "project.godot"]]
            comparison = subprocess.run(["git", "-C", str(repo_root), "diff", "--quiet", revision, "--", *git_roots], capture_output=True, text=True, check=False)
            if comparison.returncode == 1:
                failures.append(f"runtime sources changed since capture revision {revision}")
            elif comparison.returncode not in (0,):
                failures.append(f"cannot compare capture revision {revision}: {comparison.stderr.strip()}")
    report = {
        "schema_version": 1,
        "status": "fail" if failures else "pass",
        "required_views": len(required),
        "failures": failures,
        "manifest": str(manifest_path),
    }
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    if failures:
        for failure in failures:
            print(f"QA-006: FAIL - {failure}")
        return 1
    print(f"QA-006: PASS - {len(required)} required views have fresh Codex-reviewed evidence")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
