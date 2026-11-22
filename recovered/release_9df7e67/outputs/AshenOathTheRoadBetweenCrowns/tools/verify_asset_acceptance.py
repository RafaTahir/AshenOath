#!/usr/bin/env python3
"""Validate the soul-rebuild source and role acceptance contracts.

This deliberately does not approve downloaded assets by filename. A role is
approved only after a local artifact is present, hashed, and explicitly marked
approved in the role manifest. Pending roles may retain a known temporary
fallback so the current prototype remains playable.
"""

from __future__ import annotations

import argparse
import fnmatch
import hashlib
import json
import sys
from pathlib import Path
from typing import Any


PACKS = "soul_asset_pack_manifest.json"
ROLES = "soul_character_role_manifest.json"


def load_json(path: Path, errors: list[str]) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        errors.append(f"{path.name}: {exc}")
        return {}
    if not isinstance(value, dict):
        errors.append(f"{path.name}: root must be an object")
        return {}
    return value


def res_path(project: Path, value: str) -> Path | None:
    prefix = "res://"
    if not value.startswith(prefix):
        return None
    return project / value[len(prefix) :].replace("/", str(Path("/")))


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def validate_artifacts(project: Path, artifacts: Any, forbidden: list[str], excluded_patterns: list[str], errors: list[str], label: str) -> int:
    if not isinstance(artifacts, list):
        errors.append(f"{label} runtime_artifacts must be an array")
        return 0
    total_bytes = 0
    for index, artifact in enumerate(artifacts):
        if not isinstance(artifact, dict):
            errors.append(f"{label} artifact {index} must be an object")
            continue
        for key in ("path", "bytes", "sha256"):
            if key not in artifact:
                errors.append(f"{label} artifact {index} missing {key}")
        path_value = str(artifact.get("path", ""))
        path = res_path(project, path_value)
        if path is None or not path.is_file():
            errors.append(f"{label} artifact {index} has no local file: {path_value}")
            continue
        relative = path.relative_to(project).as_posix().lower()
        if any(part in relative for part in ("assets_external/downloads/", "assets_external/raw/")):
            errors.append(f"{label} artifact {index} points into an excluded source directory")
        if any(fnmatch.fnmatch(relative, pattern.lower()) for pattern in excluded_patterns):
            errors.append(f"{label} artifact {index} matches an excluded source pattern: {relative}")
        if any(token in relative for token in forbidden):
            errors.append(f"{label} artifact {index} uses a forbidden proxy token")
        actual_bytes = path.stat().st_size
        expected_bytes = artifact.get("bytes")
        if not isinstance(expected_bytes, int) or expected_bytes != actual_bytes:
            errors.append(f"{label} artifact {index} byte count does not match {path.name}")
        expected_hash = str(artifact.get("sha256", "")).lower()
        if len(expected_hash) != 64 or sha256(path) != expected_hash:
            errors.append(f"{label} artifact {index} SHA-256 does not match {path.name}")
        total_bytes += actual_bytes
    return total_bytes


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("project", nargs="?", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--json-report", type=Path)
    args = parser.parse_args()
    project = args.project.resolve()
    errors: list[str] = []
    packs = load_json(project / PACKS, errors)
    roles = load_json(project / ROLES, errors)
    pack_rows = packs.get("packs", [])
    pack_ids = {str(row.get("id", "")) for row in pack_rows if isinstance(row, dict)}
    if len(pack_ids) != len(pack_rows):
        errors.append("pack ids must be unique and non-empty")
    rules = packs.get("runtime_rules", {})
    forbidden = [str(token).lower() for token in rules.get("forbidden_role_tokens", [])]
    excluded_patterns = [str(pattern).replace("\\", "/").lower() for pattern in rules.get("excluded_source_patterns", [])]
    for row in pack_rows:
        if not isinstance(row, dict):
            errors.append("pack entry must be an object")
            continue
        for key in ("id", "version", "url", "dependencies", "preload_priority", "license", "status"):
            if key not in row:
                errors.append(f"pack {row.get('id', '<unknown>')} missing {key}")
        if str(row.get("license", "")).upper().startswith("CC0") is False:
            errors.append(f"pack {row.get('id', '<unknown>')} is not CC0")
        if not str(row.get("url", "")).startswith("https://"):
            errors.append(f"pack {row.get('id', '<unknown>')} source URL must be HTTPS")
        for dependency in row.get("dependencies", []):
            if dependency not in pack_ids:
                errors.append(f"pack {row.get('id', '<unknown>')} has unknown dependency {dependency}")
        if "runtime_artifacts" not in row:
            errors.append(f"pack {row.get('id', '<unknown>')} missing runtime_artifacts")
        if "export_policy" not in row:
            errors.append(f"pack {row.get('id', '<unknown>')} missing export_policy")
        validate_artifacts(project, row.get("runtime_artifacts", []), forbidden, excluded_patterns, errors, f"pack {row.get('id', '<unknown>')}")
    role_rows = roles.get("roles", {})
    approved_count = 0
    pending_count = 0
    artifact_count = 0
    artifact_bytes = 0
    for role_id, role in role_rows.items():
        if not isinstance(role, dict):
            errors.append(f"role {role_id} must be an object")
            continue
        source_pack = str(role.get("source_pack", ""))
        if source_pack not in pack_ids:
            errors.append(f"role {role_id} references unknown pack {source_pack}")
        status = str(role.get("status", ""))
        for required in ("family", "triangle_budget", "texture_budget", "required_clips", "equipment_sockets", "export_eligible"):
            if required not in role:
                errors.append(f"role {role_id} missing {required}")
        if bool(role.get("approved", False)):
            approved_count += 1
            if role.get("export_eligible") is not True:
                errors.append(f"approved role {role_id} must be export_eligible")
            path_value = str(role.get("path", ""))
            path = res_path(project, path_value)
            if path is None or not path.is_file():
                errors.append(f"approved role {role_id} has no local path")
                continue
            relative = path.relative_to(project).as_posix().lower()
            if any(part in relative for part in ("assets_external/downloads/", "assets_external/raw/", "assets_external/animations/")):
                errors.append(f"approved role {role_id} points into an excluded source directory")
            if any(token in relative for token in forbidden):
                errors.append(f"approved role {role_id} uses a forbidden proxy token")
            expected = str(role.get("sha256", ""))
            if len(expected) != 64:
                errors.append(f"approved role {role_id} must record a SHA-256")
            elif sha256(path) != expected.lower():
                errors.append(f"approved role {role_id} SHA-256 does not match {path.name}")
            if not str(role.get("source_url", "")).startswith("https://"):
                errors.append(f"approved role {role_id} must record its source URL")
            license_file_value = str(role.get("license_file", ""))
            license_file = res_path(project, license_file_value) if license_file_value else None
            if license_file is None or not license_file.is_file():
                errors.append(f"approved role {role_id} must record a local license file")
            role_artifacts = role.get("runtime_artifacts", [])
            artifact_bytes += validate_artifacts(project, role_artifacts, forbidden, excluded_patterns, errors, f"role {role_id}")
            artifact_count += len(role_artifacts) if isinstance(role_artifacts, list) else 0
            if not isinstance(role_artifacts, list) or not role_artifacts:
                errors.append(f"approved role {role_id} must list runtime_artifacts")
            elif not any(str(item.get("path", "")) == path_value for item in role_artifacts if isinstance(item, dict)):
                errors.append(f"approved role {role_id} runtime_artifacts must include its path")
        else:
            pending_count += 1
            if role.get("export_eligible") is not False:
                errors.append(f"pending role {role_id} must not be export_eligible")
            if not str(role.get("blocked_reason", "")).strip():
                errors.append(f"pending role {role_id} needs a blocked_reason")
            fallback_value = str(role.get("current_fallback", ""))
            fallback = res_path(project, fallback_value) if fallback_value else None
            if fallback is None or not fallback.is_file():
                errors.append(f"pending role {role_id} has no usable current fallback")
            if status == "":
                errors.append(f"pending role {role_id} needs an explicit status")

    report = {
        "packs": len(pack_rows),
        "roles": len(role_rows),
        "approved_roles": approved_count,
        "pending_roles": pending_count,
        "runtime_artifacts": artifact_count,
        "runtime_artifact_bytes": artifact_bytes,
        "errors": errors,
    }
    if args.json_report:
        args.json_report.parent.mkdir(parents=True, exist_ok=True)
        args.json_report.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    if errors:
        print("ASSET ACCEPTANCE: FAIL")
        for error in errors:
            print(f"- {error}")
        return 1
    print(f"ASSET ACCEPTANCE: PASS ({len(pack_rows)} source packs, {approved_count} approved roles, {pending_count} pending roles)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
