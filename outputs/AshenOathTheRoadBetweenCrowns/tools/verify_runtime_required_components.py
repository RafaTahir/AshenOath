#!/usr/bin/env python3
"""Validate the runtime-required component contract.

This gate is intentionally stricter than a file-presence scan.  It reads the
runtime acceptance manifest as the authority for roles, verifies every
referenced local artifact and hash, and requires blocked visual roles to carry
an explicit, existing fallback.  A fallback is reported as technical debt; it
is never treated as an approved visual role.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path
from typing import Any


REQUIRED_FILES = (
    "project.godot",
    "scenes/main.tscn",
    "scripts/game.gd",
    "scripts/player_controller.gd",
    "scripts/asset_database.gd",
    "scripts/asset_spawn_helper.gd",
    "scripts/zone_spatial_service.gd",
    "scripts/runtime_pack_manager.gd",
    "scripts/save_manager.gd",
    "scripts/input_router.gd",
    "scripts/interaction_focus_service.gd",
    "scripts/quest_manager.gd",
    "scripts/quest_presentation_state.gd",
    "scripts/objective_view_model.gd",
    "data/quests.json",
    "data/dialogue.json",
    "data/items.json",
    "data/vendors.json",
    "data/enemies.json",
    "data/bosses.json",
    "runtime_asset_manifest.json",
    "curated_runtime_assets.json",
    "export_presets.cfg",
)

POLICY_MARKERS = {
    "scripts/asset_database.gd": (
        "ACCEPTANCE_ROLE_ALIASES",
        "func get_runtime_policy",
        'result["runtime_policy"]',
    ),
    "scripts/asset_spawn_helper.gd": (
        "runtime_release_blocked",
        "_apply_runtime_policy_metadata",
        "Runtime visual role",
    ),
}

FORBIDDEN_RUNTIME_TOKENS = (
    "proxy",
    "faceplane",
    "eye_box",
    "fake_neck",
    "root_mounted",
    "placeholder",
)


def resource_path(project: Path, value: str) -> Path | None:
    if not value.startswith("res://"):
        return None
    return project / Path(value.removeprefix("res://"))


def digest(path: Path) -> str:
    hasher = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            hasher.update(block)
    return hasher.hexdigest()


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


def check_artifact(
    project: Path,
    role_id: str,
    artifact: Any,
    errors: list[str],
) -> None:
    label = f"role {role_id} artifact"
    if not isinstance(artifact, dict):
        errors.append(f"{label} must be an object")
        return
    path_value = str(artifact.get("path", ""))
    path = resource_path(project, path_value)
    if path is None or not path.is_file():
        errors.append(f"{label} is missing: {path_value}")
        return
    relative = path.relative_to(project).as_posix().lower()
    if any(token in relative for token in FORBIDDEN_RUNTIME_TOKENS):
        errors.append(f"{label} uses forbidden runtime token: {relative}")
    if relative.startswith("assets_external/downloads/") or relative.startswith("assets_external/raw/"):
        errors.append(f"{label} points at raw source: {relative}")
    expected_bytes = artifact.get("bytes")
    if not isinstance(expected_bytes, int) or expected_bytes != path.stat().st_size:
        errors.append(f"{label} byte count is stale: {relative}")
    expected_hash = str(artifact.get("sha256", "")).lower()
    if len(expected_hash) != 64 or digest(path) != expected_hash:
        errors.append(f"{label} SHA-256 is stale: {relative}")


def check_role(
    project: Path,
    role_id: str,
    role: Any,
    blocked: list[dict[str, str]],
    errors: list[str],
) -> None:
    if not isinstance(role, dict):
        errors.append(f"role {role_id} must be an object")
        return
    for key in ("family", "status", "approved", "export_eligible"):
        if key not in role:
            errors.append(f"role {role_id} is missing {key}")
    approved = bool(role.get("approved", False))
    export_eligible = role.get("export_eligible")
    if approved and export_eligible is not True:
        errors.append(f"approved role {role_id} must be export_eligible")
    if not approved and export_eligible is not False:
        errors.append(f"blocked role {role_id} must not be export_eligible")

    model_value = str(role.get("model", ""))
    model_path = resource_path(project, model_value)
    if approved:
        if model_path is None or not model_path.is_file():
            errors.append(f"approved role {role_id} model is missing: {model_value}")
        license_path = resource_path(project, str(role.get("license_file", "")))
        if license_path is None or not license_path.is_file():
            errors.append(f"approved role {role_id} license file is missing")
        artifacts = role.get("runtime_files")
        if not isinstance(artifacts, list) or not artifacts:
            errors.append(f"approved role {role_id} has no runtime_files")
        else:
            for artifact in artifacts:
                check_artifact(project, role_id, artifact, errors)
        if not str(role.get("source_url", "")).startswith("https://"):
            errors.append(f"approved role {role_id} has no HTTPS source URL")
    else:
        reason = str(role.get("blocked_reason", "")).strip()
        fallback_value = str(role.get("fallback", ""))
        fallback_path = resource_path(project, fallback_value)
        if not reason:
            errors.append(f"blocked role {role_id} needs an explicit blocked_reason")
        if fallback_path is None or not fallback_path.is_file():
            errors.append(f"blocked role {role_id} needs an existing fallback: {fallback_value}")
        blocked.append(
            {
                "id": role_id,
                "status": str(role.get("status", "")),
                "fallback": fallback_value,
                "reason": reason,
            }
        )


def check_curated_roles(project: Path, manifest: dict[str, Any], errors: list[str]) -> None:
    roles = manifest.get("roles", {})
    if not isinstance(roles, dict):
        errors.append("curated runtime roles must be an object")
        return
    for family in ("characters", "enemies"):
        entries = roles.get(family, {})
        if not isinstance(entries, dict) or not entries:
            errors.append(f"curated runtime {family} roles are empty")
            continue
        for role_id, entry in entries.items():
            if not isinstance(entry, dict):
                errors.append(f"curated role {role_id} must be an object")
                continue
            path_value = str(entry.get("path", ""))
            path = resource_path(project, path_value)
            if path is None or not path.is_file():
                errors.append(f"curated role {role_id} points at a missing path: {path_value}")
            if any(token in path_value.lower() for token in FORBIDDEN_RUNTIME_TOKENS):
                errors.append(f"curated role {role_id} uses a forbidden proxy token")


def check_runtime_policy_contract(project: Path, errors: list[str]) -> None:
    for relative, markers in POLICY_MARKERS.items():
        path = project / relative
        try:
            source = path.read_text(encoding="utf-8")
        except OSError as exc:
            errors.append(f"runtime policy source is unreadable: {relative}: {exc}")
            continue
        for marker in markers:
            if marker not in source:
                errors.append(f"runtime policy marker is missing from {relative}: {marker}")


def check_runtime_policy_rules(manifest: dict[str, Any], errors: list[str]) -> None:
    rules = manifest.get("runtime_rules", {})
    if not isinstance(rules, dict):
        errors.append("runtime_rules must be an object")
        return
    if rules.get("missing_required_is_fatal") is not True:
        errors.append("missing_required_is_fatal must be true")
    if rules.get("unregistered_required_role_is_fatal") is not True:
        errors.append("unregistered_required_role_is_fatal must be true")
    if rules.get("unapproved_required_role_mode") != "diagnostic_fallback_only":
        errors.append("unapproved_required_role_mode must be diagnostic_fallback_only")
    roles = manifest.get("roles", {})
    if not isinstance(roles, dict):
        return
    for role_id, role in roles.items():
        if not isinstance(role, dict):
            continue
        approved = bool(role.get("approved", False))
        if approved and role.get("fallback_mode", "none") != "none":
            errors.append(f"approved role {role_id} must have fallback_mode none")
        if not approved and role.get("fallback_mode") != "diagnostic_only":
            errors.append(f"blocked role {role_id} must have fallback_mode diagnostic_only")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("project", nargs="?", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--json-report", type=Path)
    args = parser.parse_args()
    project = args.project.resolve()
    errors: list[str] = []

    for relative in REQUIRED_FILES:
        if not (project / relative).is_file():
            errors.append(f"required project component is missing: {relative}")

    runtime_manifest = load_json(project / "runtime_asset_manifest.json", errors)
    curated_manifest = load_json(project / "curated_runtime_assets.json", errors)
    roles = runtime_manifest.get("roles", {})
    blocked: list[dict[str, str]] = []
    if not isinstance(roles, dict) or not roles:
        errors.append("runtime acceptance manifest has no roles")
    else:
        for role_id, role in roles.items():
            check_role(project, str(role_id), role, blocked, errors)
    check_curated_roles(project, curated_manifest, errors)
    check_runtime_policy_contract(project, errors)
    check_runtime_policy_rules(runtime_manifest, errors)

    export_text = (project / "export_presets.cfg").read_text(encoding="utf-8", errors="replace") if (project / "export_presets.cfg").is_file() else ""
    if "assets_external/downloads/*" not in export_text or "assets_external/raw/*" not in export_text:
        errors.append("production export does not exclude raw download/source directories")
    production_block = export_text.split("[preset.0]", 1)[1].split("[preset.0.options]", 1)[0] if "[preset.0]" in export_text else ""
    include_lines = "\n".join(
        line.split("=", 1)[1]
        for line in production_block.splitlines()
        if line.startswith("include_filter=")
    )
    exclude_lines = "\n".join(
        line.split("=", 1)[1]
        for line in production_block.splitlines()
        if line.startswith("exclude_filter=")
    )
    if "qa_browser_telemetry.gd" in include_lines and "qa_browser_telemetry.gd" not in exclude_lines:
        errors.append("production preset includes QA browser telemetry")
    if "tools/*" in include_lines and "tools/*" not in exclude_lines:
        errors.append("production preset includes verifier/tool sources")

    report = {
        "ticket": "RUNTIME-001",
        "status": "pass" if not errors else "fail",
        "required_files": len(REQUIRED_FILES),
        "runtime_roles": len(roles) if isinstance(roles, dict) else 0,
        "blocked_roles": blocked,
        "errors": errors,
    }
    report_path = args.json_report or project / ".release-gate" / "runtime_required_components.json"
    report_path = report_path.resolve()
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")

    if errors:
        print("RUNTIME-001 VERIFIER: FAIL")
        for error in errors:
            print(f"- {error}")
        return 1
    print(f"RUNTIME-001 VERIFIER: PASS ({len(REQUIRED_FILES)} components, {len(roles)} roles, {len(blocked)} explicit visual fallbacks)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
