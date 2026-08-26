"""NAV-002 checks that actors use the shared bridge-aware route service."""
from __future__ import annotations

import json
import sys
from pathlib import Path


def fail(message: str) -> None:
    print(f"NAV-002 VERIFIER: FAIL: {message}")
    raise SystemExit(1)


def main() -> None:
    project = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parents[1]
    manifest = json.loads((project / "world_sector_manifest.json").read_text(encoding="utf-8"))
    spatial = (project / "scripts" / "zone_spatial_service.gd").read_text(encoding="utf-8")
    life = (project / "scripts" / "greyfen_life_controller.gd").read_text(encoding="utf-8")
    enemy = (project / "scripts" / "enemy_ai.gd").read_text(encoding="utf-8")
    for needle in ["func build_route", "func validate_segment", "func nearest_safe", "func bank_for"]:
        if needle not in spatial:
            fail(f"shared spatial contract missing: {needle}")
    if "spatial_service.build_route" not in life or "spatial_service.build_route" not in enemy:
        fail("both routines and enemies must request shared routes")
    for zone, record in manifest["sectors"].items():
        if not record.get("exterior"):
            continue
        for edge_id, edge in record.get("edges", {}).items():
            if edge.get("half_width", 0) < 3.0 or "arrival" not in edge:
                fail(f"{zone}.{edge_id} has unsafe navigation metadata")
    print("NAV-002 VERIFIER: PASS (shared routes, segment validation, bank recovery, bridge metadata)")


if __name__ == "__main__":
    main()
