"""SEAM-001 static contract checks for sector lifecycle ownership."""
from __future__ import annotations

import sys
from pathlib import Path


def fail(message: str) -> None:
    print(f"SEAM-001 VERIFIER: FAIL: {message}")
    raise SystemExit(1)


def require(text: str, needle: str, label: str) -> None:
    if needle not in text:
        fail(f"{label} is missing")


def main() -> None:
    project = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parents[1]
    service_path = project / "scripts" / "seamless_world_service.gd"
    game_path = project / "scripts" / "game.gd"
    if not service_path.is_file() or not game_path.is_file():
        fail("seam service or game host is missing")
    service = service_path.read_text(encoding="utf-8")
    game = game_path.read_text(encoding="utf-8")
    require(service, "class_name SeamlessWorldService", "typed seam service")
    for method in ["update_player", "on_zone_activated", "on_zone_failed", "save_state", "load_state", "_kept_sector_ids"]:
        require(service, f"func {method}", f"SeamlessWorldService.{method}")
    for method in ["request_seamless_boundary_transition", "get_zone_half_extents", "_make_boundary_edge"]:
        require(game, f"func {method}", f"Game.{method}")
    if "host.call(" in service or "h.call(" in service:
        fail("reflective host dispatch remains in the seam service")
    require(game, "seamless_world.update_player(player, current_zone_id, delta)", "player boundary handoff")
    require(game, "seamless_world.on_zone_activated(current_zone_id, safe_spawn)", "activation callback")
    require(game, '"seamless_world": seamless_world.snapshot()', "lifecycle snapshot")
    topology = (project / "zone_streaming_topology.json").read_text(encoding="utf-8")
    if '"courtyard"' in topology:
        fail("stale courtyard topology key remains")
    print("SEAM-001 VERIFIER: PASS (typed lifecycle, activation, rollback, retention, no reflective dispatch)")


if __name__ == "__main__":
    main()
