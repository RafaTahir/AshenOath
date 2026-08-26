"""WORLDGRID-001 contract checks for the authored exterior atlas."""
from __future__ import annotations

import json
import sys
from pathlib import Path


REQUIRED_CHAIN = [
    "greyfen",
    "wychwood",
    "deep_wood",
    "old_mill",
    "burned_farmstead",
    "marsh_crossing",
    "bandit_road",
    "vargan_approach",
]


def fail(message: str) -> None:
    print(f"WORLDGRID-001 VERIFIER: FAIL: {message}")
    raise SystemExit(1)


def main() -> None:
    project = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parents[1]
    manifest_path = project / "world_sector_manifest.json"
    if not manifest_path.is_file():
        fail("world_sector_manifest.json is missing")
    try:
        data = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        fail(f"manifest is not valid JSON: {exc}")
    sectors = data.get("sectors")
    if data.get("schema_version") != 1 or not isinstance(sectors, dict):
        fail("manifest schema or sectors object is invalid")
    if data.get("cell_size") != [48.0, 40.0]:
        fail("atlas cell size changed without a schema update")
    for zone in REQUIRED_CHAIN:
        record = sectors.get(zone)
        if not isinstance(record, dict) or not record.get("exterior"):
            fail(f"required exterior sector missing: {zone}")
        if not isinstance(record.get("coordinate"), list) or len(record["coordinate"]) != 2:
            fail(f"sector has no coordinate: {zone}")
        bounds = record.get("bounds")
        if not isinstance(bounds, list) or len(bounds) != 2 or min(bounds) <= 0:
            fail(f"sector has invalid bounds: {zone}")
        for edge_id, edge in record.get("edges", {}).items():
            if edge.get("target") not in sectors:
                fail(f"{zone}.{edge_id} targets an unknown sector")
            if edge.get("half_width", 0) < 2.8:
                fail(f"{zone}.{edge_id} is narrower than a player route")
            arrival = edge.get("arrival")
            if not isinstance(arrival, list) or len(arrival) != 3:
                fail(f"{zone}.{edge_id} has no 3D arrival anchor")
    for index, source in enumerate(REQUIRED_CHAIN[:-1]):
        target = REQUIRED_CHAIN[index + 1]
        if not any(edge.get("target") == target for edge in sectors[source].get("edges", {}).values()):
            fail(f"atlas chain is missing {source} -> {target}")
    if not any(edge.get("target") == "greyfen" for edge in sectors["vargan_approach"].get("edges", {}).values()):
        fail("Vargan approach has no Greyfen return edge")
    print("WORLDGRID-001 VERIFIER: PASS (coordinate atlas, bounds, chain, arrival anchors)")


if __name__ == "__main__":
    main()
