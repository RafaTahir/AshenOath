#!/usr/bin/env python3
"""QA-003 gallery acceptance checks.

This verifier deliberately keeps machine checks and human approval separate.
It never alters captures, baselines, or the approval manifest.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any

try:
    from PIL import Image, ImageChops, ImageStat
except ImportError as error:  # pragma: no cover - environment failure
    raise SystemExit("QA-003 requires Pillow (PIL) to inspect screenshot pixels.") from error


VALID_STATUSES = {"pending", "approved", "rejected"}


@dataclass
class CheckResult:
    view_id: str
    status: str
    image: str | None = None
    message: str = ""
    metrics: dict[str, float] | None = None


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Verify Ashen Oath QA-003 screenshot acceptance metadata.")
    parser.add_argument("project", type=Path, help="Godot project root.")
    parser.add_argument(
        "--manifest",
        type=Path,
        help="Approval manifest. Defaults to Development_Gallery/qa_003_approval_manifest.json.",
    )
    parser.add_argument("--mode", choices=("ticket", "milestone"), default="ticket")
    parser.add_argument(
        "--views",
        help="Comma-separated view IDs for an ordinary changed-view check. Defaults to all manifest views.",
    )
    parser.add_argument("--dry-run", action="store_true", help="Resolve manifest entries without reading image pixels.")
    parser.add_argument("--report", type=Path, help="Optional JSON report path. The verifier writes nothing without this option.")
    return parser.parse_args()


def fail(message: str, failures: list[str]) -> None:
    failures.append(message)
    print(f"QA-003: FAIL - {message}")


def load_manifest(path: Path) -> dict[str, Any]:
    try:
        manifest = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise ValueError(f"cannot read approval manifest {path}: {error}") from error
    if manifest.get("schema_version") != 1:
        raise ValueError("approval manifest schema_version must be 1")
    if not isinstance(manifest.get("views"), list) or not manifest["views"]:
        raise ValueError("approval manifest must contain at least one view")
    return manifest


def resolve_source_paths(project: Path, manifest: dict[str, Any]) -> list[Path]:
    roots = manifest.get("runtime_source_roots", ["scripts", "scenes", "data", "project.godot"])
    paths: list[Path] = []
    for root in roots:
        path = project / root
        if path.is_file():
            paths.append(path)
        elif path.is_dir():
            paths.extend(
                child
                for child in path.rglob("*")
                if child.is_file() and child.suffix.lower() in {".gd", ".tscn", ".json", ".godot", ".tres", ".res"}
            )
    return paths


def runtime_changed_since(project: Path, manifest: dict[str, Any]) -> str | None:
    """Return a stale reason based on source control, falling back to mtimes."""
    revision = manifest.get("capture_source_revision")
    roots = manifest.get("runtime_source_roots", ["scripts", "scenes", "data", "project.godot"])
    repo_root = project.parents[1]
    if revision:
        command = ["git", "-C", str(repo_root), "diff", "--quiet", revision, "--", *roots]
        completed = subprocess.run(command, capture_output=True, text=True, check=False)
        if completed.returncode == 1:
            return f"runtime sources changed since capture revision {revision}"
        if completed.returncode != 0:
            return f"cannot compare capture revision {revision}: {completed.stderr.strip()}"
        status = subprocess.run(
            ["git", "-C", str(repo_root), "status", "--porcelain", "--", *roots],
            capture_output=True,
            text=True,
            check=False,
        )
        if status.returncode != 0:
            return f"cannot inspect runtime source status: {status.stderr.strip()}"
        if status.stdout.strip():
            return f"runtime sources changed since capture revision {revision}"
        return None
    return None


def newest_match(gallery: Path, pattern: str) -> Path | None:
    matches = [candidate for candidate in gallery.glob(pattern) if candidate.is_file()]
    return max(matches, key=lambda candidate: candidate.stat().st_mtime_ns) if matches else None


def image_metrics(path: Path) -> tuple[tuple[int, int], dict[str, float]]:
    with Image.open(path) as source:
        image = source.convert("RGB")
        stat = ImageStat.Stat(image)
        means = stat.mean
        variances = stat.var
        luminance = image.convert("L")
        histogram = luminance.histogram()
        total = float(image.width * image.height)
        dark_ratio = sum(histogram[:8]) / total
        bright_ratio = sum(histogram[248:]) / total
        return image.size, {
            "mean_luminance": round(sum(means) / 3.0, 3),
            "max_channel_variance": round(max(variances), 3),
            "dark_ratio": round(dark_ratio, 5),
            "bright_ratio": round(bright_ratio, 5),
        }


def mean_absolute_difference(current: Path, baseline: Path) -> float:
    with Image.open(current) as current_image, Image.open(baseline) as baseline_image:
        current_rgb = current_image.convert("RGB")
        baseline_rgb = baseline_image.convert("RGB")
        if current_rgb.size != baseline_rgb.size:
            raise ValueError("baseline dimensions differ from the current screenshot")
        difference = ImageChops.difference(current_rgb, baseline_rgb)
        return sum(ImageStat.Stat(difference).mean) / 3.0


def selected_views(manifest: dict[str, Any], requested: str | None) -> list[dict[str, Any]]:
    by_id = {view.get("id"): view for view in manifest["views"]}
    if requested is None:
        return manifest["views"]
    requested_ids = [item.strip() for item in requested.split(",") if item.strip()]
    unknown = [view_id for view_id in requested_ids if view_id not in by_id]
    if unknown:
        raise ValueError("unknown view IDs: " + ", ".join(unknown))
    return [by_id[view_id] for view_id in requested_ids]


def verify_view(
    view: dict[str, Any],
    gallery: Path,
    newest_runtime_source: Path | None,
    runtime_change_reason: str | None,
    has_capture_revision: bool,
    mode: str,
    dry_run: bool,
) -> CheckResult:
    view_id = view.get("id")
    pattern = view.get("current_glob")
    required = bool(view.get("required", True))
    status = view.get("status")
    if not isinstance(view_id, str) or not isinstance(pattern, str):
        return CheckResult(str(view_id), "fail", message="view needs string id and current_glob")
    if status not in VALID_STATUSES:
        return CheckResult(view_id, "fail", message="status must be pending, approved, or rejected")
    if not isinstance(view.get("reviewer", ""), str) or not isinstance(view.get("note", ""), str):
        return CheckResult(view_id, "fail", message="reviewer and note must be strings")
    if status == "approved" and (not view["reviewer"].strip() or not view["note"].strip()):
        return CheckResult(view_id, "fail", message="approved view requires reviewer and note")

    image = newest_match(gallery, pattern)
    if image is None:
        return CheckResult(view_id, "fail" if required else "warn", message=f"no image matches {pattern}")
    if runtime_change_reason:
        return CheckResult(view_id, "fail", str(image), runtime_change_reason)
    if status == "rejected":
        return CheckResult(view_id, "fail", str(image), "human reviewer rejected this view")
    if mode == "milestone" and required and status != "approved":
        return CheckResult(view_id, "fail", str(image), "mandatory milestone view lacks approval")
    if dry_run:
        return CheckResult(view_id, "pass", str(image), "resolved; approval policy satisfied")
    if not has_capture_revision and newest_runtime_source and image.stat().st_mtime_ns < newest_runtime_source.stat().st_mtime_ns:
        return CheckResult(view_id, "fail", str(image), f"stale against {newest_runtime_source.relative_to(gallery.parent.parent)}")

    expected_size = view.get("expected_size")
    try:
        size, metrics = image_metrics(image)
    except (OSError, ValueError) as error:
        return CheckResult(view_id, "fail", str(image), f"cannot read image: {error}")
    if expected_size and tuple(expected_size) != size:
        return CheckResult(view_id, "fail", str(image), f"expected {expected_size}, got {list(size)}", metrics)

    heuristics = view.get("heuristics", {})
    if metrics["mean_luminance"] < float(heuristics.get("min_mean_luminance", 1.5)):
        return CheckResult(view_id, "fail", str(image), "image appears black", metrics)
    if metrics["max_channel_variance"] < float(heuristics.get("min_channel_variance", 4.0)):
        return CheckResult(view_id, "fail", str(image), "image appears visually flat", metrics)
    if metrics["bright_ratio"] > float(heuristics.get("max_bright_ratio", 0.985)):
        return CheckResult(view_id, "fail", str(image), "image appears overexposed", metrics)

    baseline = view.get("baseline") or {}
    baseline_path = baseline.get("path")
    if baseline_path:
        if baseline.get("status") != "approved":
            return CheckResult(view_id, "fail", str(image), "baseline path requires approved baseline status", metrics)
        if not str(baseline.get("reviewer", "")).strip() or not str(baseline.get("note", "")).strip():
            return CheckResult(view_id, "fail", str(image), "approved baseline requires reviewer and note", metrics)
        threshold = baseline.get("max_mean_absolute_difference")
        if not isinstance(threshold, (int, float)):
            return CheckResult(view_id, "fail", str(image), "approved baseline requires numeric difference threshold", metrics)
        resolved_baseline = gallery.parent / baseline_path
        if not resolved_baseline.is_file():
            return CheckResult(view_id, "fail", str(image), f"baseline missing: {baseline_path}", metrics)
        try:
            difference = mean_absolute_difference(image, resolved_baseline)
        except (OSError, ValueError) as error:
            return CheckResult(view_id, "fail", str(image), f"baseline comparison failed: {error}", metrics)
        metrics["mean_absolute_difference"] = round(difference, 4)
        if difference > float(threshold):
            return CheckResult(view_id, "fail", str(image), f"difference {difference:.4f} exceeds {threshold}", metrics)

    message = "approved" if status == "approved" else "pending human review"
    return CheckResult(view_id, "pass", str(image), message, metrics)


def main() -> int:
    args = parse_args()
    project = args.project.resolve()
    manifest_path = (args.manifest or project / "Development_Gallery" / "qa_003_approval_manifest.json").resolve()
    failures: list[str] = []
    try:
        manifest = load_manifest(manifest_path)
        views = selected_views(manifest, args.views)
    except ValueError as error:
        fail(str(error), failures)
        return 1
    gallery = project / "Development_Gallery" / "screenshots"
    if not gallery.is_dir():
        fail(f"gallery is missing: {gallery}", failures)
        return 1
    sources = resolve_source_paths(project, manifest)
    newest_source = max(sources, key=lambda path: path.stat().st_mtime_ns) if sources else None
    capture_revision = manifest.get("capture_source_revision")
    runtime_change_reason = runtime_changed_since(project, manifest)
    results = [
        verify_view(
            view,
            gallery,
            newest_source,
            runtime_change_reason,
            bool(capture_revision),
            args.mode,
            args.dry_run,
        )
        for view in views
    ]
    for result in results:
        print(f"QA-003: {result.status.upper()} - {result.view_id}: {result.message}")
        if result.status == "fail":
            failures.append(f"{result.view_id}: {result.message}")
    report = {
        "schema_version": 1,
        "mode": args.mode,
        "dry_run": args.dry_run,
        "manifest": str(manifest_path),
        "capture_source_revision": capture_revision,
        "newest_runtime_source": str(newest_source) if newest_source else None,
        "status": "fail" if failures else "pass",
        "results": [result.__dict__ for result in results],
    }
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    if failures:
        return 1
    print(f"QA-003: PASS - {len(results)} view(s) accepted for {args.mode} mode")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
