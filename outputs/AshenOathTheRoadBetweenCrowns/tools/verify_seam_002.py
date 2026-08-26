"""SEAM-002 static checks for portal-free exterior travel and physical doors."""
from __future__ import annotations

import json
import sys
from pathlib import Path


def fail(message: str) -> None:
    print(f"SEAM-002 VERIFIER: FAIL: {message}")
    raise SystemExit(1)


def main() -> None:
    project = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parents[1]
    game = (project / "scripts" / "game.gd").read_text(encoding="utf-8")
    service = (project / "scripts" / "seamless_world_service.gd").read_text(encoding="utf-8")
    manifest = json.loads((project / "world_sector_manifest.json").read_text(encoding="utf-8"))
    for needle in ["should_suppress_exterior_gate", "should_use_physical_door", "_add_physical_door_visual", "_make_boundary_edge"]:
        if needle not in game and needle not in service:
            fail(f"route presentation contract missing: {needle}")
    for needle in ["open_edges_for", "edge_for_position", "request_seamless_boundary_transition"]:
        if needle not in service and needle not in game:
            fail(f"continuous boundary contract missing: {needle}")
    exterior = {zone for zone, record in manifest["sectors"].items() if record.get("exterior")}
    for source, record in manifest["sectors"].items():
        if source not in exterior:
            continue
        for edge in record.get("edges", {}).values():
            target = edge["target"]
            if target in exterior and edge.get("half_width", 0) < 3.0:
                fail(f"exterior route {source}->{target} lacks a clear walking lane")
    if 'portal.configure(zone_target' not in game:
        fail("legacy gate fallback disappeared; interior/optional gates need a safe fallback")
    print("SEAM-002 VERIFIER: PASS (exterior boundary travel, route lanes, interior physical-door fallback)")


if __name__ == "__main__":
    main()
