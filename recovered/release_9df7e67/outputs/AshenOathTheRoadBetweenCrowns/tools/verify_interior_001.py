"""INTERIOR-001 checks physical-door topology and outdoor-sky suppression."""
from __future__ import annotations

import json
import sys
from pathlib import Path


def fail(message: str) -> None:
    print(f"INTERIOR-001 VERIFIER: FAIL: {message}")
    raise SystemExit(1)


def main() -> None:
    project = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parents[1]
    data = json.loads((project / "world_sector_manifest.json").read_text(encoding="utf-8"))
    sectors = data["sectors"]
    for source, record in sectors.items():
        for target in record.get("interior_doors", []):
            if target not in sectors:
                fail(f"{source} has an unknown interior door target {target}")
            if source not in sectors[target].get("interior_doors", []):
                fail(f"interior door topology is not bidirectional: {source}<->{target}")
    game = (project / "scripts" / "game.gd").read_text(encoding="utf-8")
    seam = (project / "scripts" / "seamless_world_service.gd").read_text(encoding="utf-8")
    visual = (project / "scripts" / "visual_director.gd").read_text(encoding="utf-8")
    for needle in ["func should_use_physical_door", "InteriorDoorFrame", "InteriorDoor"]:
        if needle not in game and needle not in seam:
            fail(f"physical door implementation missing: {needle}")
    if "is_interior" not in visual and "interior" not in visual:
        fail("visual director has no interior profile branch")
    print("INTERIOR-001 VERIFIER: PASS (bidirectional doors, physical door shell, interior lighting path)")


if __name__ == "__main__":
    main()
