#!/usr/bin/env python3
"""Verify the ASSET-005 runtime asset boundary.

The current playable fallback is intentionally allowed, but it cannot be
mistaken for a visually approved release asset. Only processed files with
exact local hashes may be marked export-eligible.
"""

from __future__ import annotations

import fnmatch
import hashlib
import json
import sys
from pathlib import Path


MANIFEST_NAME = "runtime_asset_manifest.json"
REPORT_NAME = ".release-gate/asset_005.json"
REQUIRED_ROLES = {
    "road_ranger_human",
    "kael",
    "anwen",
    "villager",
    "guard",
    "traveler",
    "ghoulkin",
    "bog_wretch",
    "gravebound_knight",
    "ashwing",
    "white_hart",
}


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


def check_artifact(project: Path, row: object, errors: list[str], label: str) -> None:
    if not isinstance(row, dict):
        errors.append(f"{label} must be an object")
        return
    path_value = str(row.get("path", ""))
    path = resource_path(project, path_value)
    if path is None or not path.is_file():
        errors.append(f"{label} missing local file: {path_value}")
        return
    relative = path.relative_to(project).as_posix().lower()
    if relative.startswith("assets_external/downloads/") or relative.startswith("assets_external/raw/"):
        errors.append(f"{label} points into a raw source directory")
    if "assets_external/animations/" in relative and path.suffix.lower() in {".fbx", ".obj"}:
        errors.append(f"{label} points at a raw animation source: {relative}")
    expected_bytes = row.get("bytes")
    expected_hash = str(row.get("sha256", "")).lower()
    if not isinstance(expected_bytes, int) or expected_bytes != path.stat().st_size:
        errors.append(f"{label} byte count does not match {relative}")
    if len(expected_hash) != 64 or digest(path) != expected_hash:
        errors.append(f"{label} SHA-256 does not match {relative}")


def main() -> int:
    project = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else Path(__file__).resolve().parents[1]
    errors: list[str] = []
    manifest_path = project / MANIFEST_NAME
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        print(f"ASSET-005 VERIFIER: FAIL - {exc}")
        return 1

    if manifest.get("schema_version") != 1:
        errors.append("runtime asset manifest must be schema version 1")
    if manifest.get("ticket") != "ASSET-005":
        errors.append("runtime asset manifest must identify ASSET-005")
    if manifest.get("policy") != "free_cc0_only":
        errors.append("runtime asset policy must remain free_cc0_only")

    packs = manifest.get("source_packs", [])
    pack_ids = set()
    for pack in packs:
        if not isinstance(pack, dict):
            errors.append("source pack entries must be objects")
            continue
        pack_id = str(pack.get("id", ""))
        if not pack_id or pack_id in pack_ids:
            errors.append(f"source pack id is missing or duplicated: {pack_id}")
        pack_ids.add(pack_id)
        if not str(pack.get("url", "")).startswith("https://"):
            errors.append(f"source pack {pack_id} needs an HTTPS source URL")
        if str(pack.get("license", "")).upper() != "CC0 1.0":
            errors.append(f"source pack {pack_id} is not recorded as CC0 1.0")

    roles = manifest.get("roles", {})
    if not isinstance(roles, dict):
        errors.append("roles must be an object")
        roles = {}
    missing = sorted(REQUIRED_ROLES - set(roles))
    if missing:
        errors.append("missing required runtime roles: " + ", ".join(missing))

    approved: list[str] = []
    blocked: list[str] = []
    for role_id, role in roles.items():
        if not isinstance(role, dict):
            errors.append(f"role {role_id} must be an object")
            continue
        for key in ("family", "status", "approved", "export_eligible"):
            if key not in role:
                errors.append(f"role {role_id} missing {key}")
        if str(role.get("source_pack", "")) not in pack_ids:
            errors.append(f"role {role_id} references an unknown source pack")
        if bool(role.get("approved")):
            approved.append(role_id)
            if role.get("export_eligible") is not True:
                errors.append(f"approved role {role_id} must be export-eligible")
            if not str(role.get("model", "")):
                errors.append(f"approved role {role_id} needs a model path")
            if not str(role.get("source_url", "")).startswith("https://"):
                errors.append(f"approved role {role_id} needs a source URL")
            license_path = resource_path(project, str(role.get("license_file", "")))
            if license_path is None or not license_path.is_file():
                errors.append(f"approved role {role_id} needs a local license file")
            artifacts = role.get("runtime_files", [])
            if not isinstance(artifacts, list) or not artifacts:
                errors.append(f"approved role {role_id} needs runtime_files")
            else:
                for index, artifact in enumerate(artifacts):
                    check_artifact(project, artifact, errors, f"role {role_id} artifact {index}")
            animation_source = str(role.get("animation_source", ""))
            shared_sources = {
                str(item.get("path", ""))
                for item in manifest.get("shared_runtime_files", [])
                if isinstance(item, dict)
            }
            if animation_source and animation_source not in shared_sources:
                errors.append(f"approved role {role_id} animation source is not in shared_runtime_files")
        else:
            blocked.append(role_id)
            if role.get("export_eligible") is not False:
                errors.append(f"blocked role {role_id} must not be export-eligible")
            if not str(role.get("blocked_reason", "")).strip():
                errors.append(f"blocked role {role_id} needs a reason")
            fallback = resource_path(project, str(role.get("fallback", "")))
            if fallback is None or not fallback.is_file():
                errors.append(f"blocked role {role_id} needs an existing playable fallback")

    expected_approved = ["road_ranger_human", "kael", "anwen", "villager", "guard", "traveler"]
    if approved != expected_approved:
        errors.append(f"Milestone C approved runtime roles differ from the manifest contract: {approved}")

    for index, artifact in enumerate(manifest.get("shared_runtime_files", [])):
        check_artifact(project, artifact, errors, f"shared runtime artifact {index}")

    rules = manifest.get("runtime_rules", {})
    for token in ("proxy", "faceplane", "eye_box", "fake_neck", "root_mounted", "placeholder"):
        if token not in [str(value).lower() for value in rules.get("forbidden_path_tokens", [])]:
            errors.append(f"runtime rules omit forbidden token {token}")

    quarantine = manifest.get("quarantine", [])
    if not isinstance(quarantine, list) or not quarantine:
        errors.append("quarantine must contain raw/excluded source patterns")
    for row in quarantine:
        if not isinstance(row, dict) or not str(row.get("pattern", "")) or not str(row.get("reason", "")).strip():
            errors.append("every quarantine entry needs a pattern and reason")

    preset = (project / "export_presets.cfg").read_text(encoding="utf-8")
    for pattern in ("assets_external/downloads/*", "assets_external/raw/*"):
        if pattern not in preset:
            errors.append(f"export preset does not exclude {pattern}")
    raw_monster_pattern = "assets_external/enemies/quaternius_lowpoly_animated_monsters__*"
    include_filters = "\n".join(
        line.split("=", 1)[1]
        for line in preset.splitlines()
        if line.startswith("include_filter=")
    )
    if raw_monster_pattern in include_filters:
        errors.append("raw duplicate monster pattern must not be an export input")
    ignore = (project / ".gitignore").read_text(encoding="utf-8")
    if "/assets_external/enemies/quaternius_lowpoly_animated_monsters__*" not in ignore:
        errors.append("raw monster duplicate pattern is not ignored")

    report = {
        "ticket": "ASSET-005",
        "status": "pass" if not errors else "fail",
        "approved_roles": approved,
        "blocked_roles": blocked,
        "errors": errors,
    }
    report_path = project / REPORT_NAME
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    if errors:
        print("ASSET-005 VERIFIER: FAIL")
        for error in errors:
            print(f"- {error}")
        return 1
    print(f"ASSET-005 VERIFIER: PASS ({len(approved)} approved runtime roles, {len(blocked)} explicit fallbacks)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
