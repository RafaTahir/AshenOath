#!/usr/bin/env python3
"""Plan or execute a deterministic GLB runtime conversion.

The project keeps Blender/gltfpack outside the repository. This wrapper makes
the boundary reproducible: source and output paths are validated, conversion
arguments are stable, and registration is always pending until the Godot and
visual gates approve the result.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Any


MODEL_EXTENSIONS = {".glb", ".gltf"}
FORBIDDEN_PARTS = ("assets_external/downloads/", "assets_external/raw/")
FORBIDDEN_SOURCE_TOKENS = ("faceplane", "eye_box", "proxy", "fake_neck", "root_mounted", "placeholder")


def project_path(project: Path, value: str) -> Path:
    if value.startswith("res://"):
        return (project / value[6:].replace("/", os.sep)).resolve()
    return Path(value).expanduser().resolve()


def res_path(project: Path, path: Path) -> str:
    return "res://" + path.resolve().relative_to(project.resolve()).as_posix()


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def assert_source(path: Path, project: Path) -> None:
    if not path.is_file():
        raise ValueError(f"source does not exist: {path}")
    if path.suffix.lower() not in MODEL_EXTENSIONS:
        raise ValueError(f"source must be GLB or GLTF: {path.name}")
    relative = path.relative_to(project).as_posix().lower() if path.is_relative_to(project) else path.as_posix().lower()
    if any(part in relative for part in FORBIDDEN_PARTS):
        raise ValueError("raw/download source directories cannot be converted as runtime inputs")
    if any(token in relative for token in FORBIDDEN_SOURCE_TOKENS):
        raise ValueError(f"source uses a forbidden role token: {path.name}")


def assert_output(path: Path, project: Path) -> None:
    if not path.is_relative_to(project):
        raise ValueError("output must be inside the Godot project")
    relative = path.relative_to(project).as_posix().lower()
    if not relative.startswith("assets_external/"):
        raise ValueError("runtime output must be inside assets_external")
    if any(part in relative for part in FORBIDDEN_PARTS) or "/animations/" in relative:
        raise ValueError("runtime output cannot be placed in raw, download, or source-animation directories")
    if path.suffix.lower() != ".glb":
        raise ValueError("runtime output must be a GLB")


def find_tool(explicit: str | None, names: tuple[str, ...]) -> str | None:
    if explicit:
        candidate = Path(explicit).expanduser()
        if candidate.is_file():
            return str(candidate.resolve())
        raise ValueError(f"tool does not exist: {explicit}")
    for name in names:
        command = next((part for part in os.environ.get("PATH", "").split(os.pathsep) if (Path(part) / name).is_file()), None)
        if command:
            return str(Path(command) / name)
    return None


def artifact(path: Path, project: Path) -> dict[str, Any]:
    return {"path": res_path(project, path), "bytes": path.stat().st_size, "sha256": sha256(path)}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--source", required=True, help="Existing GLB/GLTF path or res:// path")
    parser.add_argument("--output", required=True, help="Future runtime GLB path or res:// path")
    parser.add_argument("--role", default="")
    parser.add_argument("--source-pack", default="")
    parser.add_argument("--license-file", default="")
    parser.add_argument("--source-url", default="")
    parser.add_argument("--gltfpack", default="")
    parser.add_argument("--execute", action="store_true")
    parser.add_argument("--register", action="store_true")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()
    project = args.project.resolve()
    try:
        source = project_path(project, args.source)
        output = project_path(project, args.output)
        assert_source(source, project)
        assert_output(output, project)
        if args.register and not args.role:
            raise ValueError("--register requires --role")
        if args.register and not args.license_file:
            raise ValueError("--register requires --license-file")
        if args.register:
            license_path = project_path(project, args.license_file)
            if not license_path.is_file():
                raise ValueError(f"license file does not exist: {license_path}")
        gltfpack = find_tool(args.gltfpack or None, ("gltfpack.exe", "gltfpack"))
        plan: dict[str, Any] = {
            "schema_version": 1,
            "pipeline": "Ashen Oath character runtime conversion",
            "source": res_path(project, source),
            "output": res_path(project, output),
            "role": args.role,
            "source_pack": args.source_pack,
            "source_url": args.source_url,
            "gltfpack": gltfpack,
            "conversion": {"compress_meshes": True, "preserve_skins": True, "root_motion": False, "approval": "pending_visual_review"},
        }
        if not args.execute:
            print(json.dumps(plan, indent=2))
            return 0
        if gltfpack is None:
            raise ValueError("gltfpack is not installed; provide --gltfpack or run the plan-only step")
        output.parent.mkdir(parents=True, exist_ok=True)
        command = [gltfpack, "-i", str(source), "-o", str(output), "-cc"]
        completed = subprocess.run(command, cwd=project, check=False)
        if completed.returncode != 0:
            return completed.returncode
        if not output.is_file():
            raise ValueError(f"gltfpack did not create output: {output}")
        record = {**plan, "artifact": artifact(output, project)}
        if args.register:
            manifest_path = project / "soul_character_role_manifest.json"
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            role = manifest.get("roles", {}).get(args.role)
            if not isinstance(role, dict):
                raise ValueError(f"unknown role: {args.role}")
            role.update({
                "path": record["artifact"]["path"],
                "source_pack": args.source_pack or role.get("source_pack", ""),
                "source_url": args.source_url,
                "license_file": args.license_file,
                "bytes": record["artifact"]["bytes"],
                "sha256": record["artifact"]["sha256"],
                "runtime_artifacts": [record["artifact"]],
                "approved": False,
                "export_eligible": False,
                "status": "registered_pending_visual_review",
                "blocked_reason": "Converted artifact requires Godot import, skeleton, clip, budget, and Codex visual review before approval.",
            })
            manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
            record["registered"] = True
        print(json.dumps(record, indent=2))
        return 0
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"CHARACTER PIPELINE: FAIL - {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
