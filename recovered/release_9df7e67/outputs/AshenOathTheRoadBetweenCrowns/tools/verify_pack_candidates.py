#!/usr/bin/env python3
"""Verify PACK-003 candidate PCK artifacts and their recorded hashes."""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("manifest", type=Path)
    parser.add_argument("--artifact-dir", type=Path)
    parser.add_argument("--require-artifacts", action="store_true")
    args = parser.parse_args()
    manifest_path = args.manifest.resolve()
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError) as exc:
        print(f"PACK CANDIDATES: FAIL ({exc})")
        return 1
    packs = manifest.get("packs")
    errors: list[str] = []
    if manifest.get("ticket") != "PACK-003" or not isinstance(packs, list) or not packs:
        errors.append("manifest must be a PACK-003 candidate list")
        packs = []
    total = 0
    for pack in packs:
        pack_id = str(pack.get("id", ""))
        artifact = str(pack.get("artifact", ""))
        expected_size = int(pack.get("bytes", -1))
        expected_hash = str(pack.get("sha256", ""))
        if not pack_id or not artifact or len(expected_hash) != 64:
            errors.append(f"{pack_id or '<unknown>'}: incomplete artifact record")
            continue
        total += max(expected_size, 0)
        if args.artifact_dir is None:
            continue
        path = (args.artifact_dir / artifact).resolve()
        if not path.is_file():
            message = f"{pack_id}: missing {path}"
            if args.require_artifacts:
                errors.append(message)
            continue
        raw = path.read_bytes()
        if raw[:4] != b"GDPC":
            errors.append(f"{pack_id}: invalid PCK magic")
        if len(raw) != expected_size:
            errors.append(f"{pack_id}: size {len(raw)} != recorded {expected_size}")
        actual_hash = sha256(path)
        if actual_hash != expected_hash:
            errors.append(f"{pack_id}: SHA-256 mismatch")
    recorded_total = int(manifest.get("total_bytes", -1))
    if recorded_total != total:
        errors.append(f"total_bytes {recorded_total} != pack sum {total}")
    if total > 100 * 1024 * 1024:
        errors.append("candidate pack total exceeds 100 MB")
    if errors:
        print("PACK CANDIDATES: FAIL")
        for error in errors:
            print(f"- {error}")
        return 1
    state = "artifacts verified" if args.artifact_dir else "manifest verified"
    print(f"PACK CANDIDATES: PASS ({len(packs)} packs, {total / 1024 / 1024:.2f} MB, {state})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
