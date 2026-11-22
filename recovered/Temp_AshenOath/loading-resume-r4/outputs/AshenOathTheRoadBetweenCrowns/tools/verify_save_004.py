"""SAVE-004 checks the world-coordinate migration contract."""
from __future__ import annotations

import sys
from pathlib import Path


def fail(message: str) -> None:
    print(f"SAVE-004 VERIFIER: FAIL: {message}")
    raise SystemExit(1)


def main() -> None:
    project = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parents[1]
    save = (project / "scripts" / "save_manager.gd").read_text(encoding="utf-8")
    game = (project / "scripts" / "game.gd").read_text(encoding="utf-8")
    service = (project / "scripts" / "seamless_world_service.gd").read_text(encoding="utf-8")
    if "const CURRENT_VERSION := 9" not in save:
        fail("save schema was not advanced to the sector-coordinate version")
    for needle in ["world_sector", "world_position", "seamless_world", "_local_to_world", "_game_world_position"]:
        if needle not in save:
            fail(f"save migration field/helper missing: {needle}")
    for alias in ['"deep_woods": "deep_wood"', '"castle_approach": "vargan_approach"', '"courtyard": "vargan_court"']:
        if alias not in save:
            fail(f"legacy zone alias missing: {alias}")
    if "local_position_for(zone" not in game or "func save_state" not in service:
        fail("runtime load/save does not consume the world-sector contract")
    print("SAVE-004 VERIFIER: PASS (schema 9, world coordinates, legacy aliases, seamless state)")


if __name__ == "__main__":
    main()
