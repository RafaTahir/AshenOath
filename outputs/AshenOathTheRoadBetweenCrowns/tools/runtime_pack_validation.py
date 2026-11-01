"""Shared, filesystem-free runtime pack graph validation."""

import argparse
import json
import re
from pathlib import Path


def validate_pack_graph(manifest: object) -> list[str]:
    if not isinstance(manifest, dict):
        return ["runtime manifest must be an object"]
    packs = manifest.get("packs")
    if not isinstance(packs, dict) or not packs:
        return ["runtime manifest must contain a non-empty packs object"]
    errors = []
    edges = {}
    for pack_id, pack in packs.items():
        if not isinstance(pack_id, str) or not re.fullmatch(r"[a-z0-9_]+", pack_id):
            errors.append(f"invalid pack ID: {pack_id!r}")
        if not isinstance(pack, dict):
            errors.append(f"{pack_id}: pack must be an object")
            continue
        dependencies = pack.get("dependencies", [])
        if not isinstance(dependencies, list) or any(not isinstance(dep, str) for dep in dependencies):
            errors.append(f"{pack_id}: dependencies must be a list of pack IDs")
            continue
        edges[pack_id] = dependencies
        for dependency in dependencies:
            if dependency not in packs:
                errors.append(f"{pack_id}: unknown dependency {dependency}")

    complete, active = set(), []

    def visit(pack_id):
        if pack_id in active:
            cycle = active[active.index(pack_id):] + [pack_id]
            errors.append("cyclic pack dependency: " + " -> ".join(map(str, cycle)))
            return
        if pack_id in complete:
            return
        active.append(pack_id)
        for dependency in edges.get(pack_id, []):
            if dependency in packs:
                visit(dependency)
        active.pop()
        complete.add(pack_id)

    for pack_id in sorted(packs, key=str):
        visit(pack_id)
    return errors


def require_valid_pack_graph(manifest: object) -> None:
    errors = validate_pack_graph(manifest)
    if errors:
        raise ValueError("; ".join(errors))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    args = parser.parse_args()
    try:
        require_valid_pack_graph(json.loads(args.manifest.read_text(encoding="utf-8-sig")))
    except (OSError, ValueError) as error:
        print(f"PACK GRAPH: FAIL - {error}")
        return 1
    print("PACK GRAPH: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
