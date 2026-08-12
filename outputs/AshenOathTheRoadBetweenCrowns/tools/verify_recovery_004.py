#!/usr/bin/env python3
"""Validate the current RECOVERY-004 audit registry and required boundaries."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("project", type=Path)
    args = parser.parse_args()
    project = args.project.resolve()
    failures: list[str] = []

    def require(condition: bool, message: str) -> None:
        if not condition:
            failures.append(message)

    try:
        registry = json.loads((project / "RECOVERY_004_ISSUE_REGISTRY.json").read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        print(f"RECOVERY-004: FAIL - cannot read issue registry: {error}")
        return 1

    require(registry.get("schema_version") == 1, "unsupported registry schema")
    require(registry.get("registry_id") == "ashen-oath-recovery-004", "registry id mismatch")
    totals = registry.get("audit_totals", {})
    category_total = sum(int(value) for key, value in totals.items() if key != "confirmed_findings")
    require(int(totals.get("confirmed_findings", 0)) == category_total, "audit category totals do not equal 194")
    statuses = set(registry.get("status_values", []))
    tickets = registry.get("tickets", [])
    ticket_ids = [str(ticket.get("id", "")) for ticket in tickets]
    require(len(ticket_ids) == 31, "recovery ticket set must contain 31 tickets")
    require(len(ticket_ids) == len(set(ticket_ids)), "recovery ticket IDs are duplicated")
    require(all(str(ticket.get("status")) in statuses for ticket in tickets), "unknown recovery ticket status")
    require(any(str(ticket.get("id")) == "SECURITY-001" and ticket.get("status") == "verified" for ticket in tickets),
            "SECURITY-001 is not recorded as verified")
    require(any(str(ticket.get("id")) == "QA-006" and ticket.get("status") == "blocked" for ticket in tickets),
            "pending visual approval is not recorded as a release blocker")

    required_files = [
        "tools/verify_security_001.py",
        "tools/verify_qa_005.py",
        "tools/verify_qa_006.py",
        "tools/verify_prod_003.py",
        "tools/run_release_gate.ps1",
        "scripts/input_router.gd",
        "scripts/interaction_focus_service.gd",
        "scripts/quest_presentation_state.gd",
        "scripts/zone_build_context.gd",
        "scripts/zone_composition_router.gd",
        "scripts/zone_runtime_coordinator.gd",
    ]
    for relative in required_files:
        require((project / relative).is_file(), f"required recovery contract is missing: {relative}")

    if failures:
        for failure in failures:
            print(f"RECOVERY-004: FAIL - {failure}")
        return 1
    print("RECOVERY-004: PASS - audit registry, recovery tickets, and required contracts")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
