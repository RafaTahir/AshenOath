#!/usr/bin/env python3
"""Register a local, reviewed asset without copying it into the project.

The default is a dry run. Use --write only after the visual and licensing
review for a role is complete. The command records a SHA-256 and byte count so
future rebuilds can prove that the same source was used.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path


def digest(path: Path) -> str:
    sha = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            sha.update(block)
    return sha.hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--role", required=True)
    parser.add_argument("--path", required=True, help="Project-relative res:// path")
    parser.add_argument("--source-pack", required=True)
    parser.add_argument("--license-file", required=True)
    parser.add_argument("--write", action="store_true")
    args = parser.parse_args()
    project = args.project.resolve()
    if not args.path.startswith("res://"):
        print("path must use res://", file=sys.stderr)
        return 2
    path = project / args.path[6:].replace("/", str(Path("/")))
    if not path.is_file():
        print(f"asset does not exist: {path}", file=sys.stderr)
        return 2
    relative = path.relative_to(project).as_posix().lower()
    if any(token in relative for token in ("assets_external/downloads/", "assets_external/raw/", "assets_external/animations/")):
        print("raw/download/animation source folders cannot be runtime paths", file=sys.stderr)
        return 2
    license_path = project / args.license_file.replace("res://", "").replace("/", str(Path("/")))
    if not license_path.is_file():
        print(f"license file does not exist: {license_path}", file=sys.stderr)
        return 2
    entry = {
        "path": args.path,
        "source_pack": args.source_pack,
        "license_file": args.license_file,
        "bytes": path.stat().st_size,
        "sha256": digest(path),
        "approved": False,
        "status": "registered_pending_visual_review",
    }
    manifest_path = project / "soul_character_role_manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    if args.role not in manifest.get("roles", {}):
        print(f"unknown role: {args.role}", file=sys.stderr)
        return 2
    manifest["roles"][args.role].update(entry)
    print(json.dumps({"role": args.role, **entry}, indent=2))
    if args.write:
        manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
        print(f"updated {manifest_path}")
    else:
        print("dry run only; pass --write after visual review")
    return 0


if __name__ == "__main__":
    sys.exit(main())
