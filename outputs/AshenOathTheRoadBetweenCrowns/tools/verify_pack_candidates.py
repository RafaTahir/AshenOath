#!/usr/bin/env python3
"""Verify current schema-2 or historical PACK-003 decoded PCK candidates."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path
from deployment_policy import POLICY


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def validate_candidates(manifest: object, artifact_dir: Path | None = None, require_artifacts: bool = False) -> list[str]:
    if not isinstance(manifest, dict):
        return ["candidate manifest must be an object"]
    errors = []
    schema = manifest.get("schema_version", 1)
    # The story release builder emits schema 2 without a ticket. Ticket names
    # describe workflow provenance, not the validity of this artifact schema.
    if type(schema) is not int or not (schema == 2 or (schema == 1 and manifest.get("ticket") == "PACK-003")):
        errors.append("expected schema-2 candidates or a historical PACK-003 schema-1 record")
    packs = manifest.get("packs")
    if not isinstance(packs, list) or not packs:
        return errors + ["packs must be a non-empty candidate list"]
    if require_artifacts and artifact_dir is None:
        errors.append("--require-artifacts requires --artifact-dir")
    root = artifact_dir.resolve() if artifact_dir is not None else None
    ids, artifacts = set(), set()
    total = 0
    for pack in packs:
        if not isinstance(pack, dict):
            errors.append("candidate pack must be an object")
            continue
        pack_id = pack.get("id", "")
        artifact = pack.get("artifact", "")
        expected_size = pack.get("bytes", -1)
        expected_hash = pack.get("sha256", "")
        if not isinstance(pack_id, str) or not re.fullmatch(r"[a-z0-9_]+", pack_id):
            errors.append(f"{pack_id!r}: invalid pack ID")
        elif pack_id in ids:
            errors.append(f"{pack_id}: duplicate pack ID")
        ids.add(str(pack_id))
        if type(expected_size) is not int or expected_size <= 0:
            errors.append(f"{pack_id}: bytes must be a positive integer")
        else:
            total += expected_size
        if not isinstance(expected_hash, str) or not re.fullmatch(r"[a-fA-F0-9]{64}", expected_hash):
            errors.append(f"{pack_id}: SHA-256 must be 64 hex characters")
        parts = artifact.replace("\\", "/").split("/") if isinstance(artifact, str) else []
        if not parts or any(part in {"", ".", ".."} or ":" in part for part in parts):
            errors.append(f"{pack_id}: artifact must stay inside its artifact directory")
            continue
        normalized = "/".join(parts)
        if normalized.casefold() in artifacts:
            errors.append(f"{pack_id}: duplicate artifact {artifact}")
        artifacts.add(normalized.casefold())
        if root is None:
            continue
        path = (root / normalized).resolve()
        if not path.is_relative_to(root) or path == root:
            errors.append(f"{pack_id}: artifact escapes its artifact directory")
            continue
        if not path.is_file():
            if require_artifacts:
                errors.append(f"{pack_id}: missing {path}")
            continue
        try:
            with path.open("rb") as handle:
                if handle.read(4) != b"GDPC":
                    errors.append(f"{pack_id}: invalid PCK magic")
            actual_size = path.stat().st_size
            if actual_size != expected_size:
                errors.append(f"{pack_id}: size {actual_size} != recorded {expected_size}")
            if not isinstance(expected_hash, str) or sha256(path) != expected_hash.lower():
                errors.append(f"{pack_id}: SHA-256 mismatch")
        except OSError as error:
            errors.append(f"{pack_id}: cannot read artifact: {error}")
    recorded_total = manifest.get("total_bytes", -1)
    if type(recorded_total) is not int or recorded_total != total:
        errors.append(f"total_bytes {recorded_total} != pack sum {total}")
    # Native candidates contain decoded bytes. The current shared policy caps
    # encoded web/, while historical PACK-003 records keep their stated budget.
    budget = manifest.get("max_deployment_bytes", POLICY["max_deployment_bytes"])
    if type(budget) is not int or budget <= 0:
        errors.append("max_deployment_bytes must be a positive integer")
    elif manifest.get("deployment_policy_id") != POLICY["id"] and total > budget:
        errors.append("legacy candidate pack total exceeds its recorded budget")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    parser.add_argument("--artifact-dir", type=Path)
    parser.add_argument("--require-artifacts", action="store_true")
    args = parser.parse_args()
    try:
        manifest = json.loads(args.manifest.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError) as error:
        print(f"PACK CANDIDATES: FAIL ({error})")
        return 1
    errors = validate_candidates(manifest, args.artifact_dir, args.require_artifacts)
    if errors:
        print("PACK CANDIDATES: FAIL")
        for error in errors:
            print(f"- {error}")
        return 1
    state = "required artifacts verified" if args.require_artifacts else ("available artifacts verified" if args.artifact_dir else "manifest verified")
    print(f"PACK CANDIDATES: PASS ({len(manifest['packs'])} packs, {manifest['total_bytes'] / 1048576:.2f} MB, {state})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
