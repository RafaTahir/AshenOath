#!/usr/bin/env python3
"""Validate the PROD-002 registry and its generated dashboard."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from generate_prod_002_dashboard import render_dashboard


PROJECT = Path(__file__).resolve().parents[1]
DEFAULT_REGISTRY = PROJECT / "PROD_002_ISSUE_REGISTRY.json"
DEFAULT_DASHBOARD = PROJECT / "PROD_002_MILESTONE_DASHBOARD.md"

EXPECTED_TICKETS = {
    "PROD-001", "PROD-002", "QA-001", "QA-002", "QA-003", "QA-004",
    "DATA-001", "ENGINE-001", "ENGINE-002", "ENGINE-003", "SAVE-001", "NAV-001",
    "GAMEPLAY-001", "COMBAT-001", "COMBAT-002", "OATH-001", "AI-001", "AI-002",
    "BOSS-001", "PROG-001", "INV-001", "ART-001", "ASSET-001", "MAT-001",
    "CHAR-001", "CHAR-002", "ANIM-001", "MON-001", "VFX-001", "LIGHT-001",
    "WATER-001", "WORLD-001", "WORLD-002", "WORLD-003", "WORLD-004", "WORLD-005",
    "WORLD-006", "QUEST-001", "QUEST-002", "QUEST-003", "QUEST-004", "QUEST-005",
    "QUEST-006", "SIDE-001", "DIALOGUE-001", "NARR-001", "AUDIO-001", "AUDIO-002",
    "VOICE-001", "UI-001", "UI-002", "ACCESS-001", "PERF-001", "PERF-002", "PERF-003",
    "INPUT-001", "WEB-001", "WEB-002", "MOBILE-001", "MOBILE-002", "MOBILE-003",
    "STORE-001", "RELEASE-001",
}


def fail(message: str) -> None:
    raise AssertionError(message)


def require(condition: bool, message: str) -> None:
    if not condition:
        fail(message)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--registry", type=Path, default=DEFAULT_REGISTRY)
    parser.add_argument("--dashboard", type=Path, default=DEFAULT_DASHBOARD)
    args = parser.parse_args()

    try:
        registry = json.loads(args.registry.read_text(encoding="utf-8"))
        require(registry["schema_version"] == 1, "unsupported schema_version")
        require(registry["registry_id"] == "ashen-oath-production-issues", "registry_id mismatch")
        require(registry["project"] == "Ashen Oath", "project mismatch")
        require(registry["last_reviewed_commit"], "last_reviewed_commit is empty")
        require(registry["last_reviewed_at"] == "2026-07-26", "registry review date must be explicit")

        milestones = registry["milestones"]
        milestone_ids = [item["id"] for item in milestones]
        require(len(milestone_ids) == len(set(milestone_ids)), "duplicate milestone id")
        require({"baseline", "A", "B", "C", "D", "E"}.issubset(milestone_ids), "milestone set incomplete")
        milestone_set = set(milestone_ids)

        tickets = registry["roadmap_tickets"]
        ticket_ids = [item["id"] for item in tickets]
        require(set(ticket_ids) == EXPECTED_TICKETS, "roadmap ticket set does not match master review")
        require(len(ticket_ids) == len(set(ticket_ids)), "duplicate roadmap ticket id")
        allowed_ticket_statuses = set(registry["ticket_statuses"])
        for ticket in tickets:
            require(ticket["milestone"] in milestone_set, f"unknown milestone for {ticket['id']}")
            require(ticket["status"] in allowed_ticket_statuses, f"unknown ticket status for {ticket['id']}")
            require(ticket["title"].strip(), f"empty ticket title for {ticket['id']}")
            require(ticket["area"].strip(), f"empty ticket area for {ticket['id']}")

        complete = sum(ticket["status"] == "complete" for ticket in tickets)
        planned = sum(ticket["status"] == "planned" for ticket in tickets)
        blocked = sum(ticket["status"] == "blocked_external" for ticket in tickets)
        require(complete == 27, f"expected 27 complete tickets, found {complete}")
        require(planned == 34, f"expected 34 planned tickets, found {planned}")
        require(blocked == 2, f"expected 2 externally blocked tickets, found {blocked}")
        require(next(ticket for ticket in tickets if ticket["id"] == "PROD-002")["status"] == "complete", "PROD-002 is not complete")

        issues = registry["issues"]
        issue_ids = [item["id"] for item in issues]
        require(len(issue_ids) == len(set(issue_ids)), "duplicate issue id")
        allowed_issue_statuses = set(registry["issue_statuses"])
        ticket_set = set(ticket_ids)
        for issue in issues:
            require(issue["status"] in allowed_issue_statuses, f"unknown issue status for {issue['id']}")
            require(issue["severity"] in {"blocker", "high", "medium", "low"}, f"invalid severity for {issue['id']}")
            require(issue["linked_tickets"], f"issue has no linked ticket for {issue['id']}")
            require(set(issue["linked_tickets"]).issubset(ticket_set), f"unknown linked ticket for {issue['id']}")
            require(issue["evidence"].strip(), f"empty evidence for {issue['id']}")

        policy = registry["release_policy"]
        require(policy["web_output_is_registry_data"] is False, "registry must not claim ownership of Web output")
        require("RoadmapMilestone" in policy["milestone_release"], "milestone release policy missing guard")

        expected_dashboard = render_dashboard(registry)
        require(args.dashboard.exists(), "generated dashboard is missing")
        actual_dashboard = args.dashboard.read_text(encoding="utf-8")
        require(actual_dashboard == expected_dashboard, "dashboard is stale; regenerate with --write")
    except (AssertionError, KeyError, TypeError, json.JSONDecodeError, OSError) as error:
        print(f"PROD-002 VERIFIER: FAIL: {error}")
        return 1

    print(f"PROD-002 VERIFIER: PASS ({len(tickets)} tickets, {len(issues)} tracked issues, {complete} complete)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
