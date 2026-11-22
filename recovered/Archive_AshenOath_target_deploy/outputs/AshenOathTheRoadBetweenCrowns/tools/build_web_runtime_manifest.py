#!/usr/bin/env python3
"""Write a hash manifest beside a verified Godot Web export."""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("export_dir", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    export_dir = args.export_dir.resolve()
    if not export_dir.is_dir():
        print(f"missing export directory: {export_dir}", file=sys.stderr)
        return 2
    rows = []
    for path in sorted(export_dir.iterdir()):
        if not path.is_file():
            continue
        rows.append({"name": path.name, "bytes": path.stat().st_size, "sha256": sha256(path)})
    required_names = {"index.html", "index.js", "index.wasm", "index.pck"}
    names = {row["name"] for row in rows}
    missing = sorted(required_names - names)
    if missing:
        print(f"missing required Web artifacts: {', '.join(missing)}", file=sys.stderr)
        return 1
    total = sum(int(row["bytes"]) for row in rows)
    manifest = {"schema_version": 1, "total_bytes": total, "artifacts": rows}
    output = (args.output or (export_dir / "runtime_manifest.json")).resolve()
    output.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"WEB RUNTIME MANIFEST: PASS ({len(rows)} files, {total / 1048576:.1f} MB)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
