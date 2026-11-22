#!/usr/bin/env python3
"""Validate the split-runtime manifest without requiring downloaded packs."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("project", nargs="?", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--json-report", type=Path)
    args = parser.parse_args()
    project = args.project.resolve()
    path = project / "runtime_pack_manifest.json"
    errors: list[str] = []
    try:
        manifest = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        print(f"RUNTIME PACKS: FAIL ({exc})")
        return 1
    packs = manifest.get("packs", {})
    if not isinstance(packs, dict) or not packs:
        errors.append("packs must be a non-empty object")
    max_bytes = int(manifest.get("max_deployment_bytes", 0))
    if max_bytes <= 0 or max_bytes > 100 * 1024 * 1024:
        errors.append("deployment budget must be positive and at most 100 MB")
    for pack_id, pack in packs.items():
        if not isinstance(pack, dict):
            errors.append(f"{pack_id}: pack must be an object")
            continue
        for key in ("version", "url", "sha256", "bytes", "entry_scene", "dependencies", "preload_priority", "status"):
            if key not in pack:
                errors.append(f"{pack_id}: missing {key}")
        for dependency in pack.get("dependencies", []):
            if dependency not in packs:
                errors.append(f"{pack_id}: unknown dependency {dependency}")
        declared_bytes = int(pack.get("bytes", 0))
        if declared_bytes < 0 or declared_bytes > max_bytes:
            errors.append(f"{pack_id}: invalid byte budget")
        digest = str(pack.get("sha256", ""))
        if digest and len(digest) != 64:
            errors.append(f"{pack_id}: sha256 must be 64 hex characters when present")
        if str(pack.get("status", "")).startswith("embedded") and declared_bytes != 0:
            errors.append(f"{pack_id}: embedded pack must not claim a separate artifact")
    report = {"packs": len(packs), "max_deployment_bytes": max_bytes, "errors": errors}
    if args.json_report:
        args.json_report.parent.mkdir(parents=True, exist_ok=True)
        args.json_report.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    if errors:
        print("RUNTIME PACKS: FAIL")
        for error in errors:
            print(f"- {error}")
        return 1
    print(f"RUNTIME PACKS: PASS ({len(packs)} packs, {max_bytes // (1024 * 1024)} MB deployment budget)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
