#!/usr/bin/env python3
"""Validate an Ashen Oath release report against current source and artifact.

The strict mode is used only for a milestone release. Targeted development
runs may keep a partial report while evidence is still being collected.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
from pathlib import Path
from typing import Any


REQUIRED_SCREENSHOTS = {
    "01_greyfen_spawn",
    "05_sister_anwen_dialogue",
    "70_greyfen_river_bridge",
    "10_combat_clearing",
    "15_player_sword_ready",
    "13_player_light_attack_arc",
    "14_player_heavy_attack_arc",
    "73_combat_001_blade_contact",
    "36_vargan_approach",
    "38_record_hall",
    "41_white_hart_glade",
}


def source_fingerprint(project: Path) -> str:
    # Release identity must include the contracts that choose and package
    # runtime content, not only executable scripts and scenes.
    roots = (project / "scripts", project / "scenes", project / "data")
    files: list[Path] = []
    for root in roots:
        if root.is_dir():
            files.extend(
                path
                for path in root.rglob("*")
                if path.is_file() and path.suffix.lower() in {".gd", ".tscn", ".json"}
            )
    for relative in (
        "project.godot",
        "export_presets.cfg",
        "runtime_asset_manifest.json",
        "curated_runtime_assets.json",
        "character_role_manifest.json",
        "soul_character_role_manifest.json",
        "runtime_pack_manifest.json",
        "runtime_pack_candidates.json",
        "web_boot_shell.html",
    ):
        candidate = project / relative
        if candidate.is_file():
            files.append(candidate)
    digest = hashlib.sha256()
    for path in sorted(files):
        digest.update(path.relative_to(project).as_posix().encode("utf-8"))
        digest.update(b"\0")
        # Use the lowercase hexadecimal digest as the portable wire format;
        # Windows PowerShell 5 does not expose Convert.FromHexString.
        digest.update(hashlib.sha256(path.read_bytes()).hexdigest().encode("ascii"))
    return digest.hexdigest()


def git_value(repo: Path, *args: str) -> str:
    try:
        return subprocess.check_output(
            ["git", "-C", str(repo), *args], text=True, stderr=subprocess.DEVNULL
        ).strip()
    except (OSError, subprocess.CalledProcessError):
        return ""


def fail(errors: list[str], condition: bool, message: str) -> None:
    if not condition:
        errors.append(message)


def validate_artifact(project: Path, report: dict[str, Any], errors: list[str]) -> None:
    artifact = report.get("artifact")
    fail(errors, isinstance(artifact, dict), "report artifact snapshot is missing")
    if not isinstance(artifact, dict):
        return
    directory = Path(str(artifact.get("directory", "")))
    if not directory.is_absolute():
        directory = project.parent / directory
    fail(errors, directory.is_dir(), f"artifact directory is missing: {directory}")
    if not directory.is_dir():
        return
    actual_files = sorted(path for path in directory.rglob("*") if path.is_file())
    actual_by_relative = {
        path.relative_to(directory).as_posix(): path for path in actual_files
    }
    recorded = artifact.get("files", [])
    fail(errors, isinstance(recorded, list) and bool(recorded), "artifact file list is empty")
    recorded_by_path: dict[str, dict[str, Any]] = {}
    for item in recorded if isinstance(recorded, list) else []:
        if not isinstance(item, dict):
            errors.append("artifact file record is not an object")
            continue
        relative = str(item.get("path", ""))
        if not relative or relative in recorded_by_path:
            errors.append(f"artifact file record is invalid or duplicated: {relative}")
            continue
        recorded_by_path[relative] = item
        path = actual_by_relative.get(relative)
        fail(errors, path is not None, f"recorded artifact file is missing: {relative}")
        if path is None:
            continue
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        fail(errors, int(item.get("bytes", -1)) == path.stat().st_size, f"artifact size mismatch: {relative}")
        fail(errors, str(item.get("sha256", "")).lower() == digest, f"artifact hash mismatch: {relative}")
    fail(errors, set(recorded_by_path) == set(actual_by_relative), "artifact record does not match files on disk")
    total = sum(path.stat().st_size for path in actual_files)
    fail(errors, int(artifact.get("total_bytes", -1)) == total, "artifact total size is stale")
    fail(errors, total < int(artifact.get("max_bytes", 100 * 1024 * 1024)), f"artifact exceeds 100 MiB: {total} bytes")
    pck = actual_by_relative.get("index.pck")
    fail(errors, pck is not None, "artifact has no root index.pck")
    if pck is not None:
        fail(errors, str(artifact.get("pck_sha256", "")).lower() == hashlib.sha256(pck.read_bytes()).hexdigest(), "root PCK hash is stale")


def validate_screenshots(project: Path, report: dict[str, Any], errors: list[str], strict: bool) -> None:
    gallery = project / "Development_Gallery" / "screenshots"
    fail(errors, gallery.is_dir(), f"screenshot gallery is missing: {gallery}")
    if not gallery.is_dir() or not strict:
        return
    source_roots = (project / "scripts", project / "scenes", project / "data")
    source_mtime = max(
        (path.stat().st_mtime for root in source_roots if root.is_dir() for path in root.rglob("*") if path.is_file()),
        default=0.0,
    )
    listed = report.get("screenshots", {})
    fail(errors, isinstance(listed, dict), "strict report has no screenshot evidence map")
    for stem in REQUIRED_SCREENSHOTS:
        candidates = sorted(
            gallery.glob(f"*{stem}*.png"),
            key=lambda path: path.stat().st_mtime if path.exists() else 0.0,
            reverse=True,
        )
        fail(errors, bool(candidates), f"required screenshot is missing: {stem}")
        if not candidates:
            continue
        image = candidates[0]
        fail(errors, image.stat().st_size >= 4096, f"screenshot is blank or corrupt: {image.name}")
        fail(errors, image.stat().st_mtime >= source_mtime, f"screenshot is stale: {image.name}")
        if isinstance(listed, dict) and stem in listed:
            fail(errors, str(listed[stem].get("status", "")) == "approved", f"screenshot is not approved: {stem}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("project", type=Path)
    parser.add_argument("--report", type=Path)
    parser.add_argument("--strict", action="store_true")
    args = parser.parse_args()
    project = args.project.resolve()
    report_path = (args.report or project / "release_reports" / "latest.json").resolve()
    errors: list[str] = []
    try:
        report = json.loads(report_path.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError) as error:
        print(f"RELEASE REPORT: FAIL - {error}")
        return 1
    fail(errors, int(report.get("schema_version", 0)) >= 2, "report schema must be version 2 or newer")
    allowed_statuses = {"pass"} if args.strict else {"pass", "partial-pass"}
    fail(errors, str(report.get("status", "")) in allowed_statuses, "report status is not a release pass")
    repo = project.parent.parent
    head = git_value(repo, "rev-parse", "HEAD")
    source_commit = str(report.get("source_commit", ""))
    if head and source_commit:
        if source_commit != head:
            changed = [
                item
                for item in git_value(repo, "diff", "--name-only", f"{source_commit}..{head}").splitlines()
                if item
            ]
            artifact_only = all(
                item == "outputs/AshenOathTheRoadBetweenCrowns/release_reports/latest.json"
                or item.startswith("outputs/AshenOathTheRoadBetweenCrowns/Development_Gallery/screenshots/")
                or item.startswith("web/")
                for item in changed
            )
            fail(
                errors,
                artifact_only,
                f"report source commit {source_commit} does not match HEAD {head} for runtime changes: {changed}",
            )
    fail(errors, str(report.get("source_fingerprint", "")) == source_fingerprint(project), "report source fingerprint is stale")
    git_status = report.get("git_status", [])
    if args.strict:
        fail(errors, isinstance(git_status, list) and not git_status, "strict release report was generated from a dirty worktree")
    blockers = report.get("release_blockers", [])
    fail(errors, isinstance(blockers, list) and not blockers, "release blockers remain")
    results = report.get("results", [])
    fail(errors, isinstance(results, list) and bool(results), "report has no gate results")
    for result in results if isinstance(results, list) else []:
        if not isinstance(result, dict) or str(result.get("status", "")) != "pass":
            errors.append(f"non-passing gate in report: {result}")
    validate_artifact(project, report, errors)
    validate_screenshots(project, report, errors, args.strict)
    if errors:
        for error in errors:
            print(f"RELEASE REPORT: FAIL - {error}")
        return 1
    print(f"RELEASE REPORT: PASS - schema {report['schema_version']}, {len(results)} gate(s), artifact and source identity verified")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
