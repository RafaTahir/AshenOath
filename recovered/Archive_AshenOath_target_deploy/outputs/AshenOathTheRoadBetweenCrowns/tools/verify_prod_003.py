#!/usr/bin/env python3
"""Validate outcome-based recovery status instead of historical completion claims."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


ALLOWED = {"verified", "in_progress", "functional_but_incomplete", "visually_rejected", "open", "blocked", "deferred"}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("project", type=Path)
    args = parser.parse_args()
    project = args.project.resolve()
    failures: list[str] = []
    try:
        registry = json.loads((project / "RECOVERY_004_ISSUE_REGISTRY.json").read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        print(f"PROD-003: FAIL - {error}")
        return 1
    if set(registry.get("status_values", [])) != ALLOWED:
        failures.append("registry status values do not match outcome contract")
    for category in registry.get("categories", []):
        status = category.get("status")
        if status not in ALLOWED:
            failures.append(f"category {category.get('id')} has unknown status {status}")
    for ticket in registry.get("tickets", []):
        if ticket.get("status") == "complete":
            failures.append(f"recovery ticket {ticket.get('id')} still uses historical complete status")
    state = (project / "PROJECT_STATE.md").read_text(encoding="utf-8", errors="replace")
    if "pre-alpha" not in state.lower():
        failures.append("PROJECT_STATE.md does not state the pre-alpha scope")
    if "visual approval" not in state.lower():
        failures.append("PROJECT_STATE.md does not expose the visual approval boundary")
    if failures:
        for failure in failures:
            print(f"PROD-003: FAIL - {failure}")
        return 1
    print("PROD-003: PASS - recovery outcomes are explicit and historical completion claims are bounded")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
