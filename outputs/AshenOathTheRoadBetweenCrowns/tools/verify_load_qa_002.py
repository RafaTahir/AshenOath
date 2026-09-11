#!/usr/bin/env python3
"""Milestone-A startup/cache contract and candidate artifact gate."""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
from pathlib import Path


PACK_IDS = {"base", "opening", "campaign", "characters", "monsters", "audio"}
REQUIRED_EXTERNAL_PACKS = {"opening", "campaign", "characters", "monsters", "audio"}
MAX_BYTES = 100 * 1024 * 1024


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def git_head(project: Path) -> str:
    """Read the source revision that owns the project manifests."""
    repo_root = project.parent.parent
    try:
        return subprocess.check_output(
            ["git", "-C", str(repo_root), "rev-parse", "HEAD"],
            text=True,
            stderr=subprocess.DEVNULL,
        ).strip()
    except (OSError, subprocess.CalledProcessError):
        return ""


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("project", nargs="?", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--candidate-dir", type=Path, help="optional external PACK-003 artifact directory")
    parser.add_argument("--json-report", type=Path)
    args = parser.parse_args()
    project = args.project.resolve()
    errors: list[str] = []
    diagnostics: list[str] = []

    manifest_path = project / "runtime_pack_manifest.json"
    candidates_path = project / "runtime_pack_candidates.json"
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        candidates = json.loads(candidates_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        errors.append(f"pack metadata is unreadable: {exc}")
        manifest, candidates = {}, {}

    source_commit = str(manifest.get("generated_from_commit", "")).strip().lower()
    candidate_commit = str(candidates.get("generated_from_commit", "")).strip().lower()
    current_commit = git_head(project).lower()
    if len(source_commit) != 40 or any(char not in "0123456789abcdef" for char in source_commit):
        errors.append("runtime pack manifest has no valid generated_from_commit")
    if len(candidate_commit) != 40 or any(char not in "0123456789abcdef" for char in candidate_commit):
        errors.append("runtime pack candidates have no valid generated_from_commit")
    if not current_commit:
        errors.append("could not resolve the repository HEAD for pack identity validation")
    elif source_commit != current_commit or candidate_commit != current_commit:
        errors.append(
            "runtime pack metadata was generated from "
            f"{source_commit or '<missing>'}/{candidate_commit or '<missing>'}, "
            f"but repository HEAD is {current_commit}"
        )
    if source_commit and candidate_commit and source_commit != candidate_commit:
        errors.append("runtime pack manifest and candidates disagree on generated_from_commit")
    manifest_build_id = str(manifest.get("build_id", "")).strip()
    candidate_build_id = str(candidates.get("build_id", "")).strip()
    if not manifest_build_id or manifest_build_id != candidate_build_id:
        errors.append("runtime pack manifest and candidates disagree on build_id")

    if int(manifest.get("max_deployment_bytes", 0)) > MAX_BYTES:
        errors.append("runtime pack manifest exceeds the 100 MB deployment budget")
    if int(candidates.get("total_bytes", 0)) > MAX_BYTES:
        errors.append("candidate packs exceed the 100 MB deployment budget")
    packs = manifest.get("packs", {})
    candidate_rows = {str(row.get("id")): row for row in candidates.get("packs", [])}
    if set(packs) != PACK_IDS or set(candidate_rows) != PACK_IDS:
        errors.append("manifest and candidate manifest do not contain exactly the six Milestone-A packs")

    for pack_id in sorted(PACK_IDS):
        pack = packs.get(pack_id, {})
        candidate = candidate_rows.get(pack_id, {})
        for field in ("version", "entry_scene", "dependencies", "preload_priority"):
            if field not in pack:
                errors.append(f"{pack_id} is missing manifest field {field}")
        if int(candidate.get("bytes", 0)) <= 0 or len(str(candidate.get("sha256", ""))) != 64:
            errors.append(f"{pack_id} has incomplete candidate size/hash metadata")
        if int(pack.get("candidate_bytes", 0)) != int(candidate.get("bytes", 0)):
            errors.append(f"{pack_id} candidate byte metadata disagrees between manifests")
        if str(pack.get("candidate_sha256", "")).lower() != str(candidate.get("sha256", "")).lower():
            errors.append(f"{pack_id} candidate hash metadata disagrees between manifests")

        configured_url = str(pack.get("url", "")).strip()
        status = str(pack.get("status", ""))
        if pack_id in REQUIRED_EXTERNAL_PACKS:
            if not configured_url:
                errors.append(f"{pack_id} has no production URL for its streamed runtime pack")
            if status != "streamed_web_candidate":
                errors.append(f"{pack_id} is not marked as a streamed Web candidate")
            if int(pack.get("bytes", 0)) != int(candidate.get("bytes", 0)):
                errors.append(f"{pack_id} production byte metadata disagrees with its candidate")
            if str(pack.get("sha256", "")).lower() != str(candidate.get("sha256", "")).lower():
                errors.append(f"{pack_id} production hash metadata disagrees with its candidate")
        elif pack_id == "base":
            if configured_url or not status.startswith("embedded"):
                errors.append("base must remain the embedded startup pack")
            if str(pack.get("embedded_artifact", "")) != "index.pck":
                errors.append("base must identify index.pck as its embedded artifact")
            if str(pack.get("embedded_source_artifact", "")) != str(candidate.get("artifact", "")):
                errors.append("base embedded source artifact disagrees with its candidate")
            if int(pack.get("embedded_source_bytes", 0)) != int(candidate.get("bytes", 0)):
                errors.append("base embedded source byte metadata disagrees with its candidate")
            if str(pack.get("embedded_source_sha256", "")).lower() != str(candidate.get("sha256", "")).lower():
                errors.append("base embedded source hash metadata disagrees with its candidate")
            if str(pack.get("embedded_source_kind", "")) != "standalone_pack_candidate":
                errors.append("base embedded source kind is missing or invalid")
        else:
            errors.append(f"{pack_id} has an unsupported non-streamed pack status")

        if configured_url:
            diagnostics.append(f"{pack_id}: external URL configured")
        else:
            diagnostics.append(f"{pack_id}: embedded/cache fallback active")

    manager_path = project / "scripts" / "runtime_pack_manager.gd"
    manager = manager_path.read_text(encoding="utf-8") if manager_path.is_file() else ""
    for label, token in {
        "temporary download": ".part",
        "SHA validation": "_validate_artifact",
        "atomic cache commit": "rename_absolute",
        "retry": "retry_pack",
        "cancel": "cancel_request",
        "mount": "load_resource_pack",
        "cache index": "cache_index.json",
    }.items():
        if token not in manager:
            errors.append(f"runtime pack manager missing {label} contract")

    shell_path = project / "web_boot_shell.html"
    shell = shell_path.read_text(encoding="utf-8") if shell_path.is_file() else ""
    for token in ("window.__ashenOathBoot", "ashen-oath-first-paint", "ashen-oath-engine-ready", "navigator.getGamepads"):
        if token not in shell:
            errors.append(f"boot/cache acceptance lacks {token}")

    preset = (project / "export_presets.cfg").read_text(encoding="utf-8") if (project / "export_presets.cfg").is_file() else ""
    if 'html/custom_html_shell="res://web_boot_shell.html"' not in preset:
        errors.append("production export does not use the immediate shell")
    production_preset = preset.split("[preset.0]", 1)[-1].split("[preset.0.options]", 1)[0]
    production_sources = "\n".join(
        line for line in production_preset.splitlines()
        if line.startswith("include_filter=") or line.startswith("export_files=")
    )
    if "scripts/qa_browser_telemetry.gd" in production_sources:
        errors.append("production export still exposes QA telemetry")

    external_report = {"checked": False, "packs": {}}
    if args.candidate_dir:
        candidate_dir = args.candidate_dir.resolve()
        external_report["checked"] = True
        pack_root = candidate_dir / "packs" if (candidate_dir / "packs").is_dir() else candidate_dir
        for pack_id in sorted(REQUIRED_EXTERNAL_PACKS):
            row = candidate_rows.get(pack_id, {})
            artifact = pack_root / str(row.get("artifact", f"{pack_id}.pck"))
            if not artifact.is_file():
                errors.append(f"external candidate missing: {artifact}")
                continue
            data = artifact.read_bytes()
            actual_hash = sha256(artifact)
            external_report["packs"][pack_id] = {"bytes": len(data), "sha256": actual_hash}
            if len(data) != int(row.get("bytes", 0)) or actual_hash != str(row.get("sha256", "")):
                errors.append(f"external candidate validation failed: {pack_id}")
            if data[:4] != b"GDPC":
                errors.append(f"external candidate has no GDPC header: {pack_id}")
        diagnostics.append("external candidate directory verified")
    else:
        diagnostics.append("external candidate directory not supplied; metadata verified")

    report = {
        "schema_version": 1,
        "status": "fail" if errors else "pass",
        "ticket": "LOAD-QA-002",
        "candidate_total_bytes": int(candidates.get("total_bytes", 0)),
        "diagnostics": diagnostics,
        "external_candidates": external_report,
        "failures": errors,
    }
    if args.json_report:
        args.json_report.parent.mkdir(parents=True, exist_ok=True)
        args.json_report.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    if errors:
        print("LOAD-QA-002: FAIL")
        for error in errors:
            print(f"- {error}")
        return 1
    print("LOAD-QA-002: PASS (boot timing contract, cache validation, six-pack budget, fallback safety)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
