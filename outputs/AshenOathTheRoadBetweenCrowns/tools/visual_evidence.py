"""Content identity and review contract shared by all visual release gates."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
from typing import Any

SOURCE_ROOTS = ("scripts", "scenes", "data", "assets", "assets_external")
SOURCE_FILES = (
    "project.godot", "export_presets.cfg", "runtime_asset_manifest.json",
    "asset_manifest.json", "asset_acceptance_manifest.json", "character_role_manifest.json",
    "soul_character_role_manifest.json", "monster_family_manifest.json", "visual_upgrade_manifest.json",
    "zone_scene_manifest.json", "world_sector_manifest.json", "runtime_pack_manifest.json",
)
REVIEW_CHECKS = ("anatomy", "grounding", "scale", "materials", "composition", "route_clearance", "role_identity")


def rendering_inputs(project: Path) -> list[Path]:
    paths: set[Path] = set()
    for relative in SOURCE_ROOTS:
        root = project / relative
        if not root.is_dir():
            continue
        for path in root.rglob("*"):
            if not path.is_file():
                continue
            name = path.relative_to(project).as_posix()
            if name.startswith(("assets_external/raw/", "assets_external/downloads/")):
                continue
            if path.suffix.lower() in {".blend", ".zip", ".7z", ".rar", ".uid", ".md", ".txt"}:
                continue
            if name.startswith("assets_external/animations/") and path.suffix.lower() in {".fbx", ".glb"}:
                continue
            paths.add(path)
    paths.update(project / relative for relative in SOURCE_FILES if (project / relative).is_file())
    return sorted(paths, key=lambda path: path.relative_to(project).as_posix())


def file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as opened:
        for chunk in iter(lambda: opened.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def rendering_inputs_sha256(project: Path) -> str:
    digest = hashlib.sha256()
    for path in rendering_inputs(project):
        digest.update(path.relative_to(project).as_posix().encode("utf-8"))
        digest.update(b"\0")
        digest.update(file_sha256(path).encode("ascii"))
        digest.update(b"\n")
    return digest.hexdigest()


def capture_identity_error(image: Path, current_digest: str) -> str | None:
    sidecar = image.with_suffix(image.suffix + ".capture.json")
    try:
        record = json.loads(sidecar.read_text(encoding="utf-8"))
    except (OSError, ValueError) as error:
        return f"missing or invalid source-bound capture record: {error}"
    if not isinstance(record, dict) or record.get("schema_version") != 1:
        return "invalid capture record schema"
    if record.get("status") != "captured" or not record.get("capture_gate") or not record.get("captured_at_utc"):
        return "capture record lacks a completed capture gate"
    if record.get("rendering_inputs_sha256") != current_digest:
        return "capture rendering inputs differ from current source/assets"
    if record.get("image_sha256") != file_sha256(image):
        return "capture record does not match screenshot bytes"
    return None


def needs_input_digest(gallery: Path, views: list[dict[str, Any]]) -> bool:
    # Do not read every asset when a view is already unconditionally rejected
    # for missing approval/capture evidence. This never permits a passing view
    # to skip its current-content comparison.
    for view in views:
        if view.get("status") == "rejected":
            continue
        if view.get("status") == "approved" and review_error(view):
            continue
        if any(image.with_suffix(image.suffix + ".capture.json").is_file()
               for image in gallery.glob(str(view.get("current_glob", ""))) if image.is_file()):
            return True
    return False


def review_error(view: dict[str, Any]) -> str | None:
    if "codex" not in str(view.get("reviewer", "")).lower():
        return "active visual policy requires a Codex reviewer"
    checks = view.get("review_checks")
    if not isinstance(checks, dict):
        return "approved view lacks explicit semantic review checks"
    for name in REVIEW_CHECKS:
        check = checks.get(name)
        if not isinstance(check, dict) or check.get("verdict") not in {"accepted", "not_applicable"}:
            return f"semantic review is missing or rejected: {name}"
        if not isinstance(check.get("note"), str) or not check["note"].strip():
            return f"semantic review needs an inspection note: {name}"
    return None
