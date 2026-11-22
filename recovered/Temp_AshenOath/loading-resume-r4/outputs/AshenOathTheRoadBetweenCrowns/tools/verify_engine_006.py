"""Static acceptance gate for typed zone lifecycle and rollback telemetry."""
from __future__ import annotations

import sys
from pathlib import Path


def main(root: Path) -> int:
    coordinator = (root / "scripts/zone_runtime_coordinator.gd").read_text(encoding="utf-8")
    context = (root / "scripts/zone_build_context.gd").read_text(encoding="utf-8")
    router = (root / "scripts/zone_composition_router.gd").read_text(encoding="utf-8")
    game = (root / "scripts/game.gd").read_text(encoding="utf-8")
    for token in ["begin_build", "finish_build", "validate_build", "rollback", "last_failure", "last_build"]:
        assert token in coordinator, f"coordinator missing {token}"
    for token in ["record_operation", "operation_count", "ground_count", "bounds_count", "gate_count"]:
        assert token in context, f"build context missing {token}"
    assert "ZoneBuildContext.new" in router
    assert "begin_build(zone_id, composition_kind)" in game
    assert "finish_build(build_result, zone_root)" in game
    assert "_recover_failed_zone_load(previous_zone_id)" in game
    print("ENGINE-006: PASS (typed builder contract, build timing, rollback telemetry, required zone support)")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main(Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()))
    except AssertionError as exc:
        print(f"ENGINE-006: FAIL ({exc})")
        raise SystemExit(1)
